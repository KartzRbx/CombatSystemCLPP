"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.emit = emit;
// @ts-nocheck
const api_js_1 = require("./api.js");
const libs_js_1 = require("./libs.js");
function emit(ast, options = {}) {
    const strict = options.strict === true;
    const lines = [];
    if (!options.skipHeader) {
        if (strict) {
            lines.push("--!strict");
        }
        lines.push("-- Compiled by Cluaupp — C++ × Luau");
        lines.push("");
    }
    const indentOf = (n) => "\t".repeat(n);
    let switchId = 0;
    const classOwners = new Set();
    const classFields = new Set();
    const classMethods = new Set();
    for (const decl of ast.body || []) {
        if (decl.owner) {
            classOwners.add(decl.owner);
        }
        if (decl.type === "decl" && decl.owner) {
            classFields.add(decl.name);
        }
        if ((decl.type === "function" || decl.type === "proto") && decl.owner && decl.name) {
            classMethods.add(decl.name);
        }
    }
    const ownedFns = (ast.body || []).filter((decl) => decl.type === "function");
    const hasOwnedMethods = ownedFns.some((decl) => Boolean(decl.owner));
    const classModule = ownedFns.length > 0 && ownedFns.every((decl) => Boolean(decl.owner));
    const nestedTypes = new Set();
    for (const decl of ast.body || []) {
        if (decl.type === "decl" && decl.owner && decl.valueType && classOwners.has(decl.valueType) && decl.valueType !== decl.owner) {
            nestedTypes.add(decl.valueType);
        }
    }
    const structRoots = [...classOwners].filter((name) => !nestedTypes.has(name));
    const structModule = !classModule && ownedFns.length === 0 && structRoots.length > 0;
    const localNames = new Set();
    let selfOwner = null;
    const isBareGlobal = (name) => {
        return (name === "print" ||
            name === "warn" ||
            name === "error" ||
            name === "game" ||
            name === "workspace" ||
            name === "script" ||
            name === "cout" ||
            name === "cerr" ||
            name === "endl" ||
            (0, libs_js_1.isLibraryType)(name) ||
            (0, api_js_1.isInstanceType)(name) ||
            (0, api_js_1.isDatatype)(name));
    };
    const emitSelfIdent = (name) => {
        if (name === "this") {
            return "self";
        }
        if (!selfOwner || localNames.has(name) || isBareGlobal(name)) {
            return name;
        }
        if (classFields.has(name)) {
            return `self.${name}`;
        }
        return name;
    };
    const emitMethodArg = (arg) => {
        if (arg && arg.type === "ident" && selfOwner && classMethods.has(arg.name) && !localNames.has(arg.name)) {
            return `function(...) self:${arg.name}(...) end`;
        }
        return emitExpr(arg);
    };
    const flattenShift = (node) => {
        const parts = [];
        let current = node;
        while (current && current.type === "binary" && current.op === "<<") {
            parts.unshift(current.right);
            current = current.left;
        }
        return { stream: current, args: parts };
    };
    const isEndl = (node) => node && node.type === "ident" && node.name === "endl";
    const streamPrint = (stream) => {
        if (!stream) {
            return null;
        }
        if (stream.type === "ident") {
            if (stream.name === "cout") {
                return "print";
            }
            if (stream.name === "cerr") {
                return "warn";
            }
            return null;
        }
        if (stream.type === "member" && stream.object && stream.object.type === "ident" && stream.object.name === "cout") {
            const mapped = { print: "print", warn: "warn", error: "error", ping: "print", endl: "print" };
            return mapped[stream.name] || "print";
        }
        return null;
    };
    const emitCout = (node) => {
        const { stream, args } = flattenShift(node);
        const fn = streamPrint(stream);
        if (!fn) {
            return null;
        }
        const linesOut = [];
        let current = [];
        const flush = () => {
            if (current.length === 0) {
                return;
            }
            linesOut.push(`${fn}(${current.map(emitExpr).join(", ")})`);
            current = [];
        };
        for (const arg of args) {
            if (isEndl(arg)) {
                flush();
                continue;
            }
            current.push(arg);
        }
        flush();
        if (linesOut.length === 0) {
            linesOut.push(`${fn}()`);
        }
        return linesOut;
    };
    const isStringConcatCall = (node) => node && node.type === "call" && !node.object && node.name === "string_concat";
    const emitStringConcat = (args) => {
        const parts = (args || []).map(emitExpr);
        if (parts.length === 0) {
            return `""`;
        }
        if (parts.length === 1) {
            return parts[0];
        }
        return `(${parts.join(" .. ")})`;
    };
    const isStringExpr = (node) => {
        if (!node) {
            return false;
        }
        if (node.type === "string") {
            return true;
        }
        if (isStringConcatCall(node)) {
            return true;
        }
        if (node.type === "binary" && node.op === "+" && (isStringExpr(node.left) || isStringExpr(node.right))) {
            return true;
        }
        if (node.type === "member" && (node.name === "Name" || node.name === "Text" || node.name === "DisplayName")) {
            return true;
        }
        return false;
    };
    const emitExpr = (node) => {
        if (!node) {
            return "nil";
        }
        switch (node.type) {
            case "null":
                return "nil";
            case "bool":
                return node.value ? "true" : "false";
            case "number":
                return node.value;
            case "string":
                return `"${node.value}"`;
            case "ident":
                return emitSelfIdent(node.name);
            case "initlist": {
                const entries = (node.fields || []).map((field) => `${field.name} = ${emitExpr(field.value)}`);
                if (entries.length === 0) {
                    return "{}";
                }
                return `{ ${entries.join(", ")} }`;
            }
            case "cast":
                if (node.valueType === "void") {
                    return emitExpr(node.argument);
                }
                return emitExpr(node.argument);
            case "lambda": {
                const params = (node.params || [])
                    .map((param) => {
                    if (typeof param === "string") {
                        return param;
                    }
                    const typeAnn = (0, api_js_1.luauType)(param.valueType);
                    return typeAnn ? `${param.name}: ${typeAnn}` : param.name;
                })
                    .join(", ");
                const inner = [];
                for (const stmt of node.body || []) {
                    inner.push(...emitStmt(stmt, 1));
                }
                const body = inner.length > 0 ? `\n${inner.join("\n")}\n` : "\n";
                return `function(${params})${body}end`;
            }
            case "unary": {
                const inner = emitExpr(node.argument);
                if (node.op === "!") {
                    return `not ${inner}`;
                }
                return `-${inner}`;
            }
            case "getService":
                return `game:GetService("${node.service}")`;
            case "new": {
                if ((0, libs_js_1.isLibraryType)(node.className) || !(0, api_js_1.isInstanceType)(node.className)) {
                    const args = node.args.map(emitExpr).join(", ");
                    return `${node.className}.new(${args})`;
                }
                return `Instance.new("${node.className}")`;
            }
            case "member":
                return `${emitExpr(node.object)}.${node.name}`;
            case "call": {
                if (isStringConcatCall(node)) {
                    return emitStringConcat(node.args);
                }
                const args = node.args.map(emitMethodArg).join(", ");
                if (!node.object) {
                    if ((0, api_js_1.isDatatype)(node.name)) {
                        return `${node.name}.new(${args})`;
                    }
                    if (selfOwner && classMethods.has(node.name) && !localNames.has(node.name)) {
                        return `self:${node.name}(${args})`;
                    }
                    return `${node.name}(${args})`;
                }
                const obj = emitExpr(node.object);
                if (classMethods.has(node.name) && !localNames.has(node.name)) {
                    return `${obj}:${node.name}(${args})`;
                }
                if (node.access === "::" && node.object.type === "ident" && node.object.name === "cout") {
                    if (node.name === "endl") {
                        return "print()";
                    }
                    const mapped = { print: "print", warn: "warn", error: "error", ping: "print" };
                    return `${mapped[node.name] || "print"}(${args})`;
                }
                if (node.access === "::") {
                    if (libs_js_1.MODULE_COLON.has(node.name)) {
                        return `${obj}:${node.name}(${args})`;
                    }
                    const staticNs = node.object.type === "ident" &&
                        ((0, libs_js_1.isLibraryType)(node.object.name) ||
                            (0, api_js_1.isDatatype)(node.object.name) ||
                            node.object.name === "DataService" ||
                            node.object.name === "FormatNumber" ||
                            node.object.name === "Enum");
                    if (staticNs) {
                        return `${obj}.${node.name}(${args})`;
                    }
                    return `${obj}:${node.name}(${args})`;
                }
                if ((0, api_js_1.isDatatype)(obj) || (node.object.type === "ident" && (0, api_js_1.isDatatype)(node.object.name))) {
                    return `${obj}.${node.name}(${args})`;
                }
                const colon = (0, api_js_1.isMethod)(node.name) || (0, libs_js_1.isLibraryMethod)(node.name);
                return `${obj}${colon ? ":" : "."}${node.name}(${args})`;
            }
            case "assign":
                return `${emitExpr(node.left)} = ${emitExpr(node.right)}`;
            case "binary": {
                if (node.op === "<<") {
                    const printed = emitCout(node);
                    if (printed) {
                        return printed.join("; ");
                    }
                }
                if (node.op === "+" && (isStringExpr(node.left) || isStringExpr(node.right))) {
                    return `${emitExpr(node.left)} .. ${emitExpr(node.right)}`;
                }
                const ops = { "!=": "~=", "&&": "and", "||": "or" };
                const op = ops[node.op] || node.op;
                return `${emitExpr(node.left)} ${op} ${emitExpr(node.right)}`;
            }
            default:
                return "nil";
        }
    };
    const inferredType = (node) => {
        const created = node.value;
        if (created && created.type === "new" && ((0, api_js_1.isInstanceType)(created.className) || (0, libs_js_1.isLibraryType)(created.className) || (0, api_js_1.isDatatype)(created.className))) {
            return created.className;
        }
        if (created && created.type === "call" && !created.object && (0, api_js_1.isDatatype)(created.name)) {
            return created.name;
        }
        if (created && created.type === "getService") {
            return created.service;
        }
        const fromCpp = (0, api_js_1.luauType)(node.valueType);
        if (fromCpp && fromCpp !== "auto") {
            return fromCpp;
        }
        return null;
    };
    const emitNewDecl = (node, indent) => {
        const prefix = indentOf(indent);
        const typeAnn = inferredType(node);
        const created = node.value;
        if (node.owner && indent === 0 && classModule) {
            const value = node.value ? emitExpr(node.value) : "nil";
            if (created && created.type === "new" && (0, api_js_1.isInstanceType)(created.className) && !(0, libs_js_1.isLibraryType)(created.className)) {
                const linesOut = [`${prefix}${node.owner}.${node.name} = Instance.new("${created.className}")`];
                if (created.args[0]) {
                    linesOut.push(`${prefix}${node.owner}.${node.name}.Parent = ${emitExpr(created.args[0])}`);
                }
                return linesOut;
            }
            if (created && created.type === "new" && ((0, api_js_1.isDatatype)(created.className) || (0, libs_js_1.isLibraryType)(created.className))) {
                const args = created.args.map(emitExpr).join(", ");
                return [`${prefix}${node.owner}.${node.name} = ${created.className}.new(${args})`];
            }
            return [`${prefix}${node.owner}.${node.name} = ${value}`];
        }
        const kind = node.isConst ? "const" : "local";
        const typed = typeAnn ? `: ${typeAnn}` : "";
        if (created && created.type === "new" && (0, api_js_1.isInstanceType)(created.className) && !(0, libs_js_1.isLibraryType)(created.className)) {
            const linesOut = [`${prefix}${kind} ${node.name}${typed} = Instance.new("${created.className}")`];
            if (created.args[0]) {
                linesOut.push(`${prefix}${node.name}.Parent = ${emitExpr(created.args[0])}`);
            }
            return linesOut;
        }
        if (created && created.type === "new" && ((0, api_js_1.isDatatype)(created.className) || (0, libs_js_1.isLibraryType)(created.className))) {
            const args = created.args.map(emitExpr).join(", ");
            return [`${prefix}${kind} ${node.name}${typed} = ${created.className}.new(${args})`];
        }
        const value = node.value ? emitExpr(node.value) : "nil";
        if (!node.value && node.valueType && classOwners.has(node.valueType)) {
            return [`${prefix}${kind} ${node.name}${typed} = ${node.valueType}`];
        }
        return [`${prefix}${kind} ${node.name}${typed} = ${value}`];
    };
    const emitStmt = (node, indent) => {
        const prefix = indentOf(indent);
        switch (node.type) {
            case "decl":
                if (node.name) {
                    localNames.add(node.name);
                }
                return emitNewDecl(node, indent);
            case "expr": {
                const expr = node.expr;
                if (expr && expr.type === "cast" && expr.valueType === "void") {
                    return [];
                }
                if (expr && expr.type === "binary" && expr.op === "<<") {
                    const printed = emitCout(expr);
                    if (printed) {
                        return printed.map((line) => `${prefix}${line}`);
                    }
                }
                if (expr &&
                    expr.type === "assign" &&
                    expr.right &&
                    expr.right.type === "new" &&
                    (0, api_js_1.isInstanceType)(expr.right.className) &&
                    !(0, libs_js_1.isLibraryType)(expr.right.className)) {
                    const left = emitExpr(expr.left);
                    const linesOut = [`${prefix}${left} = Instance.new("${expr.right.className}")`];
                    if (expr.right.args[0]) {
                        linesOut.push(`${prefix}${left}.Parent = ${emitExpr(expr.right.args[0])}`);
                    }
                    return linesOut;
                }
                return [`${prefix}${emitExpr(expr)}`];
            }
            case "return":
                return node.value ? [`${prefix}return ${emitExpr(node.value)}`] : [`${prefix}return`];
            case "if": {
                const out = [`${prefix}if ${emitExpr(node.test)} then`];
                for (const stmt of node.consequent) {
                    out.push(...emitStmt(stmt, indent + 1));
                }
                if (node.alternate) {
                    out.push(`${prefix}else`);
                    for (const stmt of node.alternate) {
                        out.push(...emitStmt(stmt, indent + 1));
                    }
                }
                out.push(`${prefix}end`);
                return out;
            }
            case "while": {
                const out = [`${prefix}while ${emitExpr(node.test)} do`];
                for (const stmt of node.body) {
                    out.push(...emitStmt(stmt, indent + 1));
                }
                out.push(`${prefix}end`);
                return out;
            }
            case "foreach": {
                const out = [`${prefix}for _, ${node.name} in ${emitExpr(node.iter)} do`];
                for (const stmt of node.body) {
                    out.push(...emitStmt(stmt, indent + 1));
                }
                out.push(`${prefix}end`);
                return out;
            }
            case "break":
                return [`${prefix}break`];
            case "switch": {
                switchId += 1;
                const id = `__switch${switchId}`;
                const disc = node.discriminant;
                const simple = disc &&
                    (disc.type === "ident" || disc.type === "number" || disc.type === "string" || disc.type === "bool");
                const subject = simple ? emitExpr(disc) : id;
                const out = [`${prefix}repeat`];
                const inner = indent + 1;
                const innerP = indentOf(inner);
                if (!simple) {
                    out.push(`${innerP}local ${id} = ${emitExpr(disc)}`);
                }
                const regular = (node.cases || []).filter((item) => !item.isDefault);
                const fallback = (node.cases || []).find((item) => item.isDefault);
                const testOf = (item) => (item.values || []).map((value) => `${subject} == ${emitExpr(value)}`).join(" or ");
                for (let index = 0; index < regular.length; index += 1) {
                    const item = regular[index];
                    const keyword = index === 0 ? "if" : "elseif";
                    out.push(`${innerP}${keyword} ${testOf(item)} then`);
                    for (const stmt of item.body || []) {
                        out.push(...emitStmt(stmt, inner + 1));
                    }
                }
                if (fallback) {
                    if (regular.length === 0) {
                        for (const stmt of fallback.body || []) {
                            out.push(...emitStmt(stmt, inner));
                        }
                    }
                    else {
                        out.push(`${innerP}else`);
                        for (const stmt of fallback.body || []) {
                            out.push(...emitStmt(stmt, inner + 1));
                        }
                    }
                }
                if (regular.length > 0) {
                    out.push(`${innerP}end`);
                }
                out.push(`${prefix}until true`);
                return out;
            }
            default:
                return [];
        }
    };
    const paramList = (fn) => fn.params
        .map((param) => {
        if (typeof param === "string") {
            return param;
        }
        const typeAnn = (0, api_js_1.luauType)(param.valueType);
        return typeAnn ? `${param.name}: ${typeAnn}` : param.name;
    })
        .join(", ");
    const returnAnn = (fn) => {
        const typeAnn = (0, api_js_1.luauType)(fn.returnType);
        if (!typeAnn || typeAnn === "()") {
            return "";
        }
        return `: ${typeAnn}`;
    };
    const emitFieldLiteral = (decl) => {
        if (decl.value && decl.value.type === "initlist") {
            const inner = (decl.value.fields || [])
                .map((field) => `${field.name} = ${emitExpr(field.value)}`)
                .join(", ");
            return `{ ${inner} }`;
        }
        if (decl.valueType && nestedTypes.has(decl.valueType)) {
            const nested = (ast.body || []).filter((item) => item.type === "decl" && item.owner === decl.valueType);
            const inner = nested.map((item) => `${item.name} = ${emitFieldLiteral(item)}`).join(", ");
            return `{ ${inner} }`;
        }
        return decl.value ? emitExpr(decl.value) : "nil";
    };
    const emitStructConstructor = (root) => {
        const fields = (ast.body || []).filter((decl) => decl.type === "decl" && decl.owner === root);
        const inner = fields.map((field) => `\t\t${field.name} = ${emitFieldLiteral(field)},`).join("\n");
        lines.push(`const function ${root}()`);
        lines.push("	return {");
        if (inner) {
            lines.push(inner);
        }
        lines.push("	}");
        lines.push("end");
        lines.push("");
    };
    if (hasOwnedMethods) {
        for (const owner of classOwners) {
            lines.push(`local ${owner} = {}`);
            lines.push("");
        }
    }
    if (structModule) {
        for (const root of structRoots) {
            emitStructConstructor(root);
        }
        if (structRoots.length === 1) {
            lines.push(`return ${structRoots[0]}`);
        }
        else {
            lines.push("return {");
            for (const root of structRoots) {
                lines.push(`	${root} = ${root},`);
            }
            lines.push("}");
        }
        lines.push("");
        return lines.join("\n");
    }
    for (const decl of ast.body) {
        if (decl.type === "decl") {
            lines.push(...emitNewDecl(decl, 0));
            lines.push("");
            continue;
        }
        if (decl.type === "expr") {
            lines.push(emitExpr(decl.expr));
            lines.push("");
            continue;
        }
        if (decl.type !== "function") {
            continue;
        }
        selfOwner = decl.owner || null;
        localNames.clear();
        for (const param of decl.params || []) {
            const paramName = typeof param === "string" ? param : param.name;
            if (paramName) {
                localNames.add(paramName);
            }
        }
        if (decl.owner) {
            lines.push(`function ${decl.owner}:${decl.name}(${paramList(decl)})${returnAnn(decl)}`);
        }
        else {
            lines.push(`const function ${decl.name}(${paramList(decl)})${returnAnn(decl)}`);
        }
        for (const stmt of decl.body) {
            lines.push(...emitStmt(stmt, 1));
        }
        lines.push("end");
        lines.push("");
        selfOwner = null;
        localNames.clear();
    }
    const hasInit = ast.body.some((decl) => decl.type === "function" && decl.name === "init");
    if (classModule) {
        for (const owner of classOwners) {
            if (hasInit) {
                lines.push(`${owner}.Start = ${owner}.init`);
                lines.push(`${owner}.Init = ${owner}.init`);
            }
            lines.push(`return ${owner}`);
            lines.push("");
        }
    }
    else if (hasInit && !options.skipInit) {
        lines.push("init()");
        lines.push("");
    }
    return lines.join("\n");
}
