import fs from "node:fs";
import path from "node:path";
import { parse } from "comment-json";
import type { RequireBinding, RojoConfig, RojoPathBinding } from "../types.js";
import { INCLUDE_TO_MODULE, MODULES } from "../libs.js";
import { isEngineStub } from "../preprocess.js";

const SYSTEM_INCLUDES = new Set([
	"iostream",
	"string",
	"string_view",
	"vector",
	"array",
	"map",
	"unordered_map",
	"set",
	"unordered_set",
	"optional",
	"memory",
	"cstdint",
	"cstddef",
	"cmath",
	"algorithm",
	"utility",
	"functional",
	"span",
	"tuple",
	"type_traits",
]);

function asRecord(value: unknown): Record<string, unknown> | null {
	if (!value || typeof value !== "object" || Array.isArray(value)) {
		return null;
	}
	return value as Record<string, unknown>;
}

function posix(filePath: string): string {
	return filePath.replace(/\\/g, "/");
}

export class RojoMapper {
	private config: RojoConfig | null = null;
	private bindings: RojoPathBinding[] = [];

	constructor(
		private projectJsonPath: string,
		private srcDir?: string,
		private outDir?: string,
	) {}

	public async load(): Promise<void> {
		this.loadSync();
	}

	public loadSync(): void {
		this.config = null;
		this.bindings = [];
		if (!fs.existsSync(this.projectJsonPath)) {
			return;
		}
		const content = fs.readFileSync(this.projectJsonPath, "utf8");
		this.config = parse(content) as unknown as RojoConfig;
		this.bindings = this.walkTree(this.config.tree, []);
	}

	private resolveQuotedFile(raw: string, fromFile?: string): string | null {
		const bases: string[] = [];
		if (fromFile) {
			bases.push(path.dirname(fromFile));
		}
		if (this.srcDir) {
			bases.push(this.srcDir);
		}
		for (const base of bases) {
			const candidate = path.resolve(base, raw);
			if (fs.existsSync(candidate) && fs.statSync(candidate).isFile()) {
				return candidate;
			}
		}
		return null;
	}

	public resolveIncludeToRequire(includePath: string, fromFile?: string): RequireBinding | null {
		const raw = includePath.replace(/[<>'"]/g, "").trim();
		if (!raw) {
			return null;
		}
		const cleanPath = posix(raw).replace(/\.h(pp|h)?$/i, "");
		const baseName = path.posix.basename(cleanPath);
		const key = baseName.toLowerCase();

		if (isEngineStub(raw) || SYSTEM_INCLUDES.has(key) || SYSTEM_INCLUDES.has(cleanPath.toLowerCase())) {
			return null;
		}

		const library = this.resolveLibrary(cleanPath, key);
		if (library) {
			return library;
		}

		const resolvedFile = this.resolveQuotedFile(raw, fromFile);
		const lookupPath =
			resolvedFile && this.srcDir
				? posix(path.relative(this.srcDir, resolvedFile)).replace(/\.h(pp|h)?$/i, "")
				: cleanPath;

		const fromTree = this.resolveFromRojoTree(lookupPath, baseName);
		if (fromTree) {
			return fromTree;
		}

		const segments = lookupPath.split("/").filter(Boolean);
		if (segments[0] === "src") {
			segments.shift();
		}
		const alias = this.safeAlias(baseName);
		if (segments[0] === "ReplicatedFirst") {
			return { alias, path: `ReplicatedFirst.${segments.slice(1).join(".")}` };
		}
		if (segments[0] === "ReplicatedStorage") {
			return { alias, path: `ReplicatedStorage.${segments.slice(1).join(".")}` };
		}
		if (segments[0] === "ServerScriptService") {
			return { alias, path: `ServerScriptService.${segments.slice(1).join(".")}` };
		}
		if (segments[0] === "StarterPlayer") {
			return { alias, path: `StarterPlayer.${segments.slice(1).join(".")}` };
		}
		if (segments[0] === "ServerStorage") {
			return { alias, path: `ServerStorage.${segments.slice(1).join(".")}` };
		}
		return { alias, path: `ReplicatedStorage.${segments.join(".")}` };
	}

	private resolveLibrary(cleanPath: string, key: string): RequireBinding | null {
		const mapped = (INCLUDE_TO_MODULE as Record<string, string | null>)[key]
			?? (INCLUDE_TO_MODULE as Record<string, string | null>)[path.posix.basename(cleanPath).toLowerCase()];
		if (!mapped) {
			return null;
		}
		const spec = (MODULES as Record<string, { file: string; bind: string }>)[mapped];
		const bind = spec?.bind || mapped;
		const file = spec?.file || mapped;
		const libsRoot = this.findBinding((binding) => binding.robloxPath.endsWith(".CluauppLibs") || binding.robloxPath === "ReplicatedStorage.CluauppLibs");
		const packagesRoot = this.findBinding((binding) => binding.robloxPath.endsWith(".Packages") || binding.robloxPath === "ReplicatedStorage.Packages");
		if (libsRoot) {
			return { alias: bind, path: `${libsRoot.robloxPath}.${file}` };
		}
		if (packagesRoot) {
			return { alias: bind, path: `${packagesRoot.robloxPath}.${file}` };
		}
		return { alias: bind, path: `ReplicatedStorage.CluauppLibs.${file}` };
	}

	private resolveFromRojoTree(cleanPath: string, baseName: string): RequireBinding | null {
		const outRel = this.guessOutRel(cleanPath);
		if (!outRel || this.bindings.length === 0) {
			return null;
		}
		let best: { binding: RojoPathBinding; rest: string[] } | null = null;
		for (const binding of this.bindings) {
			const prefix = posix(binding.fsPath).replace(/\/$/, "");
			if (outRel === prefix || outRel.startsWith(`${prefix}/`)) {
				const rest = outRel === prefix ? [] : outRel.slice(prefix.length + 1).split("/");
				if (!best || prefix.length > posix(best.binding.fsPath).length) {
					best = { binding, rest };
				}
			}
		}
		if (!best) {
			return null;
		}
		const tail = best.rest.join(".");
		return {
			alias: this.safeAlias(baseName),
			path: tail ? `${best.binding.robloxPath}.${tail}` : best.binding.robloxPath,
		};
	}

	private guessOutRel(cleanPath: string): string | null {
		const relative = posix(cleanPath).replace(/^src\//, "");
		const outName = relative.replace(/\.(cpp|cc|cxx|c|h|hpp|hh)$/i, "");
		if (this.outDir) {
			return posix(path.join(this.outDir, outName));
		}
		return posix(path.join("out", outName));
	}

	private walkTree(node: unknown, robloxPath: string[]): RojoPathBinding[] {
		const record = asRecord(node);
		if (!record) {
			return [];
		}
		const found: RojoPathBinding[] = [];
		if (typeof record.$path === "string" && robloxPath.length > 0) {
			found.push({
				robloxPath: robloxPath.join("."),
				fsPath: posix(record.$path),
			});
		}
		for (const [key, child] of Object.entries(record)) {
			if (key.startsWith("$")) {
				continue;
			}
			found.push(...this.walkTree(child, [...robloxPath, key]));
		}
		return found;
	}

	private findBinding(predicate: (binding: RojoPathBinding) => boolean): RojoPathBinding | undefined {
		return this.bindings.find(predicate);
	}

	private safeAlias(name: string): string {
		const cleaned = name.replace(/[^A-Za-z0-9_]/g, "_");
		return /^[A-Za-z_]/.test(cleaned) ? cleaned : `_${cleaned}`;
	}
}
