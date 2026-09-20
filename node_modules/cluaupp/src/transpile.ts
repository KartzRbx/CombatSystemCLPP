import path from "node:path";
import type { CompileOptions, CompileServiceResult } from "./types.js";
import { compileService, compileServiceAsync } from "./compile.js";
import type { RojoMapper } from "./utils/rojo-mapper.js";

export function transpileSource(
	source: string,
	fileName: string,
	options: CompileOptions,
	_mapper?: RojoMapper,
): CompileServiceResult {
	return compileService(source, fileName, options);
}

export function transpileSourceAsync(
	source: string,
	fileName: string,
	options: CompileOptions,
	_mapper?: RojoMapper,
): Promise<CompileServiceResult> {
	return compileServiceAsync(source, fileName, options);
}

export function outputNameFor(inputFile: string, outputPath: string): string {
	if (/\.luau$/i.test(outputPath)) {
		return outputPath;
	}
	const base = path.basename(inputFile).replace(/\.(clpp|clp|clh)$/i, ".luau");
	return path.join(outputPath, base);
}
