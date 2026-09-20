"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.tokenize = tokenize;
const KEYWORDS = new Set([
    "if",
    "else",
    "for",
    "while",
    "return",
    "new",
    "auto",
    "const",
    "void",
    "int",
    "bool",
    "float",
    "double",
    "true",
    "false",
    "nullptr",
    "class",
    "struct",
    "public",
    "private",
    "protected",
    "namespace",
    "using",
    "template",
    "typedef",
    "extern",
    "enum",
    "switch",
    "case",
    "default",
    "break",
    "static",
    "constexpr",
    "inline",
]);
function tokenize(source) {
    const tokens = [];
    let i = 0;
    let line = 1;
    let col = 1;
    const push = (type, value, startLine, startCol, start, end) => {
        tokens.push({ type, value, line: startLine, col: startCol, start, end });
    };
    while (i < source.length) {
        const c = source[i];
        if (c === "\n") {
            i += 1;
            line += 1;
            col = 1;
            continue;
        }
        if (c === " " || c === "\t" || c === "\r") {
            i += 1;
            col += 1;
            continue;
        }
        if (c === "#") {
            while (i < source.length && source[i] !== "\n") {
                i += 1;
            }
            continue;
        }
        if (c === "/" && source[i + 1] === "/") {
            while (i < source.length && source[i] !== "\n") {
                i += 1;
            }
            continue;
        }
        if (c === "/" && source[i + 1] === "*") {
            i += 2;
            col += 2;
            while (i < source.length && !(source[i] === "*" && source[i + 1] === "/")) {
                if (source[i] === "\n") {
                    line += 1;
                    col = 1;
                }
                else {
                    col += 1;
                }
                i += 1;
            }
            i += 2;
            col += 2;
            continue;
        }
        const startLine = line;
        const startCol = col;
        if (c === '"') {
            const start = i;
            i += 1;
            col += 1;
            let value = "";
            while (i < source.length && source[i] !== '"') {
                if (source[i] === "\\" && i + 1 < source.length) {
                    value += source[i] + source[i + 1];
                    i += 2;
                    col += 2;
                    continue;
                }
                value += source[i];
                i += 1;
                col += 1;
            }
            i += 1;
            col += 1;
            push("string", value, startLine, startCol, start, i);
            continue;
        }
        if (/[0-9]/.test(c)) {
            const start = i;
            let value = "";
            while (i < source.length && /[0-9.]/.test(source[i])) {
                value += source[i];
                i += 1;
                col += 1;
            }
            push("number", value, startLine, startCol, start, i);
            continue;
        }
        if (/[A-Za-z_]/.test(c)) {
            const start = i;
            let value = "";
            while (i < source.length && /[A-Za-z0-9_]/.test(source[i])) {
                value += source[i];
                i += 1;
                col += 1;
            }
            push(KEYWORDS.has(value) ? "kw" : "ident", value, startLine, startCol, start, i);
            continue;
        }
        const two = source.slice(i, i + 2);
        const start = i;
        if (["->", "==", "!=", "<=", ">=", "&&", "||", "::", "<<", ">>"].includes(two)) {
            push("op", two, startLine, startCol, start, i + 2);
            i += 2;
            col += 2;
            continue;
        }
        push("op", c, startLine, startCol, start, i + 1);
        i += 1;
        col += 1;
    }
    push("eof", "", line, col, source.length, source.length);
    return tokens;
}
