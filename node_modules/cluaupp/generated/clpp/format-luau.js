"use strict";
// Roblox Luau style for Cluaupp emit: tabs, indent blocks, leave inner spacing alone.
Object.defineProperty(exports, "__esModule", { value: true });
exports.formatLuauRoblox = formatLuauRoblox;
const TAB = "\t";
function longClose(eq) {
    return `]${"=".repeat(eq)}]`;
}
function longOpenEq(text, index) {
    if (text[index] !== "[") {
        return null;
    }
    let i = index + 1;
    let eq = 0;
    while (text[i] === "=") {
        eq += 1;
        i += 1;
    }
    if (text[i] === "[") {
        return eq;
    }
    return null;
}
function skipLong(text, start, eq) {
    const close = longClose(eq);
    const found = text.indexOf(close, start);
    if (found === -1) {
        return { next: text.length, closed: false };
    }
    return { next: found + close.length, closed: true };
}
function firstToken(text) {
    const match = text.match(/^[A-Za-z_][A-Za-z0-9_]*|^\}/);
    return match ? match[0] : "";
}
function identAt(text, from) {
    let j = from;
    while (j < text.length && /[A-Za-z0-9_]/.test(text[j] || "")) {
        j += 1;
    }
    return text.slice(from, j);
}
function scanDelta(text, carry) {
    let i = 0;
    let delta = 0;
    let long = carry.long;
    let eq = carry.eq;
    const consumeLong = (kind, depth, from) => {
        const skipped = skipLong(text, from, depth);
        if (!skipped.closed) {
            long = kind;
            eq = depth;
            i = text.length;
            return false;
        }
        long = "none";
        eq = 0;
        i = skipped.next;
        return true;
    };
    if (long === "string") {
        consumeLong("string", eq, 0);
    }
    else if (long === "comment") {
        consumeLong("comment", eq, 0);
    }
    while (i < text.length) {
        const ch = text[i] || "";
        if (ch === "-" && text[i + 1] === "-") {
            const commentEq = longOpenEq(text, i + 2);
            if (commentEq !== null) {
                const openEnd = i + 4 + commentEq;
                if (!consumeLong("comment", commentEq, openEnd)) {
                    return { delta, carry: { long, eq } };
                }
                continue;
            }
            break;
        }
        if (ch === "'" || ch === '"') {
            const quote = ch;
            i += 1;
            while (i < text.length) {
                if (text[i] === "\\") {
                    i += 2;
                    continue;
                }
                if (text[i] === quote) {
                    i += 1;
                    break;
                }
                i += 1;
            }
            continue;
        }
        const strEq = longOpenEq(text, i);
        if (strEq !== null) {
            const openEnd = i + 2 + strEq;
            if (!consumeLong("string", strEq, openEnd)) {
                return { delta, carry: { long, eq } };
            }
            continue;
        }
        if (ch === "{") {
            delta += 1;
            i += 1;
            continue;
        }
        if (ch === "}") {
            delta -= 1;
            i += 1;
            continue;
        }
        if (/[A-Za-z_]/.test(ch)) {
            const word = identAt(text, i);
            i += word.length;
            if (word === "function" || word === "then" || word === "do" || word === "repeat") {
                delta += 1;
            }
            else if (word === "end" || word === "until") {
                delta -= 1;
            }
            continue;
        }
        i += 1;
    }
    return { delta, carry: { long, eq } };
}
function formatLuauRoblox(source) {
    const lines = String(source).split(/\r?\n/);
    const out = [];
    let indent = 0;
    let carry = { long: "none", eq: 0 };
    for (const raw of lines) {
        if (raw.trim() === "") {
            out.push("");
            continue;
        }
        if (carry.long !== "none") {
            out.push(raw.trimEnd());
            carry = scanDelta(raw, carry).carry;
            continue;
        }
        const trimmed = raw.trim();
        const lead = firstToken(trimmed);
        const closer = lead === "end" || lead === "until" || lead === "else" || lead === "elseif" || lead === "}";
        if (closer) {
            indent = Math.max(0, indent - 1);
        }
        out.push(`${TAB.repeat(indent)}${trimmed}`);
        const rest = closer ? trimmed.slice(lead.length) : trimmed;
        const scanned = scanDelta(rest, carry);
        indent = Math.max(0, indent + scanned.delta);
        if (lead === "else") {
            indent += 1;
        }
        carry = scanned.carry;
    }
    return `${collapseBlanks(compactTableFields(spaceScopes(out))).join("\n").replace(/[ \t]+$/gm, "").replace(/\n+$/, "")}\n`;
}
function lineIndent(line) {
    const match = line.match(/^\t*/);
    return match ? match[0].length : 0;
}
function isComment(line) {
    return line.trimStart().startsWith("--");
}
function spaceScopes(lines) {
    const out = [];
    for (let i = 0; i < lines.length; i += 1) {
        const line = lines[i] || "";
        const next = lines[i + 1];
        out.push(line);
        if (next === undefined || line.trim() === "" || next.trim() === "") {
            continue;
        }
        if (lineIndent(line) !== lineIndent(next)) {
            continue;
        }
        const lead = firstToken(line.trim());
        const nextLead = firstToken(next.trim());
        const nextCloses = nextLead === "else" || nextLead === "elseif" || nextLead === "end" || nextLead === "until" || nextLead === "}";
        if ((lead === "end" || lead === "until" || lead === "}") && !nextCloses) {
            out.push("");
            continue;
        }
        const nextOpens = nextLead === "if" || nextLead === "for" || nextLead === "while" || nextLead === "repeat";
        const prevOpens = lead === "if" || lead === "for" || lead === "while" || lead === "repeat" || lead === "else" || lead === "elseif";
        if (nextOpens && !prevOpens && lead !== "end" && lead !== "until" && lead !== "}" && !isComment(line)) {
            out.push("");
        }
    }
    return out;
}
function collapseBlanks(lines) {
    const out = [];
    for (const line of lines) {
        if (line.trim() === "" && out.length > 0 && (out[out.length - 1] || "").trim() === "") {
            continue;
        }
        out.push(line);
    }
    return out;
}
function tableName(line) {
    const trimmed = line.trim();
    const field = trimmed.match(/^([A-Za-z_][A-Za-z0-9_]*)\.[A-Za-z_][A-Za-z0-9_]*\s*=/);
    if (field) {
        return field[1];
    }
    const ctor = trimmed.match(/^(?:local|const)\s+([A-Za-z_][A-Za-z0-9_]*)\s*=\s*\{\s*\}\s*$/);
    return ctor ? ctor[1] : null;
}
function compactTableFields(lines) {
    const out = [];
    for (let i = 0; i < lines.length; i += 1) {
        const line = lines[i] || "";
        if (line.trim() !== "") {
            out.push(line);
            continue;
        }
        const prev = out[out.length - 1];
        let nextIndex = i + 1;
        while (nextIndex < lines.length && (lines[nextIndex] || "").trim() === "") {
            nextIndex += 1;
        }
        const next = lines[nextIndex];
        const prevTable = prev ? tableName(prev) : null;
        const nextTable = next !== undefined ? tableName(next) : null;
        if (prevTable && nextTable && prevTable === nextTable) {
            continue;
        }
        out.push(line);
    }
    return out;
}
