"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.INTENTS = void 0;
exports.walk = walk;
exports.namesIn = namesIn;
exports.parseFileTag = parseFileTag;
exports.scoreIntents = scoreIntents;
exports.determineArchitecture = determineArchitecture;
exports.understandSystem = understandSystem;
const node_path_1 = __importDefault(require("node:path"));
const EXT = "(clpp|clp|clh)";
const EXT_REGEX = new RegExp(`\\.${EXT}$`, "i");
const SCORE_THRESHOLD = 2;
const TREE_NAME_TYPES = new Set([
    "identifier",
    "field_identifier",
    "type_identifier",
    "namespace_identifier",
]);
const ROBLOX_SERVICES = new Set([
    "Players",
    "Workspace",
    "Lighting",
    "ReplicatedStorage",
    "ReplicatedFirst",
    "ServerStorage",
    "ServerScriptService",
    "StarterGui",
    "StarterPack",
    "StarterPlayer",
    "SoundService",
    "TweenService",
    "RunService",
    "UserInputService",
    "ContextActionService",
    "GuiService",
    "TextChatService",
    "TextService",
    "CollectionService",
    "PhysicsService",
    "PathfindingService",
    "DataStoreService",
    "MemoryStoreService",
    "MessagingService",
    "TeleportService",
    "HttpService",
    "MarketplaceService",
    "BadgeService",
    "PolicyService",
    "ProximityPromptService",
    "HapticService",
    "VRService",
    "GamepadService",
    "TouchInputService",
    "VoiceChatService",
    "AnimationClipProvider",
    "AssetService",
    "AvatarEditorService",
    "Chat",
    "Debris",
    "InsertService",
    "JointsService",
    "KeyframeSequenceProvider",
    "LocalizationService",
    "LogService",
    "MaterialService",
    "NotificationService",
    "PointsService",
    "SocialService",
    "Stats",
    "Teams",
    "TestService",
    "TimerService",
]);
/**
 * Filename key first (roblox-ts ScriptType), then AST token density
 * (Knit/Flamework Service vs Controller naming).
 * @see https://github.com/roblox-ts/roblox-ts
 * @see https://github.com/roblox-csharp/roblox-cs
 * @see https://create.roblox.com/docs/reference/engine
 */
