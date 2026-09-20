"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.parseFlare = parseFlare;
const TYPES = {
    u8: "u8",
    u16: "u16",
    u32: "u32",
    i8: "i8",
    i16: "i16",
    i32: "i32",
    int: "i32",
    f32: "f32",
    f64: "f64",
    float: "f32",
    double: "f64",
    number: "f64",
    bool: "bool",
    boolean: "bool",
    string: "string",
    Vector3: "Vector3",
    Vector2: "Vector2",
    CFrame: "CFrame",
    Color3: "Color3",
    UDim: "UDim",
    UDim2: "UDim2",
    BrickColor: "BrickColor",
    buffer: "buffer",
    Instance: "Instance",
    Player: "Player",
};
const IDENT = "[A-Za-z_][A-Za-z0-9_]*";
function fail(file, line, message) {
    throw new Error(`cluaupp flare: ${file}:${line}: ${message}`);
}
function parseType(raw, file, line) {
    const mapped = TYPES[raw];
    if (!mapped) {
        fail(file, line, `unknown type '${raw}'`);
    }
    return mapped;
}
function parseFields(list, file, line) {
    const trimmed = list.trim();
    if (!trimmed) {
        return [];
    }
    const fields = [];
    for (const part of trimmed.split(",")) {
        const piece = part.trim();
        if (!piece) {
            continue;
        }
        const match = piece.match(new RegExp(`^(${IDENT})\\s+(${IDENT})$`));
        if (!match) {
            fail(file, line, `expected 'Type name' in '${piece}'`);
        }
        fields.push({ type: parseType(match[1], file, line), name: match[2] });
    }
    return fields;
}
function parseSide(raw, file, line) {
    const side = raw.toLowerCase();
    if (side === "client") {
        return "Client";
    }
    if (side === "server") {
        return "Server";
    }
    fail(file, line, `from must be Client or Server, got '${raw}'`);
}
function parseFlare(source, filePath, defaultName) {
    const file = filePath.replace(/\\/g, "/");
    let name = defaultName;
    const packets = [];
    const queries = [];
    let packetId = 1;
    let queryId = 1;
    const lines = String(source).replace(/\r\n/g, "\n").split("\n");
    for (let i = 0; i < lines.length; i++) {
        const lineNo = i + 1;
        let line = lines[i].trim();
        if (!line || line.startsWith("#") || line.startsWith("//")) {
            continue;
        }
        const opt = line.match(/^opt\s+name\s*=\s*(.+)$/i);
        if (opt) {
            const value = opt[1].trim().replace(/^["']|["']$/g, "");
            if (!/^[A-Za-z_][A-Za-z0-9_]*$/.test(value)) {
                fail(file, lineNo, `opt name must be an identifier`);
            }
            name = value;
            continue;
        }
        const packet = line.match(new RegExp(`^packet\\s+(${IDENT})\\s*\\((.*)\\)\\s+from\\s+(Client|Server)(?:\\s+(unreliable|reliable))?\\s*$`, "i"));
        if (packet) {
            const reliable = String(packet[4] || "reliable").toLowerCase() !== "unreliable";
            if (packetId > 255) {
                fail(file, lineNo, "too many packets (max 255)");
            }
            packets.push({
                kind: "packet",
                name: packet[1],
                id: packetId++,
                from: parseSide(packet[3], file, lineNo),
                reliable,
                fields: parseFields(packet[2], file, lineNo),
            });
            continue;
        }
        const query = line.match(new RegExp(`^query\\s+(${IDENT})\\s*\\((.*)\\)\\s*->\\s*(${IDENT})\\s*$`, "i"));
        if (query) {
            if (queryId > 255) {
                fail(file, lineNo, "too many queries (max 255)");
            }
            queries.push({
                kind: "query",
                name: query[1],
                id: queryId++,
                request: parseFields(query[2], file, lineNo),
                returns: parseType(query[3], file, lineNo),
            });
            continue;
        }
        fail(file, lineNo, `expected packet Tag(Type name, ...) from Client|Server or query Tag(...) -> Type`);
    }
    if (packets.length === 0 && queries.length === 0) {
        fail(file, 1, "schema is empty — add a packet or query");
    }
    return { name, sourcePath: file, packets, queries };
}
