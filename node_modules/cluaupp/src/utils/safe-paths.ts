import fs from "node:fs";
import os from "node:os";
import path from "node:path";

const BLOCKED_DIRS = new Set([".", "..", "node_modules", ".git"]);

export class PathEscapeError extends Error {
	constructor(message: string) {
		super(message);
		this.name = "PathEscapeError";
	}
}

export function posixRel(rel: string): string {
	return String(rel || "").replace(/\\/g, "/");
}

export function isInside(root: string, target: string): boolean {
	const absRoot = path.resolve(root);
	const absTarget = path.resolve(target);
	const rel = path.relative(absRoot, absTarget);
	return rel === "" || (!rel.startsWith("..") && !path.isAbsolute(rel));
}

export function realPath(target: string): string {
	try {
		return fs.realpathSync(target);
	} catch {
		return path.resolve(target);
	}
}

export function assertInside(root: string, target: string, label: string): string {
	const absRoot = realPath(root);
	const absTarget = path.resolve(target);
	if (!isInside(absRoot, absTarget)) {
		throw new PathEscapeError(`cluaupp: ${label} escapes the project folder`);
	}
	return absTarget;
}

export function safeRelPath(rel: string): string | null {
	const normalized = posixRel(rel).replace(/^\.\/+/, "");
	if (!normalized || path.isAbsolute(normalized) || /^[a-zA-Z]:/.test(normalized)) {
		return null;
	}
	const parts = normalized.split("/").filter((part) => part && part !== ".");
	if (parts.length === 0 || parts.some((part) => part === ".." || part === ".git")) {
		return null;
	}
	return parts.join("/");
}

export function safeProjectSubdir(value: string, fallback: string, label: string): string {
	const cleaned = safeRelPath(value);
	if (!cleaned || BLOCKED_DIRS.has(cleaned.split("/")[0] || "")) {
		throw new PathEscapeError(`cluaupp: invalid ${label} ${JSON.stringify(value)}`);
	}
	return cleaned;
}

export function assertInitDest(dest: string): string {
	const resolved = path.resolve(dest);
	const root = path.parse(resolved).root;
	if (resolved === root) {
		throw new PathEscapeError("cluaupp: refused to init at the filesystem root");
	}
	const home = os.homedir();
	if (home && path.resolve(home) === resolved) {
		throw new PathEscapeError("cluaupp: refused to init in the home directory itself");
	}
	return resolved;
}

export function childEnv(): NodeJS.ProcessEnv {
	const env: NodeJS.ProcessEnv = {};
	for (const key of [
		"PATH",
		"Path",
		"PATHEXT",
		"SYSTEMROOT",
		"SystemRoot",
		"COMSPEC",
		"ComSpec",
		"HOME",
		"USERPROFILE",
		"TMP",
		"TEMP",
		"TMPDIR",
		"LANG",
		"LC_ALL",
	]) {
		if (process.env[key]) {
			env[key] = process.env[key];
		}
	}
	return env;
}
