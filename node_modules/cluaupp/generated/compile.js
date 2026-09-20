"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.compileSource = compileSource;
exports.compileService = compileService;
exports.compileServiceAsync = compileServiceAsync;
const node_path_1 = __importDefault(require("node:path"));
const runner_js_1 = require("./clpp/runner.js");
const postprocess_js_1 = require("./clpp/postprocess.js");
const paths_js_1 = require("./clpp/paths.js");
function compileArgs(source, fileName, options) {
    const relative = (options.relativeName || fileName || "input.clpp").replace(/\\/g, "/");
    const outName = options.outName || (0, paths_js_1.toLuauPath)(relative);
    const header = options.filePath ? (0, paths_js_1.siblingHeader)(options.filePath) : null;
    const skipInit = options.skipInit === true || (0, postprocess_js_1.shouldSkipInit)(relative, Boolean(header));
    const diskPath = options.filePath ? node_path_1.default.resolve(options.filePath) : null;
    return {
        request: {
            source,
            fileName: diskPath ? diskPath.replace(/\\/g, "/") : relative,
            strict: options.strict,
            cwd: diskPath ? node_path_1.default.dirname(diskPath) : options.srcDir,
        },
        relative,
        outName,
        skipInit,
        options,
    };
}
function finishArtifact(artifact, relative, outName, options, skipInit, source) {
    const luau = (0, postprocess_js_1.clppLuauToGame)(artifact, {
        relativeName: relative,
        outName,
        srcDir: options.srcDir,
        rootDir: options.rootDir,
        strict: options.strict,
        skipInit,
        source,
    });
    return {
        kind: (0, paths_js_1.emitKind)(relative),
        plan: { kind: (0, paths_js_1.emitKind)(relative), strict: options.strict === true },
        files: [{ name: outName, contents: luau }],
        stale: [],
    };
}
function compileSource(source, fileName, options = {}) {
    return compileService(source, fileName, options).files[0]?.contents ?? "";
}
function compileService(source, fileName, options = {}) {
    const args = compileArgs(source, fileName, options);
    const artifact = (0, runner_js_1.compileViaClpp)(args.request);
    return finishArtifact(artifact, args.relative, args.outName, args.options, args.skipInit, source);
}
async function compileServiceAsync(source, fileName, options = {}) {
    const args = compileArgs(source, fileName, options);
    const artifact = await (0, runner_js_1.compileViaClppAsync)(args.request);
    return finishArtifact(artifact, args.relative, args.outName, args.options, args.skipInit, source);
}
