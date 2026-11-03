// Launches `lume debug <program> --dap` as the debug adapter. VS Code speaks
// the Debug Adapter Protocol to it over the child process's stdio, so this
// file only has to work out which lume.exe to run and with what arguments.
const vscode = require('vscode');
const fs = require('fs');
const path = require('path');

function resolveLume(configuration, folder) {
  const candidates = [];
  if (configuration.lumePath) candidates.push(configuration.lumePath);
  const setting = vscode.workspace.getConfiguration('lume').get('path');
  if (setting) candidates.push(setting);
  if (folder) candidates.push(path.join(folder.uri.fsPath, 'dist', 'lume.exe'));
  for (const candidate of candidates) {
    if (fs.existsSync(candidate)) return candidate;
  }
  return undefined;
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

function activate(context) {
  context.subscriptions.push(
    vscode.debug.registerDebugAdapterDescriptorFactory('lume', new LumeAdapterFactory())
  );
}

function deactivate() {}

module.exports = { activate, deactivate, resolveLume };
