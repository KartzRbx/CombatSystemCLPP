"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.pkg = exports.projectRoot = void 0;
const node_module_1 = require("node:module");
const node_path_1 = __importDefault(require("node:path"));
exports.projectRoot = node_path_1.default.resolve(__dirname, "..");
const fromPkg = (0, node_module_1.createRequire)(node_path_1.default.join(exports.projectRoot, "package.json"));
exports.pkg = fromPkg("./package.json");
