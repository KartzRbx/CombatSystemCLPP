"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.CLANGD_ID = void 0;
exports.editorBin = editorBin;
exports.isExtensionInstalled = isExtensionInstalled;
exports.findClangPlusPlus = findClangPlusPlus;
exports.ensureLlvm = ensureLlvm;
exports.installMarketplaceExtension = installMarketplaceExtension;
exports.reportInstall = reportInstall;
const node_fs_1 = __importDefault(require("node:fs"));
const node_os_1 = __importDefault(require("node:os"));
const node_path_1 = __importDefault(require("node:path"));
const node_child_process_1 = require("node:child_process");
exports.CLANGD_ID = "llvm-vs-code-extensions.vscode-clangd";
function which(command) {
    const finder = process.platform === "win32" ? "where" : "which";
    const result = (0, node_child_process_1.spawnSync)(finder, [command], { encoding: "utf8", windowsHide: true });
    if (result.status !== 0) {
        return null;
    }
    return String(result.stdout || "")
        .split(/\r?\n/)
        .map((line) => line.trim())
        .find((line) => line && !line.toLowerCase().includes("info:")) || null;
}
function editorBin() {
    const found = which("cursor") || which("code");
    if (found) {
        return found;
    }
    const local = process.env.LOCALAPPDATA || "";
    const fallbacks = [
        node_path_1.default.join(local, "Programs", "cursor", "resources", "app", "bin", "cursor.cmd"),
        node_path_1.default.join(local, "Programs", "Microsoft VS Code", "bin", "code.cmd"),
        "/usr/bin/cursor",
        "/usr/local/bin/cursor",
        "/usr/bin/code",
        "/usr/local/bin/code",
    ];
    return fallbacks.find((file) => node_fs_1.default.existsSync(file)) || null;
}
function extensionHomes() {
    return [node_path_1.default.join(node_os_1.default.homedir(), ".cursor", "extensions"), node_path_1.default.join(node_os_1.default.homedir(), ".vscode", "extensions")];
}
function isExtensionInstalled(id) {
    for (const home of extensionHomes()) {
        if (!node_fs_1.default.existsSync(home)) {
            continue;
        }
        try {
            if (node_fs_1.default.readdirSync(home).some((name) => name.startsWith(`${id}-`))) {
                return true;
            }
        }
        catch {
            // ignore
        }
    }
    const bin = editorBin();
    if (!bin) {
        return false;
    }
    const listed = (0, node_child_process_1.spawnSync)(bin, ["--list-extensions"], { encoding: "utf8", windowsHide: true, timeout: 20000 });
    return String(listed.stdout || "").split(/\r?\n/).includes(id);
}
function llvmCandidates() {
    if (process.platform === "win32") {
        return [
            "C:/Program Files/LLVM/bin/clang++.exe",
            "C:/Program Files (x86)/LLVM/bin/clang++.exe",
            node_path_1.default.join(process.env.ProgramFiles || "C:/Program Files", "LLVM", "bin", "clang++.exe"),
            "C:/msys64/ucrt64/bin/clang++.exe",
            "C:/msys64/mingw64/bin/clang++.exe",
        ];
    }
    return ["/usr/bin/clang++", "/usr/local/bin/clang++", "/opt/homebrew/bin/clang++"];
}
function findClangPlusPlus() {
    for (const candidate of llvmCandidates()) {
        if (candidate && node_fs_1.default.existsSync(candidate)) {
            return candidate.replace(/\\/g, "/");
        }
    }
    return which("clang++");
}
function ensureLlvm() {
    const found = findClangPlusPlus();
    if (found) {
        return { status: "already", path: found };
    }
    if (process.platform === "win32" && which("winget")) {
        console.log("cluaupp: installing LLVM.LLVM (clang++ / clangd) via winget");
        const result = (0, node_child_process_1.spawnSync)("winget", ["install", "--id", "LLVM.LLVM", "-e", "--accept-package-agreements", "--accept-source-agreements"], { encoding: "utf8", windowsHide: true, timeout: 300000 });
        const after = findClangPlusPlus();
        if (after) {
            return { status: "installed", path: after, how: "winget" };
        }
        return {
            status: "missing",
            detail: String(result.stderr || result.stdout || "").trim() || "winget did not install LLVM",
            hint: "winget install --id LLVM.LLVM -e",
        };
    }
    const hint = process.platform === "darwin"
        ? "brew install llvm"
        : process.platform === "win32"
            ? "winget install --id LLVM.LLVM -e"
            : "sudo apt install clang";
    return { status: "missing", hint };
}
function spawnInstall(bin, target) {
    const result = (0, node_child_process_1.spawnSync)(bin, ["--install-extension", target, "--force"], {
        encoding: "utf8",
        windowsHide: true,
        timeout: 180000,
    });
    return {
        ok: result.status === 0 && !/not found/i.test(String(result.stderr || "") + String(result.stdout || "")),
        stdout: String(result.stdout || ""),
        stderr: String(result.stderr || ""),
        status: result.status,
    };
}
async function installMarketplaceExtension(id, label) {
    if (isExtensionInstalled(id)) {
        return { status: "already", id };
    }
    const bin = editorBin();
    if (!bin) {
        return { status: "missing-editor", id };
    }
    console.log("cluaupp: installing", label || id);
    const marketplace = spawnInstall(bin, id);
    if (marketplace.ok) {
        return { status: "installed", id, how: "marketplace" };
    }
    return { status: "failed", id, detail: marketplace.stderr || marketplace.stdout };
}
function reportInstall(result, label, extraMissing) {
    if (!result) {
        return;
    }
    const name = label || result.id;
    if (result.status === "already") {
        console.log("cluaupp:", name, "already installed");
        return;
    }
    if (result.status === "installed") {
        console.log("cluaupp: installed", name, result.how ? `(${result.how})` : "");
        return;
    }
    if (result.status === "missing-editor") {
        console.error("cluaupp: Cursor/VS Code CLI not found. Install", name, "from the marketplace.");
        return;
    }
    if (result.status === "missing") {
        console.error("cluaupp: LLVM clang++ not found.", result.hint || extraMissing || "");
        if (result.detail) {
            console.error(" ", result.detail.split(/\r?\n/)[0]);
        }
        return;
    }
    console.error("cluaupp: could not install", name + ":", result.detail || "unknown error");
    if (extraMissing) {
        console.error(" ", extraMissing);
    }
}
