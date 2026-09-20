"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.emitHeaderModule = emitHeaderModule;
exports.primaryHeaderName = primaryHeaderName;
exports.collectHeaderShape = collectHeaderShape;
// @ts-nocheck
const node_path_1 = __importDefault(require("node:path"));
const api_js_1 = require("./api.js");
function fileStem(fileName) {
    return node_path_1.default.basename(String(fileName || "module")).replace(/\.(h|hpp|hh|cpp|cc|cxx|c)$/i, "");
}
function emitValue(node) {
    if (!node) {
        return "nil";
    }
    if (node.type === "number") {
        return node.value;
    }
    if (node.type === "string") {
        return `"${node.value}"`;
    }
    if (node.type === "bool") {
        return node.value ? "true" : "false";
    }
    if (node.type === "null") {
        return "nil";
    }
    if (node.type === "initlist") {
        const inner = (node.fields || []).map((field) => `${field.name} = ${emitValue(field.value)}`).join(", ");
        return `{ ${inner} }`;
    }
    return "nil";
}
function collectHeaderShape(ast, fileName) {
    const owners = new Map();
    const ensure = (name) => {
        if (!owners.has(name)) {
            owners.set(name, { fields: [], methods: [] });
        }
        return owners.get(name);
    };
    const freeProtos = [];
    const consts = [];
    for (const decl of ast.body || []) {
        if (decl.type === "decl" && decl.owner) {
            ensure(decl.owner).fields.push(decl);
            continue;
        }
        if (decl.type === "decl") {
            consts.push(decl);
            continue;
        }
        if ((decl.type === "proto" || decl.type === "function") && decl.owner) {
            ensure(decl.owner).methods.push(decl);
            continue;
        }
        if (decl.type === "proto") {
            freeProtos.push(decl);
        }
    }
    const nested = new Set();
    for (const [ownerName, spec] of owners) {
        for (const field of spec.fields) {
            if (field.valueType && owners.has(field.valueType) && field.valueType !== ownerName) {
                nested.add(field.valueType);
            }
        }
    }
    const roots = [...owners.keys()].filter((name) => !nested.has(name));
    const withMethods = roots.filter((name) => ensure(name).methods.length > 0);
    const stem = fileStem(fileName);
    let primary = withMethods[0] || (freeProtos.length ? stem : roots[0] || stem);
    return { owners, nested, roots, freeProtos, consts, primary, stem };
}
function primaryHeaderName(ast, fileName) {
    return collectHeaderShape(ast, fileName).primary;
}
function methodType(fn, owner) {
    const params = [];
    if (owner) {
        params.push(`self: ${owner}`);
    }
    for (const param of fn.params || []) {
        if (typeof param === "string") {
            params.push(param);
            continue;
        }
        const typeAnn = (0, api_js_1.luauType)(param.valueType);
        params.push(typeAnn ? `${param.name}: ${typeAnn}` : param.name);
    }
    const ret = (0, api_js_1.luauType)(fn.returnType);
    const retAnn = !ret || ret === "()" ? "()" : ret;
    return `(${params.join(", ")}) -> ${retAnn}`;
}
function fieldType(field, owners) {
    if (field.valueType && owners.has(field.valueType)) {
        return field.valueType;
    }
    return (0, api_js_1.luauType)(field.valueType) || "any";
}
function emitExportType(lines, name, spec, owners, extraMethods, extraFields) {
    lines.push(`export type ${name} = {`);
    const seen = new Set();
    for (const field of [...((spec && spec.fields) || []), ...(extraFields || [])]) {
        if (!field.name || seen.has(field.name)) {
            continue;
        }
        seen.add(field.name);
        lines.push(`	${field.name}: ${fieldType(field, owners)},`);
    }
    for (const method of (spec && spec.methods) || []) {
        if (!method.name || seen.has(method.name)) {
            continue;
        }
        seen.add(method.name);
        lines.push(`	${method.name}: ${methodType(method, name)},`);
    }
    for (const method of extraMethods || []) {
        if (!method.name || seen.has(method.name)) {
            continue;
        }
        seen.add(method.name);
        lines.push(`	${method.name}: ${methodType(method, null)},`);
    }
    lines.push("}");
    lines.push("");
}
function emitDataConstructor(lines, name, spec, owners) {
    const emitField = (field) => {
        if (field.valueType && owners.has(field.valueType)) {
            const nested = owners.get(field.valueType);
            const inner = nested.fields.map((item) => `${item.name} = ${emitValue(item.value)}`).join(", ");
            return `{ ${inner} }`;
        }
        if (field.value && field.value.type === "initlist") {
            return emitValue(field.value);
        }
        return emitValue(field.value);
    };
    lines.push(`const function ${name}(): ${name}`);
    lines.push("	return {");
    for (const field of spec.fields) {
        lines.push(`		${field.name} = ${emitField(field)},`);
    }
    lines.push("	}");
    lines.push("end");
    lines.push("");
}
function emitHeaderModule(ast, options = {}) {
    const strict = options.strict === true;
    const fileName = options.relativeName || options.filePath || "header.h";
    const shape = collectHeaderShape(ast, fileName);
    const lines = [];
    if (strict) {
        lines.push("--!strict");
    }
    lines.push("-- Compiled by Cluaupp — C++ × Luau");
    lines.push("");
    const typeOrder = [...shape.nested, ...shape.roots];
    for (const name of typeOrder) {
        const extra = name === shape.primary ? shape.freeProtos : [];
        emitExportType(lines, name, shape.owners.get(name), shape.owners, extra);
    }
    if (shape.freeProtos.length && !shape.owners.has(shape.primary)) {
        emitExportType(lines, shape.primary, { fields: [], methods: [] }, shape.owners, shape.freeProtos, shape.consts);
    }
    for (const decl of shape.consts) {
        const typeAnn = (0, api_js_1.luauType)(decl.valueType);
        const typed = typeAnn ? `: ${typeAnn}` : "";
        lines.push(`const ${decl.name}${typed} = ${emitValue(decl.value)}`);
    }
    if (shape.consts.length) {
        lines.push("");
    }
    const hasMethods = shape.roots.some((name) => shape.owners.get(name).methods.length > 0) || shape.freeProtos.length > 0;
    const implName = hasMethods ? options.headerImplName : null;
    if (!hasMethods && shape.roots.length > 0) {
        for (const name of shape.roots) {
            emitDataConstructor(lines, name, shape.owners.get(name), shape.owners);
        }
        lines.push(`return ${shape.primary}`);
        lines.push("");
        return lines.join("\n");
    }
    if (!hasMethods && shape.consts.length > 0) {
        lines.push("return {");
        for (const decl of shape.consts) {
            lines.push(`	${decl.name} = ${decl.name},`);
        }
        lines.push("}");
        lines.push("");
        return lines.join("\n");
    }
    const tableName = shape.primary;
    const spec = shape.owners.get(tableName) || { fields: [], methods: [] };
    const methods = [...spec.methods, ...shape.freeProtos];
    lines.push(`const ${tableName}: ${tableName} = {`);
    if (implName) {
        for (const field of spec.fields) {
            if (field.valueType && shape.owners.has(field.valueType) && field.valueType !== tableName) {
                continue;
            }
            lines.push(`	${field.name} = ${implName}.${field.name},`);
        }
        for (const method of methods) {
            lines.push(`	${method.name} = ${implName}.${method.name},`);
        }
    }
    for (const decl of shape.consts) {
        lines.push(`	${decl.name} = ${decl.name},`);
    }
    lines.push("}");
    lines.push("");
    lines.push(`return ${tableName}`);
    lines.push("");
    return lines.join("\n");
}
