import { createRequire } from "node:module";
import path from "node:path";

const projectRoot = path.resolve(__dirname, "..");
const requireGenerated = createRequire(path.join(projectRoot, "src", "api.generated.js"));
const generated = requireGenerated("./api.generated.js") as {
	INSTANCE_TYPES: string[];
	SERVICES: string[];
	METHODS: string[];
	DATATYPES: string[];
};

export const INSTANCE_TYPES = new Set(generated.INSTANCE_TYPES);
export const SERVICES = new Set(generated.SERVICES);
export const METHODS = new Set(generated.METHODS);
export const DATATYPES = new Set(generated.DATATYPES);

const LUAU_TYPES: Record<string, string | null> = {
	void: "()",
	int: "number",
	float: "number",
	double: "number",
	bool: "boolean",
	string: "string",
	auto: null,
};

export function isInstanceType(name: string): boolean {
	return INSTANCE_TYPES.has(name);
}

export function isService(name: string): boolean {
	return SERVICES.has(name);
}

export function isMethod(name: string): boolean {
	return METHODS.has(name);
}

export function isDatatype(name: string): boolean {
	return DATATYPES.has(name);
}

export function luauType(name: string | null | undefined): string | null {
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
