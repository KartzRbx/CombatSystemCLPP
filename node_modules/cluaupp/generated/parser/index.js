"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.createCppParserSync = createCppParserSync;
exports.parseCpp = parseCpp;
const tree_sitter_1 = __importDefault(require("tree-sitter"));
const node_module_1 = require("node:module");
const node_path_1 = __importDefault(require("node:path"));
const package_info_js_1 = require("../package-info.js");
const nodeRequire = (0, node_module_1.createRequire)(node_path_1.default.join(package_info_js_1.projectRoot, "package.json"));
function createCppParserSync() {
    try {
        const Cpp = nodeRequire("tree-sitter-cpp");
        const parser = new tree_sitter_1.default();
        parser.setLanguage(Cpp);
        parser.parse("int main() { return 0; }");
        return parser;
    }
    catch {
        return null;
    }
}
function parseCpp(source, parser = createCppParserSync()) {
    if (!parser) {
        return null;
    }
    return parser.parse(source);
}
