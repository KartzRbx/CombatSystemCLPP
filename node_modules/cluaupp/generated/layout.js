"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.ENTRY_FN = exports.PRINCIPAL_FN = exports.CLEANUP_FN = exports.SECTION = void 0;
exports.isJanitorDecl = isJanitorDecl;
exports.isApiDecl = isApiDecl;
exports.classifyDecl = classifyDecl;
exports.organizeDecls = organizeDecls;
exports.janitorNames = janitorNames;
exports.emitSection = emitSection;
exports.joinBlocks = joinBlocks;
exports.commentLine = commentLine;
exports.SECTION = {
    api: "API",
    constants: "CONSTANTS",
    variables: "VARIABLES",
    types: "TYPES",
    support: "HELPERS FUNCTIONS",
    principal: "MAIN FUNCTIONS",
    cleanup: "JANITOR",
    returns: "RETURN",
};
exports.CLEANUP_FN = /^(OnClose|OnPlayerRemoving|Cleanup|Shutdown|OnDestroy)$/i;
exports.PRINCIPAL_FN = /^(init|start|main|setup)/i;
exports.ENTRY_FN = /^(init|main)$/i;
function isGetService(node) {
    return Boolean(node && node.type === "getService");
}
function isDataServiceAlias(node) {
    let current = node || undefined;
    while (current && current.type === "member") {
        if (current.object && current.object.type === "ident" && current.object.name === "DataService") {
            return true;
        }
        current = current.object;
    }
    return false;
}
function isJanitorDecl(decl) {
    if (!decl || decl.type !== "decl") {
        return false;
    }
    const name = String(decl.name || "").toLowerCase();
    const typeName = String(decl.valueType || "").toLowerCase();
    const created = decl.value && decl.value.type === "new" && decl.value.className === "Janitor";
    return name.includes("janitor") || typeName.includes("janitor") || created;
}
function isApiDecl(decl) {
    if (!decl || decl.type !== "decl") {
        return false;
    }
    return isGetService(decl.value) || isDataServiceAlias(decl.value);
}
function classifyDecl(decl) {
    if (!decl || decl.type === "proto") {
        return null;
    }
    if (decl.type === "decl") {
        if (isApiDecl(decl)) {
            return "api";
        }
        if (isJanitorDecl(decl)) {
            return "variables";
        }
        if (decl.isConst) {
            return "constants";
        }
        return "variables";
    }
    if (decl.type === "function") {
        if (exports.CLEANUP_FN.test(decl.name || "")) {
            return "cleanup";
        }
        if (exports.PRINCIPAL_FN.test(decl.name || "")) {
            return "principal";
        }
        return "support";
    }
    return null;
}
function organizeDecls(keep) {
    const groups = {
        api: [],
        constants: [],
        variables: [],
        support: [],
        principal: [],
        cleanup: [],
    };
    for (const decl of keep) {
        const bucket = classifyDecl(decl);
        if (bucket && groups[bucket]) {
            groups[bucket].push(decl);
        }
    }
    return groups;
}
function janitorNames(keep) {
    return (keep || []).filter(isJanitorDecl).map((decl) => decl.name);
}
function emitSection(_title, body) {
    const text = String(body || "").trimEnd();
    if (!text) {
        return "";
    }
    return `${text}\n\n`;
}
function joinBlocks(parts) {
    return parts.filter((part) => Boolean(part && String(part).trim())).join("\n\n");
}
function commentLine(title) {
    return `-- ${title}`;
}
