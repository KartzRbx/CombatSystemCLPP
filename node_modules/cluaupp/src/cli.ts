import { Command } from "commander";
import fs from "node:fs/promises";
import path from "node:path";
import { pkg } from "./package-info.js";
import { start as startLsp } from "./lsp.js";
import { collectSources, toLuauPath } from "./clpp/paths.js";
import { CLPP_INSTALL_HINT } from "./clpp/contract.js";
import { clppInstalls, clppManifest, clppVersion, hasClpp, resolveClppBinary } from "./clpp/runner.js";
import { installEditorSupport, syncEditorSupport } from "./intellisense.js";
import { RojoMapper } from "./utils/rojo-mapper.js";
import { ProcessOrchestrator } from "./utils/process-orchestrator.js";
import { build as buildProject, init, loadConfig, watch } from "./utils/project.js";
import { transpileSource } from "./transpile.js";
import type { BuildOptions, BuildResult } from "./types.js";

const program = new Command();

program
	.name("cluaupp")
	.description("Cluaupp toolchain — compile CL++ to Luau, Rojo, and CluauppLibs")
	.version(pkg.version, "-v, --version", "print version")
	.showHelpAfterError()
	.action(() => {
		program.outputHelp();
	});

program
	.command("init")
	.description("create a game (ReplicatedStorage, ServerScriptService, StarterPlayer)")
	.argument("[folder]", "destination folder", ".")
	.action(async (folder: string) => {
		try {
			await init(path.resolve(process.cwd(), folder));
		} catch (err) {
			console.error(err instanceof Error ? err.message : err);
			process.exit(1);
		}
	});

program
	.command("build")
	.description("Compile a CL++ file, directory, or project to Luau")
	.argument("[folder]", "project folder", ".")
	.option("-i, --input <path>", "CL++ file or directory")
	.option("-o, --output <path>", "Luau file or directory")
	.option("-r, --rojo <path>", "Path to Rojo default.project.json", "./default.project.json")
	.option("--strict", "Emit --!strict")
	.option("--format", "Run StyLua on output")
	.option("--analyze", "Run luau-analyze on output")
	.action(async (folder: string, options: {
		input?: string;
		output?: string;
		rojo: string;
		strict?: boolean;
		format?: boolean;
		analyze?: boolean;
	}) => {
		if (options.input) {
			await buildInput(options);
			return;
		}
		try {
			buildProject(path.resolve(process.cwd(), folder), {
				format: options.format === true,
				analyze: options.analyze === true,
				rojo: options.rojo,
				strict: options.strict === true,
			});
		} catch (err) {
			console.error(err instanceof Error ? err.message : err);
			process.exit(1);
		}
	});

program
	.command("watch")
	.description("rebuild on save")
	.argument("[folder]", "project folder", ".")
	.option("-r, --rojo <path>", "Path to Rojo default.project.json", "./default.project.json")
	.option("--format", "Run StyLua on output")
	.action((folder: string, options: { rojo?: string; format?: boolean }) => {
		try {
			watch(path.resolve(process.cwd(), folder), {
				format: options.format === true,
				rojo: options.rojo,
			});
		} catch (err) {
			console.error(err instanceof Error ? err.message : err);
			process.exit(1);
		}
	});

program
	.command("lsp")
	.description("Language server stdio (JSON-RPC). Use `clpp install` for CL++ IntelliSense.")
	.argument("[folder]", "project folder", ".")
	.action((folder: string) => {
		startLsp({ projectRoot: path.resolve(process.cwd(), folder) });
	});

program
	.command("intellisense")
	.alias("intelisense")
	.description("Point the editor at CL++ (`clpp install`)")
	.argument("[folder]", "project folder", ".")
	.action(async (folder: string) => {
		try {
			const root = path.resolve(process.cwd(), folder);
			syncEditorSupport(root, loadConfig(root));
			await installEditorSupport();
			console.log("cluaupp: editor associations written in", root);
			console.log("cluaupp:", CLPP_INSTALL_HINT);
		} catch (err) {
			console.error(err instanceof Error ? err.message : err);
			process.exit(1);
		}
	});

program
	.command("language")
	.description("CL++ manifest (`clpp api manifest`)")
	.action(() => {
		try {
			const bin = resolveClppBinary();
			const version = clppVersion();
			if (version) {
				console.log(version, `(${bin})`);
			}
			for (const install of clppInstalls()) {
				if (!install.selected) {
					console.log(`skipped ${install.bin} (${install.version || "unknown"})`);
				}
			}
			console.log(JSON.stringify(clppManifest(), null, "\t"));
		} catch (err) {
			console.error(err instanceof Error ? err.message : err);
			process.exit(1);
		}
	});

async function buildInput(options: {
	input?: string;
	output?: string;
	rojo: string;
	strict?: boolean;
	format?: boolean;
	analyze?: boolean;
}): Promise<void> {
	if (!options.input || !options.output) {
		console.error("[Erro] --input e --output são obrigatórios neste modo.");
		process.exit(1);
	}

	const inputPath = path.resolve(options.input);
	const outputPath = path.resolve(options.output);

	try {
		await fs.stat(inputPath);
	} catch {
		console.error(`[Erro] O caminho de entrada especificado não existe: ${inputPath}`);
		process.exit(1);
	}

	const mapper = new RojoMapper(path.resolve(options.rojo), path.dirname(inputPath));
	await mapper.load();

	const inputs = (await fs.stat(inputPath)).isDirectory()
		? collectSources(inputPath)
		: [inputPath];

	if (inputs.length === 0) {
		console.error("no .clpp/.clp/.clh files in", inputPath);
		process.exit(1);
	}

	const outputIsFile = /\.luau$/i.test(outputPath);
	if (outputIsFile && inputs.length > 1) {
		console.error("[Erro] --output deve ser um diretório quando a entrada contém vários arquivos.");
		process.exit(1);
	}

	for (const file of inputs) {
		const sourceCode = await fs.readFile(file, "utf8");
		const rel = path.basename(file);
		const compiled = transpileSource(sourceCode, rel, {
			strict: options.strict === true,
			filePath: file,
			relativeName: rel,
			srcDir: path.dirname(file),
			includeDirs: [path.dirname(file)],
		}, mapper);

		const dest = outputIsFile ? outputPath : path.join(outputPath, path.basename(toLuauPath(rel)));
		await fs.mkdir(path.dirname(dest), { recursive: true });
		const luau = compiled.files[0]?.contents ?? "";
		await fs.writeFile(dest, luau, "utf8");

		if (options.format === true) {
			await ProcessOrchestrator.formatWithStyLua(dest);
		}
		if (options.analyze === true) {
			const analysisReport = await ProcessOrchestrator.analyzeWithLuau(dest);
			if (analysisReport) {
				console.log("\nRelatório de Análise Estática do Luau:\n", analysisReport);
			}
		}
		console.log(`Compiled ${file} → ${dest}`);
	}
}

export function build(root: string, options: BuildOptions = {}): BuildResult {
	return buildProject(root, options);
}

export { watch, init, program, hasClpp };

export function dispatch(args: string[]): Promise<Command> {
	return program.parseAsync(["node", "cluaupp", ...args]);
}

function isMain(): boolean {
	const entry = process.argv[1];
	if (!entry) {
		return false;
	}
	return ["cli.js", "cli.ts", "cluaupp.js", "cluau.js"].includes(path.basename(entry));
}

if (isMain()) {
	program.parseAsync(process.argv).catch((err: unknown) => {
		console.error(err instanceof Error ? err.message : err);
		process.exit(1);
	});
}
