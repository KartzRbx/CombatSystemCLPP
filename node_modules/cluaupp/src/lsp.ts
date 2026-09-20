import {
	createConnection,
	ProposedFeatures,
	TextDocuments,
	TextDocumentSyncKind,
} from "vscode-languageserver/node";
import { TextDocument } from "vscode-languageserver-textdocument";
import { pkg } from "./package-info.js";

export function start(_options: { projectRoot?: string } = {}): void {
	const connection = createConnection(ProposedFeatures.all);
	const documents = new TextDocuments(TextDocument);

	connection.onInitialize(() => ({
		capabilities: {
			textDocumentSync: TextDocumentSyncKind.Full,
		},
		serverInfo: { name: "cluaupp", version: pkg.version },
	}));

	const clear = (uri: string) => {
		connection.sendDiagnostics({ uri, diagnostics: [] });
	};

	documents.onDidOpen((event) => clear(event.document.uri));
	documents.onDidChangeContent((event) => clear(event.document.uri));
	documents.onDidClose((event) => clear(event.document.uri));

	documents.listen(connection);
	connection.listen();
}
