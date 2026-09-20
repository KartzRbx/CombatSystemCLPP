"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.parse = parse;
// @ts-nocheck
const lex_js_1 = require("./lex.js");
function parse(source, fileName) {
    const tokens = (0, lex_js_1.tokenize)(source);
    let i = 0;
    const peek = (offset = 0) => tokens[i + offset] || tokens[tokens.length - 1];
    const at = (type, value) => {
        const token = peek();
        if (type && token.type !== type) {
            return false;
        }
        if (value !== undefined && token.value !== value) {
            return false;
        }
        return true;
    };
    const eat = (type, value) => {
        if (!at(type, value)) {
            const token = peek();
            throw error(`expected ${value || type}, got '${token.value}'`, token);
        }
        const token = peek();
        i += 1;
        return token;
    };
    const error = (message, token = peek()) => {
        const err = new Error(`${fileName}:${token.line}:${token.col}: ${message}`);
        err.line = token.line;
        err.col = token.col;
        return err;
    };
    const skipSemicolons = () => {
        while (at("op", ";")) {
            i += 1;
        }
    };
    const skipTemplate = () => {
        if (!at("op", "<")) {
            return null;
        }
        eat("op", "<");
        const name = eat("ident").value;
        eat("op", ">");
        return name;
    };
    const CAST_NAMES = new Set(["static_cast", "const_cast", "reinterpret_cast", "dynamic_cast"]);
    function skipSpecifiers() {
        let isConst = false;
        while (at("kw", "static") || at("kw", "inline") || at("kw", "constexpr") || at("kw", "const")) {
            if (at("kw", "constexpr") || at("kw", "const")) {
                isConst = true;
            }
            i += 1;
        }
        return isConst;
    }
    function looksLikePrimaryStart() {
        if (at("ident") || at("number") || at("string")) {
            return true;
        }
        if (at("kw", "true") || at("kw", "false") || at("kw", "nullptr") || at("kw", "new")) {
            return true;
        }
        return at("op", "(") || at("op", "{") || at("op", "[") || at("op", "-") || at("op", "!");
    }
    function parseLambda() {
        eat("op", "[");
        while (!at("eof") && !at("op", "]")) {
            i += 1;
        }
        eat("op", "]");
        const params = [];
        if (at("op", "(")) {
            i += 1;
            if (!at("op", ")")) {
                params.push(parseParam());
                while (at("op", ",")) {
                    i += 1;
                    params.push(parseParam());
                }
            }
            eat("op", ")");
        }
        const body = parseBlock();
        return { type: "lambda", params, body };
    }
    function parseNamedCast() {
        i += 1;
        eat("op", "<");
        const valueType = parseType() || "any";
        eat("op", ">");
        const args = parseArgs();
        return { type: "cast", valueType, argument: args[0] || { type: "null" } };
    }
    function parseParenPrimary() {
        eat("op", "(");
        const saved = i;
        skipSpecifiers();
        const valueType = parseType();
        if (valueType && at("op", ")")) {
            i += 1;
            if (looksLikePrimaryStart()) {
                return { type: "cast", valueType, argument: parseUnary() };
            }
        }
        i = saved;
        const expr = parseExpr();
        eat("op", ")");
        return expr;
    }
    function eatGeneric() {
        let text = "";
        let depth = 0;
        while (!at("eof")) {
            const token = peek();
            if (at("op", "<")) {
                depth += 1;
                text += "<";
                i += 1;
                continue;
            }
            if (at("op", ">")) {
                depth -= 1;
                text += ">";
                i += 1;
                if (depth === 0) {
                    return text;
                }
                continue;
            }
            if (token.type === "string") {
                text += `"${token.value}"`;
            }
            else {
                text += token.value;
            }
            i += 1;
        }
        return text;
    }
    function parseType() {
        if (at("kw", "const")) {
            i += 1;
        }
        let name = null;
        if (at("kw", "auto") || at("kw", "void") || at("kw", "int") || at("kw", "bool") || at("kw", "float") || at("kw", "double")) {
            name = eat("kw").value;
        }
        else if (at("ident")) {
            name = eat("ident").value;
            while (at("op", "::")) {
                i += 1;
                if (at("ident")) {
                    name += `::${eat("ident").value}`;
                }
            }
        }
        else {
            return null;
        }
        if (at("op", "<")) {
            name += eatGeneric();
        }
        while (at("op", "*")) {
            i += 1;
        }
        return name;
    }
    function parseArgs() {
        eat("op", "(");
        const args = [];
        if (!at("op", ")")) {
            args.push(parseExpr());
            while (at("op", ",")) {
                i += 1;
                args.push(parseExpr());
            }
        }
        eat("op", ")");
        return args;
    }
    function parseInitList() {
        eat("op", "{");
        const fields = [];
        while (!at("op", "}") && !at("eof")) {
            if (at("op", ".")) {
                i += 1;
                const name = eat("ident").value;
                eat("op", "=");
                fields.push({ name, value: parseExpr() });
            }
            else {
                throw error("expected designated initializer .Field = value");
            }
            if (at("op", ",")) {
                i += 1;
            }
            else {
                break;
            }
        }
        eat("op", "}");
        return { type: "initlist", fields };
    }
    function parsePrimary() {
        if (at("kw", "true") || at("kw", "false")) {
            return { type: "bool", value: eat("kw").value === "true" };
        }
        if (at("kw", "nullptr")) {
            i += 1;
            return { type: "null" };
        }
        if (at("number")) {
            return { type: "number", value: eat("number").value };
        }
        if (at("string")) {
            return { type: "string", value: eat("string").value };
        }
        if (at("kw", "new")) {
            i += 1;
            const className = eat("ident").value;
            const args = at("op", "(") ? parseArgs() : [];
            return { type: "new", className, args };
        }
        if (at("ident", "GetService") && peek(1).value === "<") {
            i += 1;
            const service = skipTemplate();
            eat("op", "(");
            eat("op", ")");
            return { type: "getService", service };
        }
        if (at("ident") && CAST_NAMES.has(peek().value) && peek(1).value === "<") {
            return parseNamedCast();
        }
        if (at("ident")) {
            return { type: "ident", name: eat("ident").value };
        }
        if (at("op", "[")) {
            return parseLambda();
        }
        if (at("op", "(")) {
            return parseParenPrimary();
        }
        if (at("op", "{")) {
            return parseInitList();
        }
        throw error("invalid expression");
    }
    function parseUnary() {
        if (at("op", "-") || at("op", "!")) {
            const op = eat("op").value;
            return { type: "unary", op, argument: parseUnary() };
        }
        return parsePostfix();
    }
    function parsePostfix() {
        let node = parsePrimary();
        for (;;) {
            if (at("op", "->") || at("op", ".") || at("op", "::")) {
                const access = eat("op").value;
                const name = eat("ident").value;
                if (name === "GetService" && at("op", "<")) {
                    const service = skipTemplate();
                    eat("op", "(");
                    eat("op", ")");
                    node = { type: "getService", service };
                    continue;
                }
                if (at("op", "(")) {
                    node = { type: "call", object: node, name, args: parseArgs(), access };
                }
                else {
                    node = { type: "member", object: node, name, access };
                }
                continue;
            }
            if (at("op", "(") && node.type === "ident") {
                node = { type: "call", object: null, name: node.name, args: parseArgs(), access: "." };
                continue;
            }
            if (at("op", "{") && (node.type === "ident" || node.type === "member")) {
                node = parseInitList();
                continue;
            }
            break;
        }
        return node;
    }
    function parseBinary() {
        let left = parseUnary();
        while (["==", "!=", "<=", ">=", "<", ">", "&&", "||", "+", "-", "*", "/"].includes(peek().value)) {
            const op = eat("op").value;
            const right = parseUnary();
            left = { type: "binary", op, left, right };
        }
        return left;
    }
    function parseShift() {
        let left = parseBinary();
        while (at("op", "<<")) {
            eat("op", "<<");
            const right = parseBinary();
            left = { type: "binary", op: "<<", left, right };
        }
        return left;
    }
    function parseExpr() {
        const left = parseShift();
        if (at("op", "=")) {
            i += 1;
            return { type: "assign", left, right: parseExpr() };
        }
        return left;
    }
    function parseBlock() {
        eat("op", "{");
        const body = [];
        while (!at("op", "}") && !at("eof")) {
            skipSemicolons();
            if (at("op", "}")) {
                break;
            }
            body.push(parseStmt());
            skipSemicolons();
        }
        eat("op", "}");
        return body;
    }
    function parseSwitch() {
        eat("kw", "switch");
        eat("op", "(");
        const discriminant = parseExpr();
        eat("op", ")");
        eat("op", "{");
        const cases = [];
        let current = null;
        const flush = () => {
            if (current) {
                cases.push(current);
                current = null;
            }
        };
        while (!at("eof") && !at("op", "}")) {
            skipSemicolons();
            if (at("op", "}")) {
                break;
            }
            if (at("kw", "case")) {
                i += 1;
                const value = parseExpr();
                eat("op", ":");
                if (current && current.body.length === 0 && !current.isDefault) {
                    current.values.push(value);
                }
                else {
                    flush();
                    current = { values: [value], body: [], isDefault: false };
                }
                continue;
            }
            if (at("kw", "default")) {
                i += 1;
                eat("op", ":");
                flush();
                current = { values: [], body: [], isDefault: true };
                continue;
            }
            if (!current) {
                throw error("switch body needs case or default before statements");
            }
            if (at("op", "{")) {
                current.body.push(...parseBlock());
                continue;
            }
            current.body.push(parseStmt());
        }
        flush();
        eat("op", "}");
        return { type: "switch", discriminant, cases };
    }
    function parseIf() {
        eat("kw", "if");
        eat("op", "(");
        const test = parseExpr();
        eat("op", ")");
        const consequent = at("op", "{") ? parseBlock() : [parseStmt()];
        let alternate = null;
        if (at("kw", "else")) {
            i += 1;
            alternate = at("op", "{") ? parseBlock() : [parseStmt()];
        }
        return { type: "if", test, consequent, alternate };
    }
    function parseFor() {
        eat("kw", "for");
        eat("op", "(");
        if (at("kw", "auto") || at("ident") || at("kw", "int") || at("kw", "const")) {
            const isConst = at("kw", "const");
            if (isConst) {
                i += 1;
            }
            parseType();
            const name = eat("ident").value;
            if (at("op", ":")) {
                i += 1;
                const iter = parseExpr();
                eat("op", ")");
                const body = at("op", "{") ? parseBlock() : [parseStmt()];
                return { type: "foreach", name, iter, body, isConst };
            }
        }
        throw error("only range-for is supported: for (auto* x : list)");
    }
    function parseDeclOrExpr() {
        const saved = i;
        const isConst = skipSpecifiers();
        const maybeType = parseType();
        if (maybeType && at("ident") && (peek(1).value === "=" || peek(1).value === ";")) {
            const name = eat("ident").value;
            let value = null;
            if (at("op", "=")) {
                i += 1;
                value = parseExpr();
            }
            return { type: "decl", name, valueType: maybeType, value, isConst: isConst || maybeType === "const" };
        }
        i = saved;
        return { type: "expr", expr: parseExpr() };
    }
    function parseStmt() {
        if (at("kw", "if")) {
            return parseIf();
        }
        if (at("kw", "switch")) {
            return parseSwitch();
        }
        if (at("kw", "for")) {
            return parseFor();
        }
        if (at("kw", "return")) {
            i += 1;
            const value = at("op", ";") || at("op", "}") ? null : parseExpr();
            return { type: "return", value };
        }
        if (at("kw", "break")) {
            i += 1;
            skipSemicolons();
            return { type: "break" };
        }
        if (at("kw", "while")) {
            i += 1;
            eat("op", "(");
            const test = parseExpr();
            eat("op", ")");
            const body = at("op", "{") ? parseBlock() : [parseStmt()];
            return { type: "while", test, body };
        }
        return parseDeclOrExpr();
    }
    function parseParam() {
        const valueType = parseType();
        if (at("ident")) {
            return { name: eat("ident").value, valueType };
        }
        return { name: "arg", valueType };
    }
    function parseQualifiedName() {
        const parts = [eat("ident").value];
        while (at("op", "::")) {
            i += 1;
            parts.push(eat("ident").value);
        }
        return {
            parts,
            name: parts[parts.length - 1],
            owner: parts.length > 1 ? parts.slice(0, -1).join("::") : null,
        };
    }
    function parseFunction() {
        skipSpecifiers();
        const returnType = parseType();
        if (!returnType || !at("ident")) {
            throw error("invalid function declaration");
        }
        const qualified = parseQualifiedName();
        eat("op", "(");
        const params = [];
        if (!at("op", ")")) {
            params.push(parseParam());
            while (at("op", ",")) {
                i += 1;
                params.push(parseParam());
            }
        }
        eat("op", ")");
        if (at("op", ";")) {
            i += 1;
            return { type: "proto", name: qualified.name, owner: qualified.owner, returnType, params };
        }
        const body = parseBlock();
        return { type: "function", name: qualified.name, owner: qualified.owner, returnType, params, body };
    }
    function parseStruct() {
        eat("kw");
        const name = at("ident") ? eat("ident").value : "_anon";
        if (at("op", ";")) {
            i += 1;
            return { type: "struct", name, fields: [], methods: [] };
        }
        eat("op", "{");
        const fields = [];
        const methods = [];
        while (!at("eof") && !at("op", "}")) {
            skipSemicolons();
            if (at("op", "}")) {
                break;
            }
            if (at("kw", "public") || at("kw", "private") || at("kw", "protected")) {
                i += 1;
                if (at("op", ":")) {
                    i += 1;
                }
                continue;
            }
            if (at("kw", "struct") || at("kw", "class")) {
                const nested = parseStruct();
                if (nested.instance) {
                    fields.push({
                        type: "decl",
                        name: nested.instance.name,
                        valueType: nested.name,
                        value: nested.instance.value || {
                            type: "initlist",
                            fields: nested.fields.map((field) => ({
                                name: field.name,
                                value: field.value || { type: "null" },
                            })),
                        },
                        isConst: false,
                        owner: name,
                    });
                }
                else {
                    fields.push(...nested.fields);
                    methods.push(...nested.methods);
                }
                continue;
            }
            const saved = i;
            const isConst = skipSpecifiers();
            const valueType = parseType();
            if (valueType && at("ident")) {
                if (peek(1).value === "(") {
                    i = saved;
                    const method = parseFunction();
                    method.owner = method.owner || name;
                    methods.push(method);
                    continue;
                }
                const fieldName = eat("ident").value;
                let value = null;
                if (at("op", "=")) {
                    i += 1;
                    value = parseExpr();
                }
                skipSemicolons();
                fields.push({ type: "decl", name: fieldName, valueType, value, isConst, owner: name });
                continue;
            }
            i = saved;
            skipBalanced();
        }
        eat("op", "}");
        let instance = null;
        if (at("ident")) {
            instance = { name: eat("ident").value, value: null };
            if (at("op", "=")) {
                i += 1;
                instance.value = parseExpr();
            }
        }
        skipSemicolons();
        return { type: "struct", name, fields, methods, instance };
    }
    function parseTopLevelDecl(isConst, valueType) {
        const name = eat("ident").value;
        let value = null;
        if (at("op", "=")) {
            i += 1;
            value = parseExpr();
        }
        skipSemicolons();
        return { type: "decl", name, valueType, value, isConst };
    }
    function skipBalanced() {
        if (at("op", "{")) {
            let depth = 0;
            while (!at("eof")) {
                if (at("op", "{")) {
                    depth += 1;
                }
                else if (at("op", "}")) {
                    depth -= 1;
                    i += 1;
                    if (depth === 0) {
                        break;
                    }
                    continue;
                }
                i += 1;
            }
            skipSemicolons();
            return;
        }
        while (!at("op", ";") && !at("eof") && !at("op", "}")) {
            i += 1;
        }
        skipSemicolons();
    }
    function skipTypeDecl() {
        while (at("kw", "template") || at("kw", "struct") || at("kw", "class") || at("kw", "enum") || at("kw", "typedef") || at("kw", "extern")) {
            i += 1;
        }
        while (!at("eof") && !at("op", "{") && !at("op", ";")) {
            i += 1;
        }
        skipBalanced();
    }
    function skipNamespace() {
        eat("kw", "namespace");
        if (at("ident")) {
            i += 1;
        }
        if (at("op", "{")) {
            const inner = parseProgramInside();
            eat("op", "}");
            return inner;
        }
        eat("op", ";");
        return [];
    }
    function parseProgramInside() {
        const decls = [];
        while (!at("eof") && !at("op", "}")) {
            skipSemicolons();
            if (at("eof") || at("op", "}")) {
                break;
            }
            if (at("kw", "namespace")) {
                decls.push(...skipNamespace());
                continue;
            }
            if (at("kw", "using")) {
                while (!at("op", ";") && !at("eof")) {
                    i += 1;
                }
                skipSemicolons();
                continue;
            }
            if (at("kw", "struct") || at("kw", "class")) {
                const parsed = parseStruct();
                decls.push(...parsed.fields);
                decls.push(...parsed.methods);
                continue;
            }
            if (at("kw", "enum") || at("kw", "template") || at("kw", "typedef") || at("kw", "extern")) {
                skipTypeDecl();
                continue;
            }
            const saved = i;
            const isConst = skipSpecifiers();
            const maybeType = parseType();
            if (maybeType && at("ident")) {
                const next = peek(1);
                if (next.value === "(" || next.value === "::") {
                    i = saved;
                    decls.push(parseFunction());
                    skipSemicolons();
                    continue;
                }
                if (next.value === "=" || next.value === ";") {
                    decls.push(parseTopLevelDecl(isConst, maybeType));
                    continue;
                }
            }
            i = saved;
            if (at("ident") && (peek(1).value === "::" || peek(1).value === "(" || peek(1).value === "." || peek(1).value === "->")) {
                const expr = parseExpr();
                skipSemicolons();
                decls.push({ type: "expr", expr });
                continue;
            }
            decls.push(parseFunction());
            skipSemicolons();
        }
        return decls;
    }
    return { type: "program", body: parseProgramInside(), fileName };
}
