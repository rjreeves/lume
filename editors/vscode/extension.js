// Two jobs, both thin wrappers around the compiler binary:
//  - debugging: launches `lume debug <program> --dap` as the debug adapter;
//  - language features: launches `lume lsp` and maps its responses onto the
//    VS Code language-provider API (see lspClient.js for the transport).
const vscode = require('vscode');
const fs = require('fs');
const path = require('path');
const { LspClient } = require('./lspClient');

// Every place lume.exe is looked for, in order, each tagged with where the
// path came from so a "not found" message can say what was tried.
function lumeCandidates(configuration, folder) {
  const candidates = [];
  if (configuration && configuration.lumePath) candidates.push({ source: 'launch configuration "lumePath"', path: configuration.lumePath });
  const setting = vscode.workspace.getConfiguration('lume').get('path');
  if (setting) candidates.push({ source: 'setting "lume.path"', path: setting });
  if (folder) candidates.push({ source: `dist\\lume.exe in workspace folder "${folder.name}"`, path: path.join(folder.uri.fsPath, 'dist', 'lume.exe') });
  return candidates;
}

function resolveLume(configuration, folder) {
  for (const candidate of lumeCandidates(configuration, folder)) {
    if (fs.existsSync(candidate.path)) return candidate.path;
  }
  return undefined;
}

function missingLumeReport(candidates, folder) {
  const lines = ['Could not find lume.exe, so the language server was not started.'];
  if (candidates.length === 0) {
    lines.push(
      folder
        ? 'No candidates: "lume.path" is not set and there is no workspace folder to look in.'
        : 'No candidates: "lume.path" is not set and no folder is open (a single file has no dist\\lume.exe to find).'
    );
  } else {
    lines.push('Looked in, in order (none exist):');
    for (const c of candidates) lines.push(`  - ${c.source}: ${c.path}`);
    if (!candidates.some((c) => c.source.startsWith('setting'))) lines.push('"lume.path" is not set.');
  }
  lines.push('Fix: build the compiler with build.ps1 and set "lume.path" to the full path of dist\\lume.exe, then run "Lume: Restart Language Server".');
  return lines.join('\n');
}

class LumeAdapterFactory {
  createDebugAdapterDescriptor(session) {
    const configuration = session.configuration;
    if (!configuration.program) {
      throw new Error('Lume debug configuration needs a "program" (the .lume file to debug).');
    }
    const lume = resolveLume(configuration, session.workspaceFolder);
    if (!lume) {
      throw new Error('Could not find lume.exe. Build it with build.ps1, or set "lume.path" / "lumePath".');
    }
    return new vscode.DebugAdapterExecutable(lume, ['debug', configuration.program, '--dap']);
  }
}

// ---------------------------------------------------------------------------
// Language server
// ---------------------------------------------------------------------------

const SELECTOR = { language: 'lume', scheme: 'file' };

// The server compares document URIs as plain strings and converts them to
// paths without percent-decoding, so send the unencoded form
// (file:///c:/dir/x.lume) rather than VS Code's default (file:///c%3A/...);
// otherwise `use` imports and workspace symbols resolve to nonsense paths.
function toServerUri(uri) {
  return uri.toString(true);
}

function toPosition(p) {
  return new vscode.Position(p.line, p.character);
}

function toRange(r) {
  return new vscode.Range(toPosition(r.start), toPosition(r.end));
}

function fromPosition(p) {
  return { line: p.line, character: p.character };
}

function toLocation(l) {
  return new vscode.Location(vscode.Uri.parse(l.uri), toRange(l.range));
}

function toWorkspaceEdit(edit) {
  const result = new vscode.WorkspaceEdit();
  if (edit && edit.changes) {
    for (const [uri, edits] of Object.entries(edit.changes)) {
      for (const e of edits) result.replace(vscode.Uri.parse(uri), toRange(e.range), e.newText);
    }
  }
  return result;
}

// LSP's CompletionItemKind and SymbolKind are 1-based; VS Code's are 0-based.
function kind(lspKind) {
  return Math.max(0, (lspKind || 1) - 1);
}

class LumeLanguageServer {
  constructor(context) {
    this.context = context;
    this.output = vscode.window.createOutputChannel('Lume Language Server');
    this.diagnostics = vscode.languages.createDiagnosticCollection('lume');
    this.client = undefined;
    this.disposables = [];
    this.warnedMissing = false;
    context.subscriptions.push(this.output, this.diagnostics, { dispose: () => this.stop() });
  }

