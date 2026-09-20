"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.ASTCollector = void 0;
exports.emptyState = emptyState;
const node_path_1 = __importDefault(require("node:path"));
const preprocess_js_1 = require("../preprocess.js");
const translators_js_1 = require("../emitter/translators.js");
function emptyState(strict = false) {
    return {
        robloxServices: new Set(),
        moduleRequires: new Map(),
        customTypes: [],
        constants: [],
        functions: [],
        headerLines: [],
        strict,
    };
}
class ASTCollector {
    mapper;
    context;
    state;
    constructor(mapper, context = { fileName: "input.cpp" }) {
        this.mapper = mapper;
        this.context = context;
        this.state = emptyState(context.strict === true);
    }
    collect(rootNode) {
        this.visit(rootNode, false);
        return this.state;
    }
    visit(node, inFunction) {
        if (node.type === "preproc_include") {
            this.collectInclude(node);
        }
        else if (node.type === "call_expression") {
            this.collectGetService(node);
        }
        else if (!inFunction && node.type === "function_definition") {
            this.visitChildren(node, true);
            return;
        }
        else if (!inFunction && node.type === "declaration") {
            this.collectDeclaration(node);
        }
        else if (!inFunction && (node.type === "type_definition" || node.type === "alias_declaration")) {
            this.collectAlias(node);
        }
        else if (!inFunction && (node.type === "struct_specifier" || node.type === "class_specifier")) {
            this.collectStruct(node);
        }
        else if (!inFunction && node.type === "preproc_call" && /pragma\s+strict/.test(node.text)) {
            this.state.strict = true;
        }
        this.visitChildren(node, inFunction);
    }
    visitChildren(node, inFunction) {
        for (let i = 0; i < node.childCount; i += 1) {
            const child = node.child(i);
            if (child) {
                this.visit(child, inFunction);
            }
        }
    }
    includeTarget(raw) {
        const from = this.context.sourcePath;
        if (!from) {
            return null;
        }
        const cleaned = raw.replace(/[<>'"]/g, "").trim();
        if (!cleaned || raw.includes("<")) {
            return null;
        }
        return node_path_1.default.resolve(node_path_1.default.dirname(from), cleaned);
    }
    isOwnHeader(raw) {
        const from = this.context.sourcePath;
        if (!from) {
            return false;
        }
        const target = this.includeTarget(raw);
        if (!target) {
            return false;
        }
        if (node_path_1.default.resolve(from) === target) {
            return true;
        }
        const header = (0, preprocess_js_1.siblingHeader)(from);
        return Boolean(header && node_path_1.default.resolve(header) === target);
    }
    collectInclude(node) {
        const pathNode = node.childForFieldName("path") || node.namedChildren[0] || node.child(1);
        if (!pathNode) {
            return;
        }
        if (this.isOwnHeader(pathNode.text)) {
            return;
        }
        const resolved = this.mapper.resolveIncludeToRequire(pathNode.text, this.context.sourcePath);
        if (resolved) {
            this.state.moduleRequires.set(resolved.alias, resolved.path);
        }
    }
    collectGetService(node) {
        const service = (0, translators_js_1.translateGetService)(node);
        if (service) {
            this.state.robloxServices.add(service);
        }
    }
    collectDeclaration(node) {
        const text = node.text.trimStart();
        if (!(text.startsWith("const") || text.startsWith("constexpr"))) {
            return;
        }
        const translated = (0, translators_js_1.translateConstant)(node);
        if (translated) {
            this.state.constants.push(translated);
        }
    }
    collectAlias(node) {
        const translated = (0, translators_js_1.translateAlias)(node, translators_js_1.translateCppType);
        if (translated) {
            this.state.customTypes.push(translated);
        }
    }
    collectStruct(node) {
        const translated = (0, translators_js_1.translateStruct)(node, translators_js_1.translateCppType);
        if (translated) {
            this.state.customTypes.push(translated);
        }
    }
}
exports.ASTCollector = ASTCollector;
