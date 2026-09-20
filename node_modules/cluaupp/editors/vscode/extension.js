"use strict";

const fs = require("fs");
const path = require("path");
const vscode = require("vscode");

function loadEngine(context) {
	const folders = vscode.workspace.workspaceFolders || [];
	const workspaceFolder = folders[0] ? folders[0].uri.fsPath : null;
	const rootFile = path.join(context.extensionPath, "cluaupp.root");
	const roots = [];
	if (fs.existsSync(rootFile)) {
		roots.push(fs.readFileSync(rootFile, "utf8").trim());
	}
	if (workspaceFolder) {
		roots.push(path.join(workspaceFolder, "..", "Cluaupp"));
		roots.push(path.join(workspaceFolder, "node_modules", "cluaupp"));
	}
	roots.push(path.join(context.extensionPath, "..", ".."));
	for (const root of roots) {
		const candidates = [
			path.join(root, "generated", "intellisense.js"),
			path.join(root, "src", "intellisense.js"),
		];
		for (const engine of candidates) {
			if (fs.existsSync(engine)) {
				return { engine: require(engine), root, workspaceFolder, enginePath: engine };
			}
		}
	}
	throw new Error("Cluaupp editor helper not found. Run `cluaupp intellisense` then `clpp install`.");
}

function activate(context) {
	let loaded;
	try {
		loaded = loadEngine(context);
	} catch (err) {
		vscode.window.showWarningMessage(String(err.message || err));
		return;
	}

	const diagnostics = vscode.languages.createDiagnosticCollection("cluaupp");
	context.subscriptions.push(diagnostics);

	const clearCluaupp = (document) => {
		if (!document || document.languageId !== "clpp") {
			return;
		}
		diagnostics.set(document.uri, []);
	};

	context.subscriptions.push(
		vscode.workspace.onDidOpenTextDocument(clearCluaupp),
		vscode.commands.registerCommand("cluaupp.restartIntelliSense", () => {
			try {
				delete require.cache[require.resolve(loaded.enginePath)];
				loaded = loadEngine(context);
				diagnostics.clear();
				vscode.window.showInformationMessage("Cluaupp helper reloaded. Language diagnostics come from clpp install.");
			} catch (err) {
				vscode.window.showErrorMessage(String(err.message || err));
			}
		}),
	);

	for (const document of vscode.workspace.textDocuments) {
		clearCluaupp(document);
	}
}

function deactivate() {}

module.exports = { activate, deactivate };
