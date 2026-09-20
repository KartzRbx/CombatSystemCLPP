"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.SOURCE_EXTS = void 0;
exports.isSourceFile = isSourceFile;
exports.isEngineStub = isEngineStub;
exports.isHeaderFile = isHeaderFile;
exports.isImplFile = isImplFile;
exports.toLuauPath = toLuauPath;
exports.fileStem = fileStem;
exports.scriptKind = scriptKind;
exports.emitKind = emitKind;
exports.isTaggedScript = isTaggedScript;
exports.siblingHeader = siblingHeader;
exports.collectSources = collectSources;
const node_fs_1 = __importDefault(require("node:fs"));
const node_path_1 = __importDefault(require("node:path"));
const index_js_1 = require("../flare/index.js");
exports.SOURCE_EXTS = [".clpp", ".clp", ".clh"];
function isSourceFile(fileName) {
    return exports.SOURCE_EXTS.includes(node_path_1.default.extname(fileName).toLowerCase());
}
function isEngineStub(filePath) {
    const normalized = filePath.replace(/\\/g, "/").toLowerCase();
    return (normalized.includes("/include/cluaupp/") ||
        normalized.includes("/include/clpp/") ||
        normalized.includes("/include/cluau/") ||
        normalized.includes("/stdlib/") ||
        normalized.endsWith("/roblox.clh"));
}
function isHeaderFile(fileName) {
    return node_path_1.default.extname(fileName).toLowerCase() === ".clh";
}
function isImplFile(fileName) {
    const ext = node_path_1.default.extname(fileName).toLowerCase();
    return ext === ".clp" || ext === ".clpp";
}
function toLuauPath(filePath) {
    return String(filePath).replace(/\.(clpp|clp|clh)$/i, ".luau");
}
function fileStem(fileName) {
    let name = node_path_1.default.basename(fileName);
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
function scriptKind(fileName) {
    const name = node_path_1.default.basename(fileName).toLowerCase();
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
function emitKind(fileName) {
    const kind = scriptKind(fileName);
    if (kind === "legacy") {
        return "legacy";
    }
    if (kind === "module" || kind === "header") {
        return "module";
    }
    return "flat";
}
function isTaggedScript(fileName) {
    const kind = scriptKind(fileName);
    return kind === "server" || kind === "client" || kind === "plugin" || kind === "legacy";
}
function siblingHeader(implPath) {
    if (!implPath || isHeaderFile(implPath)) {
        return null;
    }
    const dir = node_path_1.default.dirname(implPath);
    const stem = fileStem(implPath);
    const candidate = node_path_1.default.join(dir, `${stem}.clh`);
    if (node_fs_1.default.existsSync(candidate)) {
        return candidate;
    }
    return null;
}
function collectSources(dir, files = []) {
    if (!node_fs_1.default.existsSync(dir)) {
        return files;
    }
    for (const entry of node_fs_1.default.readdirSync(dir, { withFileTypes: true })) {
        const full = node_path_1.default.join(dir, entry.name);
        if (entry.isDirectory()) {
            collectSources(full, files);
        }
        else if (isSourceFile(entry.name) && !(0, index_js_1.isGeneratedHeader)(full)) {
            files.push(full);
        }
    }
    return files;
}
