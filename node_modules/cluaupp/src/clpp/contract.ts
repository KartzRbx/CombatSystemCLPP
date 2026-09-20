/** Stable CL++ ↔ Cluaupp contract (CL++ 0.3.2 / 0.3.3). Cluaupp invokes the `clpp` binary. */

export interface CompileRequest {
	source: string;
	fileName: string;
	strict?: boolean;
	cwd?: string;
}

export interface CompileDiagnostic {
	message: string;
	/** 1-based */
	line: number;
	/** 1-based */
	column: number;
	severity: string;
}

export interface CompileArtifact {
	ok: boolean;
	luau: string;
	fileName: string;
	outputHint: string;
	scriptKind: "server" | "client" | "plugin" | null;
	isScript: boolean;
	isHeader: boolean;
	rojoClass: "Script" | "LocalScript" | "ModuleScript";
	libraries: string[];
	error?: string;
	diagnostics?: CompileDiagnostic[];
}

export interface LanguageManifest {
	name: "CL++";
	id: "clpp";
	version: string;
	extensions: string[];
	tags: Array<{
		pattern: string;
		scriptKind: string;
		rojoClass: string;
	}>;
	builtins: string[];
	operators: Array<{ clpp: string; luau: string; meaning: string }>;
	io: Array<{ clpp: string; luau: string }>;
}

export const MIN_CLPP_VERSION = "0.3.2";

export const CLPP_INSTALL_HINT =
	"Install CL++ 0.3.2 or newer (clpp-setup.exe or `clpp setup`) and put `clpp` on PATH. 0.3.3 is the same JSON contract. Instances are class names (`Player player`, not `Player*`). Override with CLPP or CLPP_PATH.";
