"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.determineArchitecture = exports.scoreIntents = exports.parseFileTag = exports.namesIn = exports.walk = exports.INTENTS = exports.VALUE_CLASSES = void 0;
exports.toPascalServiceName = toPascalServiceName;
exports.analyze = analyze;
exports.legacyOutName = legacyOutName;
exports.modernScriptOutName = modernScriptOutName;
exports.looksLikeCacheSetup = looksLikeCacheSetup;
// @ts-nocheck
const node_path_1 = __importDefault(require("node:path"));
const api_js_1 = require("./api.js");
const system_understander_js_1 = require("./system-understander.js");
Object.defineProperty(exports, "INTENTS", { enumerable: true, get: function () { return system_understander_js_1.INTENTS; } });
Object.defineProperty(exports, "walk", { enumerable: true, get: function () { return system_understander_js_1.walk; } });
Object.defineProperty(exports, "namesIn", { enumerable: true, get: function () { return system_understander_js_1.namesIn; } });
Object.defineProperty(exports, "parseFileTag", { enumerable: true, get: function () { return system_understander_js_1.parseFileTag; } });
Object.defineProperty(exports, "scoreIntents", { enumerable: true, get: function () { return system_understander_js_1.scoreIntents; } });
Object.defineProperty(exports, "determineArchitecture", { enumerable: true, get: function () { return system_understander_js_1.determineArchitecture; } });
const VALUE_CLASSES = {
    IntValue: { luau: "number", instance: "IntValue", fallback: "0" },
    NumberValue: { luau: "number", instance: "NumberValue", fallback: "0" },
    StringValue: { luau: "string", instance: "StringValue", fallback: '""' },
    BoolValue: { luau: "boolean", instance: "BoolValue", fallback: "false" },
};
exports.VALUE_CLASSES = VALUE_CLASSES;
const EXT = "(cpp|cc|cxx|c|h|hpp|hh)";
function capitalize(word) {
    if (!word) {
        return word;
    }
    return word.charAt(0).toUpperCase() + word.slice(1);
}
function toPascalServiceName(fileName) {
    let base = node_path_1.default.basename(fileName).replace(new RegExp(`\\.${EXT}$`, "i"), "");
    base = base.replace(/\.legacy\.(server|client)$/i, "");
    base = base.replace(/\.(server|client)$/i, "");
    if (/^init$/i.test(base)) {
        const folder = node_path_1.default.basename(node_path_1.default.dirname(fileName) || "");
        if (folder && folder !== "." && folder !== "src") {
            return capitalize(folder);
        }
        return "Init";
    }
    if (/stats$/i.test(base) && !/Stats$/.test(base)) {
        return capitalize(base.slice(0, -5)) + "Stats";
    }
    if (/[-_]/.test(base)) {
        return base
            .split(/[-_]+/)
            .filter(Boolean)
            .map(capitalize)
            .join("");
    }
    return capitalize(base);
}
function literal(node) {
    if (!node) {
        return null;
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
    return null;
}
function collectStats(ast) {
    const stats = [];
    let folderName = null;
    const seen = new Set();
    for (const decl of ast.body || []) {
        if (decl.type !== "function" || !decl.body) {
            continue;
        }
        const locals = new Map();
        for (const stmt of decl.body) {
            if (stmt.type === "decl" && stmt.value && stmt.value.type === "new") {
                locals.set(stmt.name, {
                    className: stmt.value.className,
                    statName: null,
                    defaultValue: null,
                });
            }
            if (stmt.type !== "expr" || !stmt.expr || stmt.expr.type !== "assign") {
                continue;
            }
            const left = stmt.expr.left;
            if (!left || left.type !== "member" || !left.object || left.object.type !== "ident") {
                continue;
            }
            const record = locals.get(left.object.name);
            if (!record) {
                continue;
            }
            if (left.name === "Name" && stmt.expr.right && stmt.expr.right.type === "string") {
                record.statName = stmt.expr.right.value;
                if (record.className === "Folder") {
                    folderName = record.statName;
                }
            }
            if (left.name === "Value") {
                record.defaultValue = literal(stmt.expr.right);
            }
        }
        for (const record of locals.values()) {
            const spec = VALUE_CLASSES[record.className];
            if (!spec || !record.statName || seen.has(record.statName)) {
                continue;
            }
            seen.add(record.statName);
            stats.push({
                name: record.statName,
                instance: spec.instance,
                luau: spec.luau,
                defaultValue: record.defaultValue != null ? record.defaultValue : spec.fallback,
            });
        }
    }
    return { stats, folderName: folderName || (stats.length > 0 ? "leaderstats" : null) };
}
function collectConsts(ast) {
    const consts = [];
    for (const decl of ast.body || []) {
        if (decl.type === "decl" && decl.isConst) {
            consts.push({
                name: decl.name,
                luau: (0, api_js_1.luauType)(decl.valueType) || "number",
                value: literal(decl.value) || "nil",
            });
        }
    }
    return consts;
}
function onlyConsts(ast) {
    const body = ast.body || [];
    if (body.length === 0) {
        return false;
    }
    return body.every((node) => node.type === "decl" || node.type === "proto");
}
function looksLikeCacheSetup(fn) {
    if (!fn || !fn.body) {
        return false;
    }
    const named = (0, system_understander_js_1.namesIn)(fn);
    return [...Object.keys(VALUE_CLASSES), "Folder"].some((name) => named.has(name));
}
function isTrivial(ast) {
    const fns = (ast.body || []).filter((node) => node.type === "function");
    if (fns.length === 0) {
        return (ast.body || []).every((node) => node.type === "proto" || node.type === "decl");
    }
    if (fns.some((fn) => fn.name !== "init")) {
        return false;
    }
    const init = fns.find((fn) => fn.name === "init");
    const named = (0, system_understander_js_1.namesIn)(init || { body: [] }, { strings: false });
    const interesting = [...named].filter((name) => !["print", "warn", "error"].includes(name) && !/^[0-9.]+$/.test(name));
    return interesting.length === 0;
}
function classifyFunctions(ast, intents) {
    const primary = intents.find((item) => item.name !== "players" && item.name !== "cache");
    const classified = [];
    for (const decl of ast.body || []) {
        if (decl.type !== "function" || decl.name === "init") {
            continue;
        }
        const named = (0, system_understander_js_1.namesIn)(decl);
        const localIntents = (0, system_understander_js_1.scoreIntents)(named);
        let absorb = "none";
        if (looksLikeCacheSetup(decl)) {
            absorb = "cache";
        }
        const top = localIntents[0];
        classified.push({
            name: decl.name,
            decl,
            intent: top ? top.name : primary ? primary.name : "domain",
            absorb,
        });
    }
    keepReferencedFunctions(ast, classified);
    return classified;
}
function keepReferencedFunctions(ast, classified) {
    const kept = new Set(["init"]);
    for (const item of classified) {
        if (item.absorb !== "cache") {
            kept.add(item.name);
        }
    }
    let changed = true;
    while (changed) {
        changed = false;
        for (const decl of ast.body || []) {
            if (decl.type !== "function" || !kept.has(decl.name)) {
                continue;
            }
            const named = (0, system_understander_js_1.namesIn)(decl);
            for (const item of classified) {
                if (item.absorb === "cache" && named.has(item.name)) {
                    item.absorb = "none";
                    kept.add(item.name);
                    changed = true;
                }
            }
        }
    }
}
function analyze(ast, fileName) {
    const report = (0, system_understander_js_1.determineArchitecture)(fileName, ast);
    const tag = report.fileTag;
    const named = (0, system_understander_js_1.namesIn)(ast);
    const { stats, folderName } = collectStats(ast);
    const consts = collectConsts(ast);
    const intents = (0, system_understander_js_1.scoreIntents)(named, tag.runtime);
    const functions = classifyFunctions(ast, intents);
    const trivial = isTrivial(ast);
    const constsOnly = onlyConsts(ast);
    const hasPlayers = intents.some((item) => item.name === "players");
    const hasCache = intents.some((item) => item.name === "cache") || stats.length > 0;
    const primaryDomain = intents.find((item) => item.name !== "players" && item.name !== "cache") || null;
    const serviceName = toPascalServiceName(fileName);
    const configLike = tag.emit === "module" &&
        (constsOnly || (consts.length > 0 && !hasPlayers && stats.length === 0 && !primaryDomain));
    let kind = "flat";
    if (tag.emit === "legacy") {
        kind = "legacy";
    }
    else if (tag.emit === "module") {
        kind = configLike ? "config" : "module";
    }
    else if (tag.emit === "service") {
        kind = trivial ? "flat" : "service";
    }
    const roles = {
        players: kind === "service" && hasPlayers,
        cache: kind === "service" && (hasCache || stats.length > 0),
        domain: null,
    };
    if (kind === "service" && primaryDomain) {
        roles.domain = primaryDomain.module;
    }
    else if (kind === "service" && !roles.cache && !roles.players) {
        roles.domain = `${serviceName}Controller`;
    }
    const reasoning = [
        ...report.reasoning,
        kind === "service"
            ? `roles ${["Main", roles.players ? "PlayersManager" : null, roles.cache ? "CacheController" : null, roles.domain, `${serviceName}Types`].filter(Boolean).join(", ")}`
            : `kind ${kind}`,
    ];
    return {
        tag,
        kind,
        onlyConsts: constsOnly,
        trivial,
        serviceName,
        typesName: `${serviceName}Types`,
        isClient: tag.runtime === "client",
        runContext: tag.runContext || null,
        intents,
        primaryDomain,
        roles,
        stats,
        folderName,
        consts,
        functions,
        fileName,
        understand: report,
        reasoning,
    };
}
function modernScriptOutName(relativeName) {
    const rel = String(relativeName).replace(/\\/g, "/");
    if (/\.plugin\.(cpp|cc|cxx|c|h|hpp|hh)$/i.test(rel)) {
        return rel.replace(/\.plugin\.(cpp|cc|cxx|c|h|hpp|hh)$/i, ".luau");
    }
    return rel.replace(/\.(cpp|cc|cxx|c|h|hpp|hh)$/i, ".luau");
}
function legacyOutName(relativeName) {
    return String(relativeName)
        .replace(/\\/g, "/")
        .replace(/\.legacy\.plugin\./i, ".")
        .replace(/\.legacy\.(server|client)\./i, ".$1.")
        .replace(/\.legacy\./i, ".server.")
        .replace(new RegExp(`\\.${EXT}$`, "i"), ".luau");
}