  async start() {
    if (!vscode.workspace.getConfiguration('lume').get('lsp.enable', true)) return;
    const folder = vscode.workspace.workspaceFolders && vscode.workspace.workspaceFolders[0];
    const lume = resolveLume(undefined, folder);
    if (!lume) {
      // Always logged (the popup is shown once and is easy to miss), so the
      // output channel explains why nothing started every time.
      this.output.appendLine(missingLumeReport(lumeCandidates(undefined, folder), folder));
      if (!this.warnedMissing) {
        this.warnedMissing = true;
        vscode.window
          .showWarningMessage('Lume language server not started: could not find lume.exe.', 'Show Details')
          .then((choice) => { if (choice) this.output.show(true); });
      }
      return;
    }
    const client = new LspClient(lume, ['lsp'], { cwd: folder ? folder.uri.fsPath : undefined });
    client.on('stderr', (text) => this.output.append(text));
    client.on('protocolError', (error) => this.output.appendLine(`protocol error: ${error.message}`));
    client.on('notification', (method, params) => this.onNotification(method, params));
    client.on('exit', (error, intentional) => {
      if (!intentional) this.output.appendLine(String(error.message || error));
      if (this.client === client) this.client = undefined;
      this.diagnostics.clear();
    });
    client.start();
    this.client = client;
    this.output.appendLine(`started ${lume} lsp`);

    try {
      await client.request('initialize', {
        processId: process.pid,
        rootUri: folder ? toServerUri(folder.uri) : null,
        workspaceFolders: folder ? [{ uri: toServerUri(folder.uri), name: folder.name }] : null,
        capabilities: {},
      });
    } catch (error) {
      this.output.appendLine(`initialize failed: ${error.message}`);
      return;
    }
    client.notify('initialized', {});
    this.registerSync(client);
    this.registerProviders();
    for (const doc of vscode.workspace.textDocuments) this.didOpen(doc);
  }

  async stop() {
    for (const d of this.disposables) d.dispose();
    this.disposables = [];
    const client = this.client;
    this.client = undefined;
    if (client) await client.stop();
  }

  async restart() {
    await this.stop();
    this.diagnostics.clear();
    await this.start();
  }

  isLume(doc) {
    return doc.languageId === 'lume' && doc.uri.scheme === 'file';
  }

  didOpen(doc) {
    if (!this.client || !this.isLume(doc)) return;
    this.client.notify('textDocument/didOpen', {
      textDocument: { uri: toServerUri(doc.uri), languageId: 'lume', version: doc.version, text: doc.getText() },
    });
  }

  registerSync(client) {
    this.disposables.push(
      vscode.workspace.onDidOpenTextDocument((doc) => this.didOpen(doc)),
      vscode.workspace.onDidChangeTextDocument((event) => {
        if (!this.isLume(event.document) || event.contentChanges.length === 0) return;
        // The server only supports full-document sync.
        client.notify('textDocument/didChange', {
          textDocument: { uri: toServerUri(event.document.uri), version: event.document.version },
          contentChanges: [{ text: event.document.getText() }],
        });
      }),
      vscode.workspace.onDidCloseTextDocument((doc) => {
        if (!this.isLume(doc)) return;
        client.notify('textDocument/didClose', { textDocument: { uri: toServerUri(doc.uri) } });
        this.diagnostics.delete(doc.uri);
      })
    );
  }

  onNotification(method, params) {
    if (method !== 'textDocument/publishDiagnostics') return;
    const uri = vscode.Uri.parse(params.uri);
    const doc = vscode.workspace.textDocuments.find((d) => d.uri.toString() === uri.toString());
    const list = params.diagnostics.map((d) => {
      let range = toRange(d.range);
      // The compiler reports only a line; underline the whole line instead
      // of a zero-width range at column 0.
      if (range.isEmpty && doc && range.start.line < doc.lineCount) range = doc.lineAt(range.start.line).range;
      const diagnostic = new vscode.Diagnostic(range, d.message, Math.max(0, (d.severity || 1) - 1));
      diagnostic.source = d.source || 'lume';
      if (d.code !== undefined) diagnostic.code = String(d.code);
      return diagnostic;
    });
    this.diagnostics.set(uri, list);
  }

  async ask(method, params) {
    if (!this.client) return undefined;
    try {
      return await this.client.request(method, params);
    } catch (error) {
      this.output.appendLine(`${method} failed: ${error.message}`);
      return undefined;
    }
  }

