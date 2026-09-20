"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.transpileSource = transpileSource;
exports.transpileSourceAsync = transpileSourceAsync;
exports.outputNameFor = outputNameFor;
const node_path_1 = __importDefault(require("node:path"));
const compile_js_1 = require("./compile.js");
function transpileSource(source, fileName, options, _mapper) {
    return (0, compile_js_1.compileService)(source, fileName, options);
}
function transpileSourceAsync(source, fileName, options, _mapper) {
    return (0, compile_js_1.compileServiceAsync)(source, fileName, options);
}
function outputNameFor(inputFile, outputPath) {
    if (/\.luau$/i.test(outputPath)) {
        return outputPath;
    }
    const base = node_path_1.default.basename(inputFile).replace(/\.(clpp|clp|clh)$/i, ".luau");
    return node_path_1.default.join(outputPath, base);
}
