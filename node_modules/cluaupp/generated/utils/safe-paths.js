"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.PathEscapeError = void 0;
exports.posixRel = posixRel;
exports.isInside = isInside;
exports.realPath = realPath;
exports.assertInside = assertInside;
exports.safeRelPath = safeRelPath;
exports.safeProjectSubdir = safeProjectSubdir;
exports.assertInitDest = assertInitDest;
exports.childEnv = childEnv;
const node_fs_1 = __importDefault(require("node:fs"));
const node_os_1 = __importDefault(require("node:os"));
const node_path_1 = __importDefault(require("node:path"));
const BLOCKED_DIRS = new Set([".", "..", "node_modules", ".git"]);
class PathEscapeError extends Error {
    constructor(message) {
        super(message);
        this.name = "PathEscapeError";
    }
}
exports.PathEscapeError = PathEscapeError;
function posixRel(rel) {
    return String(rel || "").replace(/\\/g, "/");
}
function isInside(root, target) {
    const absRoot = node_path_1.default.resolve(root);
    const absTarget = node_path_1.default.resolve(target);
    const rel = node_path_1.default.relative(absRoot, absTarget);
    return rel === "" || (!rel.startsWith("..") && !node_path_1.default.isAbsolute(rel));
}
function realPath(target) {
    try {
        return node_fs_1.default.realpathSync(target);
    }
    catch {
        return node_path_1.default.resolve(target);
    }
}
function assertInside(root, target, label) {
    const absRoot = realPath(root);
    const absTarget = node_path_1.default.resolve(target);
    if (!isInside(absRoot, absTarget)) {
        throw new PathEscapeError(`cluaupp: ${label} escapes the project folder`);
    }
    return absTarget;
}
function safeRelPath(rel) {
    const normalized = posixRel(rel).replace(/^\.\/+/, "");
    if (!normalized || node_path_1.default.isAbsolute(normalized) || /^[a-zA-Z]:/.test(normalized)) {
        return null;
    }
    const parts = normalized.split("/").filter((part) => part && part !== ".");
    if (parts.length === 0 || parts.some((part) => part === ".." || part === ".git")) {
        return null;
    }
    return parts.join("/");
}
function safeProjectSubdir(value, fallback, label) {
    const cleaned = safeRelPath(value);
    if (!cleaned || BLOCKED_DIRS.has(cleaned.split("/")[0] || "")) {
        throw new PathEscapeError(`cluaupp: invalid ${label} ${JSON.stringify(value)}`);
    }
    return cleaned;
}
function assertInitDest(dest) {
    const resolved = node_path_1.default.resolve(dest);
    const root = node_path_1.default.parse(resolved).root;
    if (resolved === root) {
        throw new PathEscapeError("cluaupp: refused to init at the filesystem root");
    }
    const home = node_os_1.default.homedir();
    if (home && node_path_1.default.resolve(home) === resolved) {
        throw new PathEscapeError("cluaupp: refused to init in the home directory itself");
    }
    return resolved;
}
function childEnv() {
    const env = {};
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
