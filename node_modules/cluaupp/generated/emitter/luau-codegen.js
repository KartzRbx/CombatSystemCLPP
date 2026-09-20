"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.LuauCodeEmitter = void 0;
const GET_SERVICE = /^const\s+([A-Za-z_][\w]*)\s*=\s*game:GetService\("([A-Za-z_][\w]*)"\)\s*$/;
const REQUIRE_LINE = /^const\s+([A-Za-z_][\w]*)\s*=\s*require\((.+)\)\s*$/;
class LuauCodeEmitter {
    static emptyState(strict = false) {
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
    static emit(state) {
        const output = [];
        if (state.strict) {
            output.push("--!strict");
        }
        if (state.headerLines.length > 0) {
            output.push(...state.headerLines);
        }
        else {
            output.push("-- Compiled by Cluaupp — C++ × Luau");
        }
        output.push("");
        if (state.robloxServices.size > 0) {
            for (const service of Array.from(state.robloxServices).sort()) {
                output.push(`const ${service} = game:GetService("${service}")`);
            }
            output.push("");
        }
        if (state.moduleRequires.size > 0) {
            for (const [alias, requirePath] of Array.from(state.moduleRequires.entries()).sort(([a], [b]) => a.localeCompare(b))) {
                output.push(`const ${alias} = require(${requirePath})`);
            }
            output.push("");
        }
        if (state.customTypes.length > 0) {
            output.push(...state.customTypes);
            output.push("");
        }
        if (state.constants.length > 0) {
            output.push(...state.constants);
            output.push("");
        }
        if (state.functions.length > 0) {
            output.push(...state.functions);
        }
        else {
            output.push("-- Nenhum método ou lógica detectado para transcompilação.");
        }
        return output.join("\n").replace(/\n{3,}/g, "\n\n") + "\n";
    }
    static merge(state, compiledLuau) {
        const trimmed = String(compiledLuau || "").trim();
        if (!trimmed || trimmed.startsWith("{") || trimmed.startsWith("[")) {
            return compiledLuau;
        }
        const harvested = harvestPreamble(compiledLuau);
        for (const service of harvested.services) {
            state.robloxServices.add(service);
        }
        for (const [alias, requirePath] of harvested.requires) {
            if (!state.moduleRequires.has(alias)) {
                state.moduleRequires.set(alias, requirePath);
            }
        }
        const output = [];
        output.push(...(harvested.header.length > 0 ? harvested.header : ["-- Compiled by Cluaupp — C++ × Luau"]));
        for (const line of state.headerLines) {
            if (line && !output.includes(line)) {
                output.push(line);
            }
        }
        if (state.strict && !output.some((line) => line.startsWith("--!strict"))) {
            output.unshift("--!strict");
        }
        output.push("");
        if (state.robloxServices.size > 0) {
            for (const service of Array.from(state.robloxServices).sort()) {
                output.push(`const ${service} = game:GetService("${service}")`);
            }
            output.push("");
        }
        if (state.moduleRequires.size > 0) {
            for (const [alias, requirePath] of Array.from(state.moduleRequires.entries()).sort(([a], [b]) => a.localeCompare(b))) {
                output.push(`const ${alias} = require(${requirePath})`);
            }
            output.push("");
        }
        const rest = harvested.body.trim();
        const extraTypes = state.customTypes.filter((line) => !bodyHasDecl(rest, line, /^type\s+(\w+)/));
        const extraConsts = state.constants.filter((line) => !bodyHasDecl(rest, line, /^const\s+(\w+)/));
        if (extraTypes.length > 0) {
            output.push(...extraTypes, "");
        }
        if (extraConsts.length > 0) {
            output.push(...extraConsts, "");
        }
        if (rest) {
            output.push(rest);
        }
        else if (state.customTypes.length || state.constants.length || state.functions.length) {
            if (state.customTypes.length) {
                output.push(...state.customTypes, "");
            }
            if (state.constants.length) {
                output.push(...state.constants, "");
            }
            if (state.functions.length) {
                output.push(...state.functions);
            }
        }
        return `${output.join("\n").replace(/\n{3,}/g, "\n\n").trimEnd()}\n`;
    }
}
exports.LuauCodeEmitter = LuauCodeEmitter;
function harvestPreamble(luau) {
    const lines = luau.split(/\r?\n/);
    const header = [];
    const services = new Set();
    const requires = new Map();
    let i = 0;
    while (i < lines.length && (lines[i].startsWith("--") || lines[i].trim() === "")) {
        if (lines[i].startsWith("--")) {
            header.push(lines[i]);
        }
        i += 1;
    }
    while (i < lines.length) {
        const line = lines[i];
        if (line.trim() === "") {
            i += 1;
            continue;
        }
        const service = line.match(GET_SERVICE);
        if (service && service[1] === service[2]) {
            services.add(service[1]);
            i += 1;
            continue;
        }
        const required = line.match(REQUIRE_LINE);
        if (required) {
            requires.set(required[1], required[2]);
            i += 1;
            continue;
        }
        break;
    }
    return {
        header,
        services,
        requires,
        body: lines.slice(i).join("\n"),
    };
}
function bodyHasDecl(body, line, pattern) {
    const match = line.match(pattern);
    if (!match) {
        return body.includes(line);
    }
    return new RegExp(`^(?:export\\s+)?(?:type|const)\\s+${match[1]}\\b`, "m").test(body);
}
