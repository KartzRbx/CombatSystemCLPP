"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.ProcessOrchestrator = void 0;
const node_child_process_1 = require("node:child_process");
const safe_paths_js_1 = require("./safe-paths.js");
function runTool(bin, args, timeout = 120000) {
    const result = (0, node_child_process_1.spawnSync)(bin, args, {
        encoding: "utf8",
        windowsHide: true,
        shell: false,
        env: (0, safe_paths_js_1.childEnv)(),
        timeout,
    });
    return {
        status: result.status,
        stdout: String(result.stdout || ""),
        stderr: String(result.stderr || ""),
        error: result.error ? result.error.message : undefined,
    };
}
function formatError(result) {
    return (result.stderr || result.stdout || result.error || "").trim();
}
class ProcessOrchestrator {
    static async formatWithStyLua(filePath) {
        await new Promise((resolve) => {
            const child = (0, node_child_process_1.spawn)("stylua", [filePath], {
                windowsHide: true,
                shell: false,
                env: (0, safe_paths_js_1.childEnv)(),
            });
            child.on("error", (error) => {
                console.warn(`[Aviso] Falha ao executar StyLua. Certifique-se de que está instalado. Detalhes: ${error.message}`);
                resolve();
            });
            child.on("close", (status) => {
                if (status !== 0) {
                    console.warn("[Aviso] Falha ao executar StyLua. Certifique-se de que está instalado.");
                }
                resolve();
            });
        });
    }
    static formatWithStyLuaSync(filePath) {
        const result = runTool("stylua", [filePath]);
        if (result.status !== 0) {
            const details = formatError(result);
            console.warn(`[Aviso] Falha ao executar StyLua. Certifique-se de que está instalado.${details ? ` Detalhes: ${details}` : ""}`);
        }
    }
    static async analyzeWithLuau(filePath) {
        return ProcessOrchestrator.analyzeWithLuauSync(filePath);
    }
    static analyzeWithLuauSync(filePath) {
        const result = runTool("luau-analyze", [filePath]);
        const details = formatError(result);
        if (result.status === 0) {
            return details || null;
        }
        return details || "Falha na análise estrutural ou erros encontrados pelo analisador Luau.";
    }
}
exports.ProcessOrchestrator = ProcessOrchestrator;
