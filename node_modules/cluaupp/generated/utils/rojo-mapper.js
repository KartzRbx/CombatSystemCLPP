"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.RojoMapper = void 0;
const node_fs_1 = __importDefault(require("node:fs"));
const node_path_1 = __importDefault(require("node:path"));
const comment_json_1 = require("comment-json");
const libs_js_1 = require("../libs.js");
const preprocess_js_1 = require("../preprocess.js");
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
function asRecord(value) {
    if (!value || typeof value !== "object" || Array.isArray(value)) {
        return null;
    }
    return value;
}
function posix(filePath) {
    return filePath.replace(/\\/g, "/");
}
class RojoMapper {
    projectJsonPath;
    srcDir;
    outDir;
    config = null;
    bindings = [];
    constructor(projectJsonPath, srcDir, outDir) {
        this.projectJsonPath = projectJsonPath;
        this.srcDir = srcDir;
        this.outDir = outDir;
    }
    async load() {
        this.loadSync();
    }
    loadSync() {
        this.config = null;
        this.bindings = [];
        if (!node_fs_1.default.existsSync(this.projectJsonPath)) {
            return;
        }
        const content = node_fs_1.default.readFileSync(this.projectJsonPath, "utf8");
        this.config = (0, comment_json_1.parse)(content);
        this.bindings = this.walkTree(this.config.tree, []);
    }
    resolveQuotedFile(raw, fromFile) {
        const bases = [];
        if (fromFile) {
            bases.push(node_path_1.default.dirname(fromFile));
        }
        if (this.srcDir) {
            bases.push(this.srcDir);
        }
        for (const base of bases) {
            const candidate = node_path_1.default.resolve(base, raw);
            if (node_fs_1.default.existsSync(candidate) && node_fs_1.default.statSync(candidate).isFile()) {
                return candidate;
            }
        }
        return null;
    }
    resolveIncludeToRequire(includePath, fromFile) {
        const raw = includePath.replace(/[<>'"]/g, "").trim();
        if (!raw) {
            return null;
        }
        const cleanPath = posix(raw).replace(/\.h(pp|h)?$/i, "");
        const baseName = node_path_1.default.posix.basename(cleanPath);
        const key = baseName.toLowerCase();
        if ((0, preprocess_js_1.isEngineStub)(raw) || SYSTEM_INCLUDES.has(key) || SYSTEM_INCLUDES.has(cleanPath.toLowerCase())) {
            return null;
        }
        const library = this.resolveLibrary(cleanPath, key);
        if (library) {
            return library;
        }
        const resolvedFile = this.resolveQuotedFile(raw, fromFile);
        const lookupPath = resolvedFile && this.srcDir
            ? posix(node_path_1.default.relative(this.srcDir, resolvedFile)).replace(/\.h(pp|h)?$/i, "")
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
    resolveLibrary(cleanPath, key) {
        const mapped = libs_js_1.INCLUDE_TO_MODULE[key]
            ?? libs_js_1.INCLUDE_TO_MODULE[node_path_1.default.posix.basename(cleanPath).toLowerCase()];
        if (!mapped) {
            return null;
        }
        const spec = libs_js_1.MODULES[mapped];
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
    resolveFromRojoTree(cleanPath, baseName) {
        const outRel = this.guessOutRel(cleanPath);
        if (!outRel || this.bindings.length === 0) {
            return null;
        }
        let best = null;
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
    guessOutRel(cleanPath) {
        const relative = posix(cleanPath).replace(/^src\//, "");
        const outName = relative.replace(/\.(cpp|cc|cxx|c|h|hpp|hh)$/i, "");
        if (this.outDir) {
            return posix(node_path_1.default.join(this.outDir, outName));
        }
        return posix(node_path_1.default.join("out", outName));
    }
    walkTree(node, robloxPath) {
        const record = asRecord(node);
        if (!record) {
            return [];
        }
        const found = [];
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
    findBinding(predicate) {
        return this.bindings.find(predicate);
    }
    safeAlias(name) {
        const cleaned = name.replace(/[^A-Za-z0-9_]/g, "_");
        return /^[A-Za-z_]/.test(cleaned) ? cleaned : `_${cleaned}`;
    }
}
exports.RojoMapper = RojoMapper;
