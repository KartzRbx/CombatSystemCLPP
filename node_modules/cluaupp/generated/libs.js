"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.MODULE_COLON = exports.LIBRARY_METHODS = exports.LIBRARY_TYPES = exports.EXTRA_TYPE_EXPORTS = exports.TYPE_EXPORTS = exports.INCLUDE_TO_MODULE = exports.MODULES = void 0;
exports.isLibraryType = isLibraryType;
exports.isLibraryMethod = isLibraryMethod;
exports.collectLibraries = collectLibraries;
exports.libraryNamesFromIncludes = libraryNamesFromIncludes;
exports.requireCluauppLib = requireCluauppLib;
exports.emitRequires = emitRequires;
exports.insertRequires = insertRequires;
exports.insertModuleRequires = insertModuleRequires;
exports.insertPreamble = insertPreamble;
// @ts-nocheck
const node_path_1 = __importDefault(require("node:path"));
const TYPE_EXPORTS = {
    Sweep: "Sweep",
    Promise: "Promise",
    Net: "Net",
    Crest: "Crest",
    Shift: "Shift",
    Coil: "Coil",
    Pin: "Pin",
    Bloom: "Bloom",
    Stage: "Stage",
    Axiom: "Axiom",
    Ember: "Ember",
    Mint: "Mint",
    Gleam: "Gleam",
    Lens: "Lens",
    Helm: "Helm",
    Echo: "Echo",
    Keep: "DataService",
    Trace: "Trace",
    Spark: "Spark",
    Guide: "Guide",
    Roster: "Roster",
    Hive: "Hive",
    Flare: "Flare",
};
exports.TYPE_EXPORTS = TYPE_EXPORTS;
const EXTRA_TYPE_EXPORTS = {
    Keep: {
        Data: "Data",
        DataPath: "Path",
        DataServiceServer: "ServerApi",
        DataServiceClient: "ClientApi",
    },
    Spark: {
        SparkConnection: "Connection",
    },
};
exports.EXTRA_TYPE_EXPORTS = EXTRA_TYPE_EXPORTS;
const MODULES = {
    Sweep: { file: "Sweep", bind: "Sweep" },
    Promise: { file: "Promise", bind: "Promise" },
    Net: { file: "Net", bind: "Net" },
    NetEvent: { file: "Net", bind: "Net" },
    NetFunction: { file: "Net", bind: "Net" },
    Axiom: { file: "Axiom", bind: "Axiom" },
    Mint: { file: "Mint", bind: "Mint" },
    Stage: { file: "Stage", bind: "Stage" },
    Keep: { file: "Keep", bind: "Keep" },
    Bloom: { file: "Bloom", bind: "Bloom" },
    Coil: { file: "Coil", bind: "Coil" },
    Trace: { file: "Trace", bind: "Trace" },
    Pin: { file: "Pin", bind: "Pin" },
    Crest: { file: "Crest", bind: "Crest" },
    Helm: { file: "Helm", bind: "Helm" },
    Echo: { file: "Echo", bind: "Echo" },
    Lens: { file: "Lens", bind: "Lens" },
    Gleam: { file: "Gleam", bind: "Gleam" },
    Shift: { file: "Shift", bind: "Shift" },
    Ember: { file: "Ember", bind: "Ember" },
    ArrayIndexer: { file: "ArrayIndexer", bind: "ArrayIndexer" },
    Occlude: { file: "Occlude", bind: "Occlude" },
    Spark: { file: "Spark", bind: "Spark" },
    Guide: { file: "Guide", bind: "Guide" },
    Flare: { file: "Flare", bind: "Flare" },
    Roster: { file: "Roster", bind: "Roster" },
    Hive: { file: "Hive", bind: "Hive" },
    Ward: { file: "Ward", bind: "Ward" },
};
exports.MODULES = MODULES;
const INCLUDE_TO_MODULE = {
    sweep: "Sweep",
    janitor: "Sweep",
    maid: "Sweep",
    promise: "Promise",
    net: "Net",
    axiom: "Axiom",
    math: "Axiom",
    mint: "Mint",
    formatnumber: "Mint",
    stage: "Stage",
    module3d: "Stage",
    keep: "Keep",
    dataservice: "Keep",
    dataservicev2: "Keep",
    bloom: "Bloom",
    twinkle: "Bloom",
    ezvisual: "Bloom",
    ezvisualz: "Bloom",
    coil: "Coil",
    spring: "Coil",
    trace: "Trace",
    display: "Trace",
    pin: "Pin",
    stickybillboard: "Pin",
    crest: "Crest",
    icon: "Crest",
    topbarplus: "Crest",
    helm: "Helm",
    cmdr: "Helm",
    echo: "Echo",
    chrono: "Echo",
    lens: "Lens",
    iris: "Lens",
    gleam: "Gleam",
    fusion: "Gleam",
    vide: "Gleam",
    shift: "Shift",
    statemachine: "Shift",
    ember: "Ember",
    vfx: "Ember",
    vfxutil: "Ember",
    arrayindexer: "ArrayIndexer",
    occlude: "Occlude",
    spark: "Spark",
    signal: "Spark",
    guide: "Guide",
    tutorialkit: "Guide",
    flare: "Flare",
    zap: "Flare",
    quicknet: "Flare",
    roster: "Roster",
    hive: "Hive",
    ward: "Ward",
    libs: null,
};
exports.INCLUDE_TO_MODULE = INCLUDE_TO_MODULE;
const LIBRARY_TYPES = new Set(Object.keys(MODULES));
exports.LIBRARY_TYPES = LIBRARY_TYPES;
const LIBRARY_METHODS = new Set([
    "Add",
    "AddObject",
    "AddPromise",
    "Remove",
    "RemoveNoClean",
    "RemoveList",
    "RemoveListNoClean",
    "GetAll",
    "Cleanup",
    "Destroy",
    "LinkToInstance",
    "LinkToInstances",
    "Then",
    "Catch",
    "Finally",
    "Await",
    "Cancel",
    "Fire",
    "FireDeferred",
    "FireAll",
    "Wrap",
    "DisconnectAll",
    "GetConnections",
    "ConnectParallel",
    "OnceParallel",
    "IsDestroyed",
    "register",
    "On",
    "OnClient",
    "OnServer",
    "Invoke",
    "InvokeServer",
    "InvokeClient",
    "Attach3D",
    "Update",
    "SetCFrame",
    "GetCFrame",
    "SetDepthMultiplier",
    "GetDepthMultiplier",
    "GetPersisted",
    "GetTransient",
    "HasTransient",
    "SetTransient",
    "UpdateTransient",
    "ClearTransient",
    "ArrayInsert",
    "ArrayInsertTransient",
    "ArrayRemove",
    "ArrayRemoveTransient",
    "GetOrderedList",
    "GetOrderedListWithPriority",
    "GetChangedSignal",
    "GetPathChangedSignal",
    "GetIndexChangedSignal",
    "GetArrayInsertedSignal",
    "GetArrayRemovedSignal",
    "Typed",
    "WaitFor",
    "WaitForData",
    "HasData",
    "GetProfile",
    "GetBufferStats",
    "Init",
    "Observe",
    "Impulse",
    "SetGoal",
    "Set",
    "Get",
    "Step",
    "Fade",
    "FrameSlide",
    "FrameZoom",
    "FrameBounce",
    "ShowText",
    "SetButtonStyle",
    "FadeSlideRunoff",
    "Abbreviate",
    "Comma",
    "Compact",
    "Play",
    "Pause",
    "Resume",
    "Stop",
    "BindEvent",
    "bindEvent",
    "BindFunction",
    "RegisterDefaultCommands",
    "RegisterHook",
    "RegisterType",
    "RegisterCommand",
    "ChangeState",
    "GetState",
    "GetCurrentState",
    "GetPreviousState",
    "GetData",
    "ChangeData",
    "LoadDirectory",
    "setLabel",
    "setImage",
    "setEnabled",
    "setName",
    "setOrder",
    "setWidth",
    "align",
    "setLeft",
    "setMid",
    "setRight",
    "bindToggleItem",
    "modifyTheme",
    "setTheme",
    "notify",
    "clearNotices",
    "select",
    "deselect",
    "autoDeselect",
    "SetText",
    "SetEnabled",
    "SetMaxDistance",
    "SetActive",
    "GetActive",
    "End",
    "Scale",
    "DestroyAfter",
    "Burst",
    "CloneOnto",
    "Shutdown",
    "Append",
    "PushConfig",
    "PopConfig",
    "ForceRefresh",
    "build",
    "to",
    "focus",
    "tour",
    "SetStep",
    "GetStep",
    "Complete",
    "GoTo",
    "Advance",
    "FireServer",
    "FireAll",
    "Invoke",
    "Start",
    "Allow",
    "Strike",
    "Packet",
    "Grace",
    "WatchMovement",
    "SaveWait",
    "Begin",
    "Reserve",
    "Commit",
    "Abort",
    "Ensure",
    "Credit",
]);
exports.LIBRARY_METHODS = LIBRARY_METHODS;
const MODULE_COLON = new Set(["Attach3D", "RegisterDefaultCommands", "RegisterHook", "Connect", "LoadDirectory"]);
exports.MODULE_COLON = MODULE_COLON;
function isLibraryType(name) {
    return LIBRARY_TYPES.has(name);
}
function isLibraryMethod(name) {
    return LIBRARY_METHODS.has(name);
}
function walk(node, visit) {
    if (!node || typeof node !== "object") {
        return;
    }
    visit(node);
    for (const value of Object.values(node)) {
        if (Array.isArray(value)) {
            for (const item of value) {
                walk(item, visit);
            }
        }
        else if (value && typeof value === "object") {
            walk(value, visit);
        }
    }
}
function modulesFromIncludes(source) {
    const found = new Set();
    for (const line of String(source).split(/\r?\n/)) {
        const match = line.match(/^\s*#\s*include\s+<(?:clpp|cluaupp)\/(?:libs\/)?([A-Za-z0-9]+)\.(?:clh|hpp)>/);
        if (!match) {
            continue;
        }
        const key = match[1].toLowerCase();
        const mapped = INCLUDE_TO_MODULE[key];
        if (mapped) {
            found.add(mapped);
        }
        if (key === "libs") {
            for (const name of Object.keys(MODULES)) {
                found.add(name);
            }
        }
    }
    return found;
}
function collectLibraries(source, ast) {
    const used = modulesFromIncludes(source);
    walk(ast, (node) => {
        if (node.type === "ident" && MODULES[node.name] && node.name !== "Net" && node.name !== "NetEvent" && node.name !== "NetFunction") {
            used.add(node.name === "NetEvent" || node.name === "NetFunction" ? "Net" : node.name);
        }
        if (node.type === "new" && MODULES[node.className]) {
            used.add(node.className === "NetEvent" || node.className === "NetFunction" ? "Net" : node.className);
        }
        if (node.type === "call" && node.object && node.object.type === "ident" && MODULES[node.object.name] && node.object.name !== "Net") {
            const name = node.object.name;
            used.add(name === "NetEvent" || name === "NetFunction" ? "Net" : name);
        }
    });
    const unique = [];
    const seenBind = new Set();
    for (const name of used) {
        const spec = MODULES[name];
        if (!spec || seenBind.has(spec.bind)) {
            continue;
        }
        seenBind.add(spec.bind);
        unique.push(spec);
    }
    return unique;
}
const ROJO_ROOTS = {
    ReplicatedFirst: { service: "ReplicatedFirst", expr: "ReplicatedFirst" },
    ReplicatedStorage: { service: "ReplicatedStorage", expr: "ReplicatedStorage" },
    ServerScriptService: { service: "ServerScriptService", expr: "ServerScriptService" },
    StarterPlayer: { service: "StarterPlayer", expr: "StarterPlayer" },
    ServerStorage: { service: "ServerStorage", expr: "ServerStorage" },
};
const SERVICE_ORDER = ["ReplicatedFirst", "ReplicatedStorage", "ServerScriptService", "StarterPlayer", "ServerStorage"];
const SERVICE_GET = {
    ReplicatedFirst: 'const ReplicatedFirst = game:GetService("ReplicatedFirst")',
    ReplicatedStorage: 'const ReplicatedStorage = game:GetService("ReplicatedStorage")',
    ServerScriptService: 'const ServerScriptService = game:GetService("ServerScriptService")',
    StarterPlayer: 'const StarterPlayer = game:GetService("StarterPlayer")',
    ServerStorage: 'const ServerStorage = game:GetService("ServerStorage")',
};
function requireCluauppLib(name) {
    return `require(ReplicatedStorage.CluauppLibs.${name})`;
}
function parseOutRel(toOutRel) {
    const posix = String(toOutRel || "module.luau")
        .replace(/\\/g, "/")
        .replace(/\.luau$/i, "");
    const parts = posix.split("/").filter(Boolean);
    const tree = parts[0];
    const root = ROJO_ROOTS[tree] || null;
    const rest = root ? parts.slice(1) : parts;
    return { tree, root, rest, posix };
}
function robloxRequireFrom(_fromOutRel, toOutRel) {
    const { root, rest } = parseOutRel(toOutRel);
    if (root) {
        const tail = rest.join(".");
        return tail ? `require(${root.expr}.${tail})` : `require(${root.expr})`;
    }
    const fromDir = node_path_1.default.posix.dirname(String(_fromOutRel || "module.luau").replace(/\\/g, "/"));
    const toMod = String(toOutRel || "module.luau")
        .replace(/\\/g, "/")
        .replace(/\.luau$/i, "");
    let rel = node_path_1.default.posix.relative(fromDir, toMod);
    if (!rel || rel === ".") {
        rel = node_path_1.default.posix.basename(toMod);
    }
    const parts = rel.split("/");
    let expr = "script.Parent";
    for (const part of parts) {
        if (part === "..") {
            expr += ".Parent";
        }
        else if (part && part !== ".") {
            expr += `.${part}`;
        }
    }
    return `require(${expr})`;
}
function emitLibraryLines(libraries) {
    const api = [];
    const types = [];
    for (const spec of libraries) {
        api.push(`const ${spec.bind} = ${requireCluauppLib(spec.file)}`);
        const exported = TYPE_EXPORTS[spec.bind];
        if (exported) {
            types.push(`type ${spec.bind} = ${spec.bind}.${exported}`);
        }
        const extra = EXTRA_TYPE_EXPORTS[spec.bind];
        if (extra) {
            for (const [alias, exportedName] of Object.entries(extra)) {
                types.push(`type ${alias} = ${spec.bind}.${exportedName}`);
            }
        }
    }
    return { api, types };
}
function emitRequireParts(libraries) {
    if (!libraries.length) {
        return { api: "", types: "" };
    }
    const { api, types } = emitLibraryLines(libraries);
    api.unshift(SERVICE_GET.ReplicatedStorage);
    return {
        api: `${api.join("\n")}\n`,
        types: types.length ? `${types.join("\n")}\n` : "",
    };
}
function emitRequires(libraries) {
    const { api, types } = emitRequireParts(libraries);
    return [api, types].filter((part) => Boolean(part && part.trim())).join("\n");
}
function insertRequires(luau, libraries) {
    const block = emitRequires(libraries).trimEnd();
    if (!block) {
        return luau;
    }
    return insertBlock(luau, block);
}
function moduleIsUsed(luau, spec) {
    if (String(luau).includes(spec.name)) {
        return true;
    }
    const exported = [...((spec.exports && spec.exports.consts) || []), ...((spec.exports && spec.exports.structs) || [])];
    return exported.some((name) => String(luau).includes(name));
}
function moduleRequireLines(modules, fromOutRel, luau) {
    const lines = [];
    const services = new Set();
    const seen = new Set();
    for (const spec of modules || []) {
        if (!spec || !spec.name || seen.has(spec.name)) {
            continue;
        }
        if (fromOutRel && !moduleIsUsed(luau, spec)) {
            continue;
        }
        seen.add(spec.name);
        const { root } = parseOutRel(spec.outRel);
        if (root) {
            services.add(root.service);
        }
        lines.push(`const ${spec.name} = ${robloxRequireFrom(fromOutRel, spec.outRel)}`);
        for (const name of (spec.exports && spec.exports.consts) || []) {
            if (name !== spec.name) {
                lines.push(`const ${name} = ${spec.name}.${name}`);
            }
        }
        if (((spec.exports && spec.exports.structs) || []).includes(spec.name) || (spec.exports && spec.exports.hasProtos)) {
            lines.push(`type ${spec.name} = ${spec.name}.${spec.name}`);
        }
    }
    return { lines, services };
}
function insertModuleRequires(luau, modules, fromOutRel) {
    return insertPreamble(luau, modules, [], fromOutRel);
}
function stripServiceGets(luau, services) {
    let next = String(luau);
    for (const name of services) {
        const line = SERVICE_GET[name];
        if (!line) {
            continue;
        }
        next = next.replace(new RegExp(`^${line.replace(/[.*+?^${}()|[\]\\]/g, "\\$&")}\\n?`, "m"), "");
    }
    return next;
}
function insertPreamble(luau, modules, libraries, fromOutRel) {
    const text = String(luau || "");
    const trimmed = text.trim();
    if (trimmed.startsWith("{") || trimmed.startsWith("[") || /\.json$/i.test(String(fromOutRel || ""))) {
        return luau;
    }
    const { lines: moduleLines, services } = moduleRequireLines(modules, fromOutRel, luau);
    const libList = libraries || [];
    if (libList.length) {
        services.add("ReplicatedStorage");
    }
    if (moduleLines.length === 0 && libList.length === 0) {
        return luau;
    }
    const { api: libApi, types: libTypes } = emitLibraryLines(libList);
    const blockLines = [];
    for (const name of SERVICE_ORDER) {
        if (services.has(name)) {
            blockLines.push(SERVICE_GET[name]);
        }
    }
    blockLines.push(...moduleLines);
    blockLines.push(...libApi);
    blockLines.push(...libTypes);
    const body = stripServiceGets(luau, services);
    return insertBlock(body, blockLines.join("\n"));
}
function insertBlock(luau, block) {
    const match = String(luau).match(/^(?:--[^\n]*\n)+/);
    if (!match) {
        return `${block}\n${luau}`;
    }
    const insertAt = match[0].length;
    const rest = luau.slice(insertAt).replace(/^\n*/, "\n");
    return `${luau.slice(0, insertAt)}\n${block}\n${rest}`;
}
function libraryNamesFromIncludes(source) {
    return [...modulesFromIncludes(source)];
}
