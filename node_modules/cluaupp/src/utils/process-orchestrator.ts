import { spawn, spawnSync } from "node:child_process";
import { childEnv } from "./safe-paths.js";

type ToolResult = {
	status: number | null;
	stdout: string;
	stderr: string;
	error?: string;
};

function runTool(bin: string, args: string[], timeout = 120000): ToolResult {
	const result = spawnSync(bin, args, {
		encoding: "utf8",
		windowsHide: true,
		shell: false,
		env: childEnv(),
		timeout,
	});
	return {
		status: result.status,
		stdout: String(result.stdout || ""),
		stderr: String(result.stderr || ""),
		error: result.error ? result.error.message : undefined,
	};
}

function formatError(result: ToolResult): string {
	return (result.stderr || result.stdout || result.error || "").trim();
}

export class ProcessOrchestrator {
	public static async formatWithStyLua(filePath: string): Promise<void> {
		await new Promise<void>((resolve) => {
			const child = spawn("stylua", [filePath], {
				windowsHide: true,
				shell: false,
				env: childEnv(),
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

	public static formatWithStyLuaSync(filePath: string): void {
		const result = runTool("stylua", [filePath]);
		if (result.status !== 0) {
			const details = formatError(result);
			console.warn(`[Aviso] Falha ao executar StyLua. Certifique-se de que está instalado.${details ? ` Detalhes: ${details}` : ""}`);
		}
	}

	public static async analyzeWithLuau(filePath: string): Promise<string | null> {
		return ProcessOrchestrator.analyzeWithLuauSync(filePath);
	}

	public static analyzeWithLuauSync(filePath: string): string | null {
		const result = runTool("luau-analyze", [filePath]);
		const details = formatError(result);
		if (result.status === 0) {
			return details || null;
		}
		return details || "Falha na análise estrutural ou erros encontrados pelo analisador Luau.";
	}
}
