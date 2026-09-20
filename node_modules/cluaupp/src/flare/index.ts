import fs from "node:fs";
import path from "node:path";
import { emitFlare } from "./emit.js";
import { parseFlare } from "./parse.js";
import type { FlareEmitResult, FlareSchema } from "./types.js";

export type { FlareEmitResult, FlareSchema } from "./types.js";
export { parseFlare } from "./parse.js";
export { emitFlare, emitFlareHeader, emitFlareLuau } from "./emit.js";

export function isFlareFile(fileName: string): boolean {
	return path.extname(fileName).toLowerCase() === ".flare";
}

export function isGeneratedHeader(filePath: string): boolean {
	if (path.extname(filePath).toLowerCase() !== ".clh") {
		return false;
	}
	if (!fs.existsSync(filePath)) {
		return false;
	}
	const head = fs.readFileSync(filePath, "utf8").slice(0, 400);
	return /cluaupp generated/i.test(head);
}

export function collectFlareFiles(dir: string, files: string[] = []): string[] {
	if (!fs.existsSync(dir)) {
		return files;
	}
	for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
		const full = path.join(dir, entry.name);
		if (entry.isDirectory()) {
			collectFlareFiles(full, files);
		} else if (isFlareFile(entry.name)) {
			files.push(full);
		}
	}
	return files;
}

export function compileFlareFile(file: string, srcDir: string): { schema: FlareSchema; emit: FlareEmitResult } {
	const source = fs.readFileSync(file, "utf8");
	const rel = path.relative(srcDir, file).replace(/\\/g, "/");
	const stem = path.basename(file, path.extname(file));
	const schema = parseFlare(source, rel, stem);
	const relDir = path.posix.dirname(rel);
	const dir = relDir === "." ? "" : relDir;
	const emit = emitFlare(schema, dir);
	return { schema, emit };
}