exports.INTENTS = {
    players: {
        role: "manager",
        module: "PlayersManager",
        side: "server",
        tokens: ["GetPlayers", "PlayerAdded", "PlayerRemoving", "Players"],
    },
    cache: {
        role: "controller",
        module: "CacheController",
        side: "server",
        tokens: ["Folder", "IntValue", "StringValue", "BoolValue", "NumberValue", "leaderstats"],
    },
    combat: {
        role: "controller",
        module: "CombatController",
        side: "server",
        tokens: [
            "TakeDamage",
            "Humanoid",
            "Raycast",
            "RaycastParams",
            "Hitbox",
            "Health",
            "Damage",
            "Weapon",
            "Tool",
            "Activated",
            "Combat",
            "Hurt",
            "Attack",
        ],
    },
    character: {
        role: "controller",
        module: "CharacterController",
        side: "any",
        tokens: ["CharacterAdded", "CharacterRemoving", "HumanoidRootPart", "GetPivot", "PivotTo", "Character"],
    },
    input: {
        role: "controller",
        module: "InputController",
        side: "client",
        tokens: [
            "UserInputService",
            "ContextActionService",
            "InputBegan",
            "InputEnded",
            "InputChanged",
            "Mouse",
            "GetMouse",
            "PreferredInput",
            "GamepadService",
            "TouchInputService",
        ],
    },
    ui: {
        role: "controller",
        module: "ViewController",
        side: "client",
        tokens: [
            "PlayerGui",
            "ScreenGui",
            "BillboardGui",
            "SurfaceGui",
            "TextLabel",
            "TextButton",
            "Frame",
            "ImageLabel",
            "TweenService",
            "Twinkle",
            "GuiService",
            "StarterGui",
        ],
    },
    net: {
        role: "controller",
        module: "NetController",
        side: "any",
        tokens: [
            "RemoteEvent",
            "RemoteFunction",
            "UnreliableRemoteEvent",
            "FireServer",
            "FireAllClients",
            "FireClient",
            "OnServerEvent",
            "OnClientEvent",
            "Net",
            "NetEvent",
        ],
    },
    data: {
        role: "service",
        module: "DataController",
        side: "server",
        tokens: [
            "DataStore",
            "DataStoreService",
            "DataService",
            "SetAsync",
            "GetAsync",
            "UpdateAsync",
            "ProfileStore",
            "GetChangedSignal",
            "WaitFor",
            "MemoryStoreService",
            "MessagingService",
        ],
    },
    animation: {
        role: "controller",
        module: "AnimationController",
        side: "any",
        tokens: ["Animator", "Animation", "AnimationTrack", "LoadAnimation"],
    },
    inventory: {
        role: "handler",
        module: "InventoryHandler",
        side: "any",
        tokens: ["Backpack", "Inventory"],
    },
    marketplace: {
        role: "service",
        module: "MarketplaceService",
        side: "server",
        tokens: ["MarketplaceService", "PromptGamePassPurchase", "PromptProductPurchase", "ProcessReceipt"],
    },
    collection: {
        role: "manager",
        module: "CollectionManager",
        side: "shared",
        tokens: ["CollectionService", "GetTagged", "AddTag", "RemoveTag", "GetInstanceAddedSignal"],
    },
    proximity: {
        role: "handler",
        module: "ProximityHandler",
        side: "any",
        tokens: ["ProximityPrompt", "ProximityPromptService", "Triggered"],
    },
    camera: {
        role: "controller",
        module: "CameraController",
        side: "client",
        tokens: ["CurrentCamera", "Camera", "CameraType", "CameraSubject"],
    },
    run: {
        role: "utility",
        module: "HeartbeatUtil",
        side: "any",
        tokens: ["RunService", "Heartbeat", "RenderStepped", "Stepped", "PreSimulation"],
    },
};
function isTreeNode(node) {
    return Boolean(node &&
        typeof node === "object" &&
        "childCount" in node &&
        typeof node.child === "function");
}
function walk(node, visit) {
    if (!node || typeof node !== "object") {
        return;
    }
    visit(node);
    if (isTreeNode(node) && typeof node.childCount === "number" && node.child) {
        for (let index = 0; index < node.childCount; index += 1) {
            const child = node.child(index);
            if (child) {
                walk(child, visit);
            }
        }
        return;
    }
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
function addName(found, value) {
    if (typeof value !== "string") {
        return;
    }
    const trimmed = value.replace(/^["'<]+|["'>]+$/g, "").trim();
    if (trimmed) {
        found.add(trimmed);
    }
}
function namesIn(ast, options = {}) {
    const found = new Set();
    walk(ast, (node) => {
        const type = String(node.type || "");
        if ((type === "call" || type === "member" || type === "ident") && node.name) {
            addName(found, node.name);
        }
        if (type === "new" && node.className) {
            addName(found, node.className);
        }
        if (type === "getService" && node.service) {
            addName(found, node.service);
        }
        if (options.strings !== false && type === "string" && node.value) {
            addName(found, node.value);
        }
        if (TREE_NAME_TYPES.has(type) && typeof node.text === "string") {
            addName(found, node.text);
        }
        if (options.strings !== false && type === "string_literal" && typeof node.text === "string") {
            addName(found, node.text);
        }
    });
    return found;
}
function parseFileTag(fileName) {
    const base = node_path_1.default.basename(fileName);
    if (new RegExp(`\\.legacy\\.plugin\\.${EXT}$`, "i").test(base)) {
        return { key: "legacy.plugin", emit: "legacy", runtime: "plugin", rojo: "Script", runContext: "Plugin" };
    }
    if (new RegExp(`\\.legacy\\.server\\.${EXT}$`, "i").test(base)) {
        return { key: "legacy.server", emit: "legacy", runtime: "server", rojo: "Script", runContext: null };
    }
    if (new RegExp(`\\.legacy\\.client\\.${EXT}$`, "i").test(base)) {
        return { key: "legacy.client", emit: "legacy", runtime: "client", rojo: "LocalScript", runContext: null };
    }
    if (new RegExp(`\\.legacy\\.${EXT}$`, "i").test(base)) {
        return { key: "legacy", emit: "legacy", runtime: "server", rojo: "Script", runContext: null };
    }
    if (new RegExp(`\\.plugin\\.${EXT}$`, "i").test(base)) {
        return { key: "plugin", emit: "service", runtime: "plugin", rojo: "Script", runContext: "Plugin" };
    }
    if (new RegExp(`\\.server\\.${EXT}$`, "i").test(base)) {
        return { key: "server", emit: "service", runtime: "server", rojo: "Script", runContext: "Server" };
    }
    if (new RegExp(`\\.client\\.${EXT}$`, "i").test(base)) {
        return { key: "client", emit: "service", runtime: "client", rojo: "LocalScript", runContext: "Client" };
    }
    return { key: "module", emit: "module", runtime: "shared", rojo: "ModuleScript", runContext: null };
}
function sideWeight(runtime, side) {
    if (side === "any" || side === "shared") {
        return 1;
    }
    if (side === runtime) {
        return 1.25;
    }
    if (runtime === "shared") {
        return 0.6;
    }
    return 0.35;
}
function scoreIntents(namedSet, runtime = "shared") {
    const scored = [];
    for (const [name, spec] of Object.entries(exports.INTENTS)) {
        const evidence = spec.tokens.filter((token) => namedSet.has(token));
        if (evidence.length === 0) {
            continue;
        }
        scored.push({
            name,
            score: evidence.length * sideWeight(runtime, spec.side),
            evidence,
            role: spec.role,
            module: spec.module,
            side: spec.side,
        });
    }
    return scored.sort((a, b) => b.score - a.score || b.evidence.length - a.evidence.length);
}
function pascalUtilName(fileName) {
    let base = node_path_1.default.basename(fileName).replace(EXT_REGEX, "");
    base = base.replace(/\.legacy\.(server|client|plugin)$/i, "");
    base = base.replace(/\.(server|client|plugin)$/i, "");
    if (!base) {
        return "ModuleUtil";
    }
    const pascal = base
        .split(/[-_]+/)
        .filter(Boolean)
        .map((part) => part.charAt(0).toUpperCase() + part.slice(1))
        .join("");
    return /Util$/.test(pascal) ? pascal : `${pascal}Util`;
}
function collectInjectedServices(named, evidence) {
    const found = new Set();
    for (const token of [...evidence, ...named]) {
        if (ROBLOX_SERVICES.has(token)) {
            found.add(token);
        }
    }
    return [...found].sort();
}
const SUPPORTING_INTENTS = new Set(["players", "cache", "run"]);
function pickDominant(intents) {
    const top = intents[0];
    if (!top) {
        return undefined;
    }
    const domain = intents.find((item) => !SUPPORTING_INTENTS.has(item.name) && item.evidence.length >= SCORE_THRESHOLD);
    if (domain && (SUPPORTING_INTENTS.has(top.name) || domain.score >= top.score * 0.8)) {
        return domain;
    }
    return top;
}
function formatIntents(intents) {
    return intents.map((item) => `${item.name}:${item.evidence.length}`).join(", ");
}
function determineArchitecture(fileName, ast, tree) {
    const fileTag = parseFileTag(fileName);
    const named = new Set();
    if (ast) {
        for (const name of namesIn(ast)) {
            named.add(name);
        }
    }
    if (tree) {
        for (const name of namesIn(tree)) {
            named.add(name);
        }
    }
    const intents = scoreIntents(named, fileTag.runtime);
    const top = pickDominant(intents);
    if (!top || top.score < SCORE_THRESHOLD) {
        const suggestedModule = pascalUtilName(fileName);
        return {
            role: "utility",
            suggestedModule,
            fileTag,
            injectedServices: collectInjectedServices(named, top ? top.evidence : []),
            isUtility: true,
            intents,
            reasoning: [
                `tag ${fileTag.key} → ${fileTag.rojo} (${fileTag.emit})`,
                top ? `intents ${formatIntents(intents)} below threshold` : "intents none — utility module",
                `role utility ${suggestedModule}`,
            ],
        };
    }
    return {
        role: top.role,
        suggestedModule: top.module,
        fileTag,
        injectedServices: collectInjectedServices(named, top.evidence),
        isUtility: false,
        intents,
        reasoning: [
            `tag ${fileTag.key} → ${fileTag.rojo} (${fileTag.emit})`,
            `intents ${formatIntents(intents)}`,
            `role ${top.role} ${top.module}`,
        ],
    };
}
function understandSystem(fileName, ast, tree) {
    return determineArchitecture(fileName, ast, tree);
}
