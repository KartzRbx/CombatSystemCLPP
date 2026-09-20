"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.start = start;
const node_1 = require("vscode-languageserver/node");
const vscode_languageserver_textdocument_1 = require("vscode-languageserver-textdocument");
const package_info_js_1 = require("./package-info.js");
function start(_options = {}) {
    const connection = (0, node_1.createConnection)(node_1.ProposedFeatures.all);
    const documents = new node_1.TextDocuments(vscode_languageserver_textdocument_1.TextDocument);
    connection.onInitialize(() => ({
        capabilities: {
            textDocumentSync: node_1.TextDocumentSyncKind.Full,
        },
        serverInfo: { name: "cluaupp", version: package_info_js_1.pkg.version },
    }));
    const clear = (uri) => {
        connection.sendDiagnostics({ uri, diagnostics: [] });
    };
    documents.onDidOpen((event) => clear(event.document.uri));
    documents.onDidChangeContent((event) => clear(event.document.uri));
    documents.onDidClose((event) => clear(event.document.uri));
    documents.listen(connection);
    connection.listen();
}
