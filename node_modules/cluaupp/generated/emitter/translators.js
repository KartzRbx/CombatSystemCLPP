"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.translateCppType = translateCppType;
exports.translateGetService = translateGetService;
exports.translateConstant = translateConstant;
exports.translateAlias = translateAlias;
exports.translateStruct = translateStruct;
exports.translateFunction = translateFunction;
const compile_js_1 = require("../compile.js");
const TYPE_MAP = {
    "std::string": "string",
    "std::string_view": "string",
    string: "string",
    string_view: "string",
    bool: "boolean",
    int: "number",
    int8_t: "number",
    int16_t: "number",
    int32_t: "number",
    int64_t: "number",
    uint8_t: "number",
    uint16_t: "number",
    uint32_t: "number",
    uint64_t: "number",
    float: "number",
    double: "number",
    size_t: "number",
    void: "()",
    auto: "any",
};
function translateCppType(cppType) {
    const trimmed = cppType
        .replace(/\b(?:const|constexpr|volatile|static|inline|restrict)\b/g, "")
        .replace(/\s+/g, " ")
        .replace(/&/g, "")
        .replace(/\*/g, "")
        .trim();
    if (!trimmed) {
        return "any";
    }
    if (TYPE_MAP[trimmed]) {
        return TYPE_MAP[trimmed];
    }
    const generic = trimmed.match(/^(?:std::)?(?:vector|array|span|LuaArray)\s*<\s*([^>]+)\s*>$/);
    if (generic) {
        return `{${translateCppType(generic[1])}}`;
    }
    const optional = trimmed.match(/^(?:std::)?optional\s*<\s*([^>]+)\s*>$/);
    if (optional) {
        return `${translateCppType(optional[1])}?`;
    }
    return trimmed.replace(/^::/, "");
}
function translateGetService(node) {
    const functionNode = node.childForFieldName("function") || node.namedChildren[0];
    if (!functionNode) {
        return null;
    }
    const text = functionNode.text.replace(/\s+/g, "");
    const generic = text.match(/GetService<(\w+)>/);
    if (generic) {
        return generic[1];
    }
    if (!text.includes("GetService")) {
        return null;
    }
    const args = functionNode.namedChildren.find((child) => child.type === "template_argument_list");
    if (args) {
        const ident = args.namedChildren.find((child) => child.type === "type_identifier" || child.type === "identifier");
        if (ident) {
            return ident.text;
        }
    }
    const callText = node.text.replace(/\s+/g, "");
    const match = callText.match(/GetService<(\w+)>/);
    return match ? match[1] : null;
}
function translateConstant(node) {
    const declarator = node.childForFieldName("declarator");
    if (!declarator) {
        return null;
    }
    const name = identifierOf(declarator);
    const valueNode = node.childForFieldName("value") ||
        declarator.childForFieldName("value") ||
        namedOf(declarator, "initializer") ||
        node.namedChildren[node.namedChildren.length - 1];
    if (!name || !valueNode || valueNode === declarator) {
        return null;
    }
    let value = valueNode.text.replace(/;$/, "").trim();
    if (value.startsWith("=")) {
        value = value.slice(1).trim();
    }
    if (!value) {
        return null;
    }
    return `const ${name} = ${value}`;
}
function translateAlias(node, mapType) {
    const nameNode = node.childForFieldName("name") || namedOf(node, "type_identifier") || node.namedChildren[1];
    const typeNode = node.childForFieldName("type") || namedOf(node, "type_descriptor") || node.namedChildren[0];
    if (!nameNode || !typeNode) {
        return null;
    }
    return `type ${nameNode.text} = ${mapType(typeNode.text)}`;
}
function translateStruct(node, mapType) {
    const nameNode = node.childForFieldName("name") || namedOf(node, "type_identifier");
    const body = node.childForFieldName("body") || namedOf(node, "field_declaration_list");
    if (!nameNode) {
        return null;
    }
    if (!body) {
        return `type ${nameNode.text} = {}`;
    }
    const fields = [];
    for (const field of body.namedChildren) {
        if (field.type !== "field_declaration") {
            continue;
        }
        const fieldType = field.childForFieldName("type");
        const fieldDecl = field.childForFieldName("declarator");
        const fieldName = fieldDecl ? identifierOf(fieldDecl) : namedOf(field, "field_identifier")?.text;
        if (!fieldName) {
            continue;
        }
        fields.push(`\t${fieldName}: ${mapType(fieldType?.text || "any")},`);
    }
    if (fields.length === 0) {
        return `type ${nameNode.text} = {}`;
    }
    return `type ${nameNode.text} = {\n${fields.join("\n")}\n}`;
}
function translateFunction(node, fileName) {
    try {
        const luau = (0, compile_js_1.compileSource)(node.text, fileName, { skipHeader: true });
        const trimmed = String(luau || "").trim();
        return trimmed || null;
    }
    catch {
        const name = identifierOf(node.childForFieldName("declarator") || node) || "fn";
        return `-- function ${name} (não traduzida)`;
    }
}
function identifierOf(node) {
    if (node.type === "identifier" || node.type === "field_identifier" || node.type === "type_identifier") {
        return node.text;
    }
    const direct = node.childForFieldName("declarator") || namedOf(node, "identifier") || namedOf(node, "field_identifier");
    if (direct) {
        return identifierOf(direct);
    }
    for (const child of node.namedChildren) {
        const found = identifierOf(child);
        if (found) {
            return found;
        }
    }
    return null;
}
function namedOf(node, type) {
    return node.namedChildren.find((child) => child.type === type) || null;
}
