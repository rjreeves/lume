// End-to-end check of the language-server half of the extension: loads the real
// extension.js against a small stand-in for the `vscode` module and drives it
// against a real `lume.exe lsp`. Needs only Node (VS Code's own bundled one
// works: ELECTRON_RUN_AS_NODE=1 "Code.exe" test/extension.test.js).
//
// Usage: node test/extension.test.js [path\to\lume.exe]
'use strict';

const assert = require('assert');
const fs = require('fs');
const os = require('os');
const path = require('path');
const Module = require('module');

const lumePath = path.resolve(process.argv[2] || process.env.LUME || path.join(__dirname, '..', '..', '..', 'dist', 'lume.exe'));
if (!fs.existsSync(lumePath)) {
  console.error(`lume.exe not found at ${lumePath}; build it with build.ps1 or pass its path`);
  process.exit(2);
}

// ---- stand-in for the parts of the vscode API extension.js touches ----------

class Position { constructor(line, character) { this.line = line; this.character = character; } }
class Range {
  constructor(start, end) { this.start = start; this.end = end; }
  get isEmpty() { return this.start.line === this.end.line && this.start.character === this.end.character; }
}
class Uri {
  constructor(scheme, p) { this.scheme = scheme; this.path = p; }
  static file(p) { return new Uri('file', '/' + p.replace(/\\/g, '/')); }
  static parse(s) {
    const m = /^file:\/\/(.*)$/.exec(s);
    return new Uri('file', decodeURIComponent(m[1]));
  }
  get fsPath() { return this.path.replace(/^\//, ''); }
  toString(skipEncoding) {
    return 'file://' + (skipEncoding ? this.path : this.path.replace(/^\/([A-Za-z]):/, '/$1%3A'));
  }
}
class Location { constructor(uri, range) { this.uri = uri; this.range = range; } }
class WorkspaceEdit {
  constructor() { this.edits = []; }
  replace(uri, range, text) { this.edits.push({ uri: uri.toString(true), range, text }); }
}
class Diagnostic { constructor(range, message, severity) { Object.assign(this, { range, message, severity }); } }
class MarkdownString { constructor() { this.value = ''; } appendCodeblock(code) { this.value += code; return this; } }
class Hover { constructor(contents) { this.contents = contents; } }
class CompletionItem { constructor(label, kind) { this.label = label; this.kind = kind; } }
class CodeAction { constructor(title, kind) { this.title = title; this.kind = kind; } }
class DocumentSymbol {
  constructor(name, detail, kind, range, selectionRange) { Object.assign(this, { name, detail, kind, range, selectionRange }); }
}
class SymbolInformation {
  constructor(name, kind, containerName, location) { Object.assign(this, { name, kind, containerName, location }); }
}

const providers = {};
const diagnosticSets = new Map();
const listeners = {};
const textDocuments = [];
const registered = [];

const disposable = { dispose() {} };
const provider = (name) => (selector, impl) => { providers[name] = impl; return disposable; };

const workDir = fs.mkdtempSync(path.join(os.tmpdir(), 'lspx-'));

const vscodeMock = {
  Position, Range, Uri, Location, WorkspaceEdit, Diagnostic, MarkdownString, Hover, CompletionItem,
  CodeAction, DocumentSymbol, SymbolInformation,
  CodeActionKind: { QuickFix: 'quickfix' },
  DiagnosticSeverity: { Error: 0 },
  DebugAdapterExecutable: class {},
  window: {
    createOutputChannel: () => ({ append() {}, appendLine(l) { if (process.env.VERBOSE) console.log(l); }, dispose() {} }),
    showWarningMessage: (m) => { throw new Error('unexpected warning: ' + m); },
  },
  workspace: {
    workspaceFolders: [{ uri: Uri.file(workDir), name: 'work' }],
    textDocuments,
    getConfiguration: () => ({ get: (key, fallback) => (key === 'path' ? lumePath : fallback) }),
    onDidOpenTextDocument: (f) => { listeners.open = f; return disposable; },
    onDidChangeTextDocument: (f) => { listeners.change = f; return disposable; },
    onDidCloseTextDocument: (f) => { listeners.close = f; return disposable; },
  },
  languages: {
    createDiagnosticCollection: () => ({
      set: (uri, list) => diagnosticSets.set(uri.toString(true), list),
      delete: (uri) => diagnosticSets.delete(uri.toString(true)),
      clear: () => diagnosticSets.clear(),
      dispose() {},
    }),
    registerDefinitionProvider: provider('definition'),
    registerHoverProvider: provider('hover'),
    registerReferenceProvider: provider('references'),
    registerRenameProvider: provider('rename'),
    registerCompletionItemProvider: provider('completion'),
    registerCodeActionsProvider: provider('codeActions'),
    registerDocumentSymbolProvider: provider('documentSymbol'),
    registerWorkspaceSymbolProvider: (impl) => { providers.workspaceSymbol = impl; return disposable; },
  },
  commands: { registerCommand: (name, f) => { registered.push(name); providers[name] = f; return disposable; } },
  debug: { registerDebugAdapterDescriptorFactory: () => disposable },
};

const originalLoad = Module._load;
Module._load = function (request, ...rest) {
  return request === 'vscode' ? vscodeMock : originalLoad.call(this, request, ...rest);
};

// ---- fixture ----------------------------------------------------------------

function makeDoc(name, text) {
  const file = path.join(workDir, name);
  fs.writeFileSync(file, text);
  const lines = text.split('\n');
  return {
    uri: Uri.file(file),
    languageId: 'lume',
    version: 1,
    lineCount: lines.length,
    getText: () => text,
    lineAt: (n) => ({ range: new Range(new Position(n, 0), new Position(n, lines[n].length)) }),
  };
}

function positionOf(doc, needle, occurrence = 0) {
  const lines = doc.getText().split('\n');
  let seen = 0;
  for (let line = 0; line < lines.length; line++) {
    let from = 0;
    for (;;) {
      const col = lines[line].indexOf(needle, from);
      if (col < 0) break;
      if (seen++ === occurrence) return new Position(line, col + 1);
      from = col + needle.length;
    }
  }
  throw new Error(`"${needle}" not found`);
}

async function waitFor(predicate, what) {
  for (let i = 0; i < 100; i++) {
    const value = predicate();
    if (value) return value;
    await new Promise((r) => setTimeout(r, 50));
  }
  throw new Error('timed out waiting for ' + what);
}

// ---- tests ------------------------------------------------------------------

async function main() {
  const a = makeDoc('a.lume', 'pub fn helper(x: int) -> int {\n  return x + 1\n}\n');
  const b = makeDoc('b.lume', 'use a\n\nfn main(args: [str]) -> int {\n  print(helper(1))\n  return 0\n}\n');
  const c = makeDoc('c.lume', 'fn helper(x: int) -> int {\n  return x\n}\n\nfn main(args: [str]) -> int {\n  print(helpr(1))\n  return 0\n}\n');
  // d imports e, which exists only on disk (never opened): resolving it
  // needs the server to turn the document URI back into a real path.
  fs.writeFileSync(path.join(workDir, 'e.lume'), 'pub fn only_on_disk(x: int) -> int {\n  return x\n}\n');
  const d = makeDoc('d.lume', 'use e\n\nfn main(args: [str]) -> int {\n  print(only_on_disk(1))\n  return 0\n}\n');
  textDocuments.push(a, b, c, d);

  const extension = require('../extension.js');
  const context = { subscriptions: [] };
  extension.activate(context);
  await waitFor(() => providers.definition, 'providers to register');
  assert.ok(registered.includes('lume.restartLanguageServer'), 'restart command registered');

  // diagnostics: published for c.lume, widened from column 0 to the whole line
  const cKey = c.uri.toString(true);
  const diags = await waitFor(() => diagnosticSets.get(cKey), 'diagnostics for c.lume');
  assert.strictEqual(diags.length, 1);
  assert.strictEqual(diags[0].code, 'E0216');
  assert.strictEqual(diags[0].range.start.line, 5);
  assert.strictEqual(diags[0].range.end.character, '  print(helpr(1))'.length, 'range widened to the whole line');
  console.log('ok diagnostics');

  // b.lume imports a.lume, so it must compile cleanly (one-level `use` resolution)
  const bDiags = diagnosticSets.get(b.uri.toString(true));
  assert.ok(!bDiags || bDiags.length === 0, 'no false diagnostics for a file with a resolvable import');
  console.log('ok import resolution (no false diagnostics)');

  const helperCall = positionOf(b, 'helper');
  const hover = await providers.hover.provideHover(b, helperCall);
  assert.ok(hover && /helper/.test(hover.contents.value), 'hover shows the imported signature');
  console.log('ok hover (cross-file):', hover.contents.value);

  const definition = await providers.definition.provideDefinition(b, helperCall);
  assert.strictEqual(definition.length, 1);
  assert.strictEqual(definition[0].uri.toString(true), a.uri.toString(true), 'definition points at a.lume');
  assert.strictEqual(definition[0].range.start.line, 0);
  console.log('ok definition (cross-file)');

  const diskOnlyCall = positionOf(d, 'only_on_disk');
  const diskHover = await providers.hover.provideHover(d, diskOnlyCall);
  assert.ok(diskHover && /only_on_disk/.test(diskHover.contents.value), 'hover resolves an import that is only on disk');
  const diskDefinition = await providers.definition.provideDefinition(d, diskOnlyCall);
  assert.ok(diskDefinition && /e\.lume$/.test(diskDefinition[0].uri.toString(true)), 'definition resolves an import that is only on disk');
  console.log('ok import that exists only on disk');

  const refs = await providers.references.provideReferences(b, helperCall);
  assert.ok(refs.length >= 2, 'references span both files');
  console.log('ok references');

  const rename = await providers.rename.provideRenameEdits(b, helperCall, 'assist');
  const files = new Set(rename.edits.map((e) => e.uri));
  assert.ok(files.has(a.uri.toString(true)) && files.has(b.uri.toString(true)), 'rename edits both files');
  assert.ok(rename.edits.every((e) => e.text === 'assist'));
  console.log('ok rename');

  const completion = await providers.completion.provideCompletionItems(b, new Position(3, 2));
  assert.ok(completion.some((i) => i.label === 'print' || i.label === 'str.len'), 'builtins offered');
  console.log('ok completion (%d items)', completion.length);

  const typoDiag = diags[0];
  const actions = await providers.codeActions.provideCodeActions(c, typoDiag.range, { diagnostics: [typoDiag] });
  const fix = actions.find((x) => /helper/.test(x.title));
  assert.ok(fix, 'did-you-mean action offered: ' + JSON.stringify(actions.map((x) => x.title)));
  assert.strictEqual(fix.edit.edits[0].text, 'helper');
  assert.strictEqual(fix.edit.edits[0].range.start.line, 5);
  console.log('ok code action:', fix.title);

  const symbols = await providers.documentSymbol.provideDocumentSymbols(c);
  assert.deepStrictEqual(symbols.map((s) => s.name), ['helper', 'main']);
  console.log('ok document symbols');

  const workspace = await providers.workspaceSymbol.provideWorkspaceSymbols('help');
  assert.ok(workspace.length >= 2 && workspace.every((s) => /help/i.test(s.name)), 'workspace symbols match query');
  console.log('ok workspace symbols (%d)', workspace.length);

  // live edit: fixing the typo clears the diagnostic
  const fixedText = c.getText().replace('helpr', 'helper');
  const fixed = { ...c, version: 2, getText: () => fixedText };
  listeners.change({ document: fixed, contentChanges: [{}] });
  await waitFor(() => (diagnosticSets.get(cKey) || []).length === 0, 'diagnostics to clear after the fix');
  console.log('ok didChange clears diagnostics');

  for (const d of context.subscriptions) await d.dispose();
  console.log('all extension tests passed');
}

main().then(() => process.exit(0), (error) => { console.error(error); process.exit(1); });
