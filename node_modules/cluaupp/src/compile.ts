import path from "node:path";
import type { CompileOptions, CompileServiceResult } from "./types.js";
import { compileViaClpp, compileViaClppAsync } from "./clpp/runner.js";
import { clppLuauToGame, shouldSkipInit } from "./clpp/postprocess.js";
import { emitKind, siblingHeader, toLuauPath } from "./clpp/paths.js";
import type { CompileArtifact } from "./clpp/contract.js";

function compileArgs(source: string, fileName: string | undefined, options: CompileOptions) {
	const relative = (options.relativeName || fileName || "input.clpp").replace(/\\/g, "/");
	const outName = options.outName || toLuauPath(relative);
	const header = options.filePath ? siblingHeader(options.filePath) : null;
	const skipInit = options.skipInit === true || shouldSkipInit(relative, Boolean(header));
	const diskPath = options.filePath ? path.resolve(options.filePath) : null;
	return {
		request: {
			source,
			fileName: diskPath ? diskPath.replace(/\\/g, "/") : relative,
			strict: options.strict,
			cwd: diskPath ? path.dirname(diskPath) : options.srcDir,
		},
		relative,
		outName,
		skipInit,
		options,
	};
}

function finishArtifact(
	artifact: CompileArtifact,
	relative: string,
	outName: string,
	options: CompileOptions,
	skipInit: boolean,
	source: string,
): CompileServiceResult {
	const luau = clppLuauToGame(artifact, {
		relativeName: relative,
		outName,
		srcDir: options.srcDir,
		rootDir: options.rootDir,
		strict: options.strict,
		skipInit,
		source,
	});
	return {
		kind: emitKind(relative),
		plan: { kind: emitKind(relative), strict: options.strict === true },
		files: [{ name: outName, contents: luau }],
		stale: [],
	};
}

export function compileSource(source: string, fileName?: string, options: CompileOptions = {}): string {
	return compileService(source, fileName, options).files[0]?.contents ?? "";
}

export function compileService(source: string, fileName?: string, options: CompileOptions = {}): CompileServiceResult {
	const args = compileArgs(source, fileName, options);
	const artifact = compileViaClpp(args.request);
	return finishArtifact(artifact, args.relative, args.outName, args.options, args.skipInit, source);
}

export async function compileServiceAsync(source: string, fileName?: string, options: CompileOptions = {}): Promise<CompileServiceResult> {
	const args = compileArgs(source, fileName, options);
	const artifact = await compileViaClppAsync(args.request);
	return finishArtifact(artifact, args.relative, args.outName, args.options, args.skipInit, source);
}
