"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.DATATYPES = exports.METHODS = exports.SERVICES = exports.INSTANCE_TYPES = void 0;
exports.isInstanceType = isInstanceType;
exports.isService = isService;
exports.isMethod = isMethod;
exports.isDatatype = isDatatype;
exports.luauType = luauType;
const node_module_1 = require("node:module");
const node_path_1 = __importDefault(require("node:path"));
const projectRoot = node_path_1.default.resolve(__dirname, "..");
const requireGenerated = (0, node_module_1.createRequire)(node_path_1.default.join(projectRoot, "src", "api.generated.js"));
const generated = requireGenerated("./api.generated.js");
exports.INSTANCE_TYPES = new Set(generated.INSTANCE_TYPES);
exports.SERVICES = new Set(generated.SERVICES);
exports.METHODS = new Set(generated.METHODS);
exports.DATATYPES = new Set(generated.DATATYPES);
const LUAU_TYPES = {
    void: "()",
    int: "number",
    float: "number",
    double: "number",
    bool: "boolean",
    string: "string",
    auto: null,
};
function isInstanceType(name) {
    return exports.INSTANCE_TYPES.has(name);
}
function isService(name) {
    return exports.SERVICES.has(name);
}
function isMethod(name) {
    return exports.METHODS.has(name);
}
function isDatatype(name) {
    return exports.DATATYPES.has(name);
}
function luauType(name) {
    if (!name) {
        return null;
    }
    const cleaned = String(name)
        .replace(/\*+$/, "")
        .replace(/^const\s+/, "")
        .replace(/^Enum::/, "Enum.")
        .replace(/\s+/g, " ")
        .trim();
    if (cleaned in LUAU_TYPES) {
        return LUAU_TYPES[cleaned];
    }
    const generic = cleaned.match(/^(?:std::)?(?:vector|array|span|LuaArray)\s*<\s*([^>]+)\s*>$/);
    if (generic) {
        const inner = luauType(generic[1]) || generic[1];
        return `{${inner}}`;
    }
    const optional = cleaned.match(/^(?:std::)?optional\s*<\s*([^>]+)\s*>$/);
    if (optional) {
        return `${luauType(optional[1]) || optional[1]}?`;
    }
    return cleaned;
}
