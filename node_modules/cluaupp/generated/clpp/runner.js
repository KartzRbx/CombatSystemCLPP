"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.hasClpp = hasClpp;
exports.resolveClppBinary = resolveClppBinary;
exports.formatClppFailure = formatClppFailure;
exports.compileViaClpp = compileViaClpp;
exports.compileViaClppAsync = compileViaClppAsync;
exports.clppManifest = clppManifest;
exports.clppVersion = clppVersion;
exports.clppInstalls = clppInstalls;
const node_child_process_1 = require("node:child_process");
const node_fs_1 = __importDefault(require("node:fs"));
const node_os_1 = __importDefault(require("node:os"));
const node_path_1 = __importDefault(require("node:path"));
const contract_js_1 = require("./contract.js");
const MISSING_CLPP = `cluaupp: clpp not found. ${contract_js_1.CLPP_INSTALL_HINT}`;
let cachedBin;
function parseSemver(text) {
    const match = String(text).match(/(\d+)\.(\d+)\.(\d+)/);
    if (!match) {
        return null;
    }
    return { major: Number(match[1]), minor: Number(match[2]), patch: Number(match[3]) };
}
function cmpSemver(a, b) {
    return a.major - b.major || a.minor - b.minor || a.patch - b.patch;
}
function minClpp() {
    return parseSemver(contract_js_1.MIN_CLPP_VERSION) || { major: 0, minor: 3, patch: 2 };
}
function tooOldMessage(bin, version) {
    return `cluaupp: clpp ${version || "unknown"} is too old (${bin}). Need CL++ ${contract_js_1.MIN_CLPP_VERSION}+. Install https://github.com/KartzRbx/CLPP/releases/download/v0.3.2/clpp-setup.exe or set CLPP / CLPP_PATH.`;
}
function probeVersion(bin) {
    const result = (0, node_child_process_1.spawnSync)(bin, ["--version"], { encoding: "utf8", windowsHide: true });
    if (result.status !== 0) {
        return null;
    }
    return String(result.stdout || result.stderr || "").trim() || null;
}
function pushCandidate(out, seen, item) {
    const value = String(item || "").trim();
    if (!value) {
        return;
    }
    const key = value.toLowerCase();
    if (seen.has(key)) {
        return;
    }
    seen.add(key);
    out.push(value);
}
function existsBin(bin) {
    try {
        return node_fs_1.default.existsSync(bin);
    }
    catch {
        return false;
    }
}
function listClppCandidates() {
    const seen = new Set();
    const override = [];
    pushCandidate(override, seen, process.env.CLPP);
    pushCandidate(override, seen, process.env.CLPP_PATH);
    const overrideExisting = override.filter(existsBin);
    if (overrideExisting.length > 0) {
        return overrideExisting;
    }
    const out = [];
    const finder = process.platform === "win32" ? "where" : "which";
    const found = (0, node_child_process_1.spawnSync)(finder, ["clpp"], { encoding: "utf8", windowsHide: true });
    if (found.status === 0) {
        for (const line of String(found.stdout || "").split(/\r?\n/)) {
            pushCandidate(out, seen, line);
        }
    }
    if (process.platform === "win32") {
        const local = process.env.LOCALAPPDATA || node_path_1.default.join(node_os_1.default.homedir(), "AppData", "Local");
        pushCandidate(out, seen, node_path_1.default.join(local, "Programs", "CLPP", "clpp.exe"));
    }
    return out.filter(existsBin);
}
function pickClppBinary() {
    const candidates = listClppCandidates();
    if (candidates.length === 0) {
        return null;
    }
    let best = null;
    let fallback = null;
    for (const bin of candidates) {
        const version = probeVersion(bin);
        const parsed = parseSemver(version || "");
        if (!fallback) {
            fallback = bin;
        }
        if (!parsed) {
            continue;
        }
        if (!best || cmpSemver(parsed, best.parsed) > 0) {
            best = { bin, parsed };
        }
    }
    return best?.bin || fallback;
}
function whichClpp() {
    if (cachedBin !== undefined) {
        return cachedBin;
    }
    cachedBin = pickClppBinary();
    return cachedBin;
}
function hasClpp() {
    return Boolean(whichClpp());
}
function resolveClppBinary() {
    const bin = whichClpp();
    if (!bin) {
        throw new Error(MISSING_CLPP);
    }
    const version = probeVersion(bin);
    const parsed = parseSemver(version || "");
    if (!parsed || cmpSemver(parsed, minClpp()) < 0) {
        throw new Error(tooOldMessage(bin, version));
    }
    return bin;
}
function parseArtifact(stdout, fileName, fallbackError) {
    const text = String(stdout || "").trim();
    try {
        const parsed = JSON.parse(text);
        if (parsed && typeof parsed === "object") {
            return parsed;
        }
    }
    catch {
        // fall through
    }
    return {
        ok: false,
        luau: "",
        fileName,
        outputHint: "",
        scriptKind: null,
        isScript: false,
        isHeader: false,
        rojoClass: "ModuleScript",
        libraries: [],
        error: fallbackError || "clpp returned invalid JSON",
    };
}
function formatClppFailure(artifact, fallback) {
    const diags = Array.isArray(artifact.diagnostics) ? artifact.diagnostics : [];
    if (diags.length > 0) {
        return diags
            .map((d) => {
            const where = `${artifact.fileName || "clpp"}:${d.line}:${d.column}`;
            return `${where}: ${d.message}`;
        })
            .join("\n");
    }
    return artifact.error || fallback;
}
function compileViaClpp(request) {
    const bin = resolveClppBinary();
    const payload = JSON.stringify({
        source: request.source,
        fileName: request.fileName,
        strict: request.strict ?? null,
    });
    const result = (0, node_child_process_1.spawnSync)(bin, ["api", "compile"], {
        input: payload,
        encoding: "utf8",
        cwd: request.cwd,
        maxBuffer: 16 * 1024 * 1024,
        windowsHide: true,
    });
    const stderr = String(result.stderr || "").trim();
    const artifact = parseArtifact(result.stdout, request.fileName, stderr || result.error?.message || "clpp api compile failed");
    if (!artifact.ok) {
        throw new Error(formatClppFailure(artifact, stderr || result.error?.message || `clpp failed (${result.status})`));
    }
    return artifact;
}
function compileViaClppAsync(request) {
    return new Promise((resolve, reject) => {
        let bin;
        try {
            bin = resolveClppBinary();
        }
        catch (err) {
            reject(err);
            return;
        }
        const child = (0, node_child_process_1.spawn)(bin, ["api", "compile"], {
            cwd: request.cwd,
            windowsHide: true,
        });
        let stdout = "";
        let stderr = "";
        child.stdout.setEncoding("utf8");
        child.stderr.setEncoding("utf8");
        child.stdout.on("data", (chunk) => {
            stdout += chunk;
        });
        child.stderr.on("data", (chunk) => {
            stderr += chunk;
        });
        child.on("error", reject);
        child.on("close", (code) => {
            const artifact = parseArtifact(stdout, request.fileName, stderr.trim() || `clpp api compile failed (${code})`);
            if (!artifact.ok) {
                reject(new Error(formatClppFailure(artifact, stderr.trim() || `clpp failed (${code})`)));
                return;
            }
            resolve(artifact);
        });
        child.stdin.end(JSON.stringify({
            source: request.source,
            fileName: request.fileName,
            strict: request.strict ?? null,
        }));
    });
}
function clppManifest() {
    const bin = resolveClppBinary();
    const result = (0, node_child_process_1.spawnSync)(bin, ["api", "manifest"], {
        encoding: "utf8",
        windowsHide: true,
    });
    if (result.status !== 0) {
        throw new Error(String(result.stderr || result.error?.message || "clpp api manifest failed"));
    }
    return JSON.parse(result.stdout);
}
function clppVersion() {
    const bin = whichClpp();
    if (!bin) {
        return null;
    }
    return probeVersion(bin);
}
function clppInstalls() {
    const selected = whichClpp();
    return listClppCandidates().map((bin) => ({
        bin,
        version: probeVersion(bin),
        selected: bin === selected,
    }));
}