  textPosition(doc, position) {
    return { textDocument: { uri: toServerUri(doc.uri) }, position: fromPosition(position) };
  }

  registerProviders() {
    const self = this;
    this.disposables.push(
      vscode.languages.registerDefinitionProvider(SELECTOR, {
        async provideDefinition(doc, position) {
          const result = await self.ask('textDocument/definition', self.textPosition(doc, position));
          if (!result) return undefined;
          return (Array.isArray(result) ? result : [result]).map(toLocation);
        },
      }),
      vscode.languages.registerHoverProvider(SELECTOR, {
        async provideHover(doc, position) {
          const result = await self.ask('textDocument/hover', self.textPosition(doc, position));
          if (!result || !result.contents) return undefined;
          const value = typeof result.contents === 'string' ? result.contents : result.contents.value;
          return new vscode.Hover(new vscode.MarkdownString().appendCodeblock(value, 'lume'));
        },
      }),
      vscode.languages.registerReferenceProvider(SELECTOR, {
        async provideReferences(doc, position) {
          const result = await self.ask('textDocument/references', {
            ...self.textPosition(doc, position),
            context: { includeDeclaration: true },
          });
          return result ? result.map(toLocation) : undefined;
        },
      }),
      vscode.languages.registerRenameProvider(SELECTOR, {
        async provideRenameEdits(doc, position, newName) {
          const result = await self.ask('textDocument/rename', { ...self.textPosition(doc, position), newName });
          return result ? toWorkspaceEdit(result) : undefined;
        },
      }),
      vscode.languages.registerCompletionItemProvider(SELECTOR, {
        async provideCompletionItems(doc, position) {
          const result = await self.ask('textDocument/completion', self.textPosition(doc, position));
          if (!result) return undefined;
          const items = Array.isArray(result) ? result : result.items || [];
          return items.map((item) => new vscode.CompletionItem(item.label, kind(item.kind)));
        },
      }),
      vscode.languages.registerCodeActionsProvider(SELECTOR, {
        async provideCodeActions(doc, range, context) {
          if (context.diagnostics.length === 0) return undefined;
          const result = await self.ask('textDocument/codeAction', {
            textDocument: { uri: toServerUri(doc.uri) },
            range: { start: fromPosition(range.start), end: fromPosition(range.end) },
            context: {
              diagnostics: context.diagnostics.map((d) => ({
                range: { start: fromPosition(d.range.start), end: fromPosition(d.range.end) },
                message: d.message,
                code: d.code && d.code.value !== undefined ? String(d.code.value) : String(d.code),
                severity: d.severity + 1,
                source: d.source,
              })),
            },
          });
          if (!result) return undefined;
          return result.map((a) => {
            const action = new vscode.CodeAction(a.title, vscode.CodeActionKind.QuickFix);
            action.edit = toWorkspaceEdit(a.edit);
            action.diagnostics = context.diagnostics;
            return action;
          });
        },
      }, { providedCodeActionKinds: [vscode.CodeActionKind.QuickFix] }),
      vscode.languages.registerDocumentSymbolProvider(SELECTOR, {
        async provideDocumentSymbols(doc) {
          const result = await self.ask('textDocument/documentSymbol', { textDocument: { uri: toServerUri(doc.uri) } });
          if (!result) return undefined;
          return result.map((s) => new vscode.DocumentSymbol(s.name, s.detail || '', kind(s.kind), toRange(s.range), toRange(s.selectionRange)));
        },
      }),
      vscode.languages.registerWorkspaceSymbolProvider({
        async provideWorkspaceSymbols(query) {
          const result = await self.ask('workspace/symbol', { query });
          if (!result) return undefined;
          return result.map((s) => new vscode.SymbolInformation(s.name, kind(s.kind), s.containerName || '', toLocation(s.location)));
        },
      })
    );
  }
}

function activate(context) {
  context.subscriptions.push(
    vscode.debug.registerDebugAdapterDescriptorFactory('lume', new LumeAdapterFactory())
  );
  const server = new LumeLanguageServer(context);
  context.subscriptions.push(
    vscode.commands.registerCommand('lume.restartLanguageServer', () => server.restart())
  );
  server.start();
}

function deactivate() {}

module.exports = { activate, deactivate, resolveLume, lumeCandidates, missingLumeReport, toServerUri };
