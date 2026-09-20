import fs from "node:fs";
import path from "node:path";
import { isGeneratedHeader } from "../flare/index.js";

export const SOURCE_EXTS = [".clpp", ".clp", ".clh"];

export function isSourceFile(fileName: string): boolean {
	return SOURCE_EXTS.includes(path.extname(fileName).toLowerCase());
}

export function isEngineStub(filePath: string): boolean {
	const normalized = filePath.replace(/\\/g, "/").toLowerCase();
	return (
		normalized.includes("/include/cluaupp/") ||
		normalized.includes("/include/clpp/") ||
		normalized.includes("/include/cluau/") ||
		normalized.includes("/stdlib/") ||
		normalized.endsWith("/roblox.clh")
	);
}

export function isHeaderFile(fileName: string): boolean {
	return path.extname(fileName).toLowerCase() === ".clh";
}

export function isImplFile(fileName: string): boolean {
	const ext = path.extname(fileName).toLowerCase();
	return ext === ".clp" || ext === ".clpp";
}

export function toLuauPath(filePath: string): string {
	return String(filePath).replace(/\.(clpp|clp|clh)$/i, ".luau");
}

export function fileStem(fileName: string): string {
	let name = path.basename(fileName);
	const lower = name.toLowerCase();
	for (const ext of [".clpp", ".clp", ".clh"]) {
		if (lower.endsWith(ext)) {
			name = name.slice(0, -ext.length);
			break;
		}
	}
	const tagged = name.toLowerCase();
	for (const tag of [".legacy.server", ".legacy.client", ".legacy", ".server", ".client", ".plugin"]) {
		if (tagged.endsWith(tag)) {
			name = name.slice(0, -tag.length);
			break;
		}
	}
	return name;
}

export function scriptKind(fileName: string): "server" | "client" | "plugin" | "legacy" | "module" | "header" {
	const name = path.basename(fileName).toLowerCase();
	if (name.endsWith(".clh")) {
		return "header";
	}
	if (name.includes(".legacy.")) {
		return "legacy";
	}
	if (name.includes(".server.")) {
		return "server";
	}
	if (name.includes(".client.")) {
		return "client";
	}
	if (name.includes(".plugin.")) {
		return "plugin";
	}
	return "module";
}

export function emitKind(fileName: string): "flat" | "module" | "legacy" {
	const kind = scriptKind(fileName);
	if (kind === "legacy") {
		return "legacy";
	}
	if (kind === "module" || kind === "header") {
		return "module";
	}
	return "flat";
}

export function isTaggedScript(fileName: string): boolean {
	const kind = scriptKind(fileName);
	return kind === "server" || kind === "client" || kind === "plugin" || kind === "legacy";
}

export function siblingHeader(implPath: string | null | undefined): string | null {
	if (!implPath || isHeaderFile(implPath)) {
		return null;
	}
	const dir = path.dirname(implPath);
	const stem = fileStem(implPath);
	const candidate = path.join(dir, `${stem}.clh`);
	if (fs.existsSync(candidate)) {
		return candidate;
	}
	return null;
}

export function collectSources(dir: string, files: string[] = []): string[] {
	if (!fs.existsSync(dir)) {
		return files;
	}
	for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
		const full = path.join(dir, entry.name);
		if (entry.isDirectory()) {
			collectSources(full, files);
		} else if (isSourceFile(entry.name) && !isGeneratedHeader(full)) {
			files.push(full);
		}
	}
	return files;
}
