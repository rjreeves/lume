// A minimal Language Server Protocol client over a child process's stdio:
// Content-Length framing, request/response correlation, and notifications.
// It deliberately knows nothing about VS Code, so it can be tested with plain
// Node against a real `lume.exe lsp`, and keeps this extension free of
// dependencies (no vscode-languageclient, no build step).
'use strict';

const { spawn } = require('child_process');
const { EventEmitter } = require('events');

class LspClient extends EventEmitter {
  constructor(command, args, options) {
    super();
    this.command = command;
    this.args = args || [];
    this.options = options || {};
    this.nextId = 1;
    this.pending = new Map();
    this.buffer = Buffer.alloc(0);
    this.child = undefined;
    this.stopping = false;
  }

  start() {
    this.child = spawn(this.command, this.args, { ...this.options, stdio: ['pipe', 'pipe', 'pipe'] });
    this.child.stdout.on('data', (chunk) => this.onData(chunk));
    this.child.stderr.on('data', (chunk) => this.emit('stderr', chunk.toString('utf8')));
    this.child.on('error', (error) => this.onExit(error));
    this.child.on('exit', (code, signal) => this.onExit(new Error(`lume lsp exited (code ${code}, signal ${signal})`)));
    this.child.stdin.on('error', () => {});
  }

  onExit(error) {
    if (!this.child) return;
    this.child = undefined;
    for (const { reject } of this.pending.values()) reject(error);
    this.pending.clear();
    this.emit('exit', error, this.stopping);
  }

  onData(chunk) {
    this.buffer = Buffer.concat([this.buffer, chunk]);
    for (;;) {
      const headerEnd = this.buffer.indexOf('\r\n\r\n');
      if (headerEnd < 0) return;
      const header = this.buffer.slice(0, headerEnd).toString('ascii');
      const match = /Content-Length:\s*(\d+)/i.exec(header);
      if (!match) {
        this.buffer = this.buffer.slice(headerEnd + 4);
        continue;
      }
      const length = parseInt(match[1], 10);
      const bodyStart = headerEnd + 4;
      if (this.buffer.length < bodyStart + length) return;
      const body = this.buffer.slice(bodyStart, bodyStart + length).toString('utf8');
      this.buffer = this.buffer.slice(bodyStart + length);
      let message;
      try {
        message = JSON.parse(body);
      } catch (error) {
        this.emit('protocolError', error);
        continue;
      }
      this.dispatch(message);
    }
  }

  dispatch(message) {
    const hasMethod = typeof message.method === 'string';
    if (!hasMethod && message.id !== undefined) {
      const entry = this.pending.get(message.id);
      if (!entry) return;
      this.pending.delete(message.id);
      if (message.error) entry.reject(new Error(message.error.message || 'LSP error'));
      else entry.resolve(message.result);
    } else if (hasMethod && message.id !== undefined) {
      // A server-to-client request this client does not implement.
      this.send({ jsonrpc: '2.0', id: message.id, error: { code: -32601, message: `method not found: ${message.method}` } });
    } else if (hasMethod) {
      this.emit('notification', message.method, message.params);
    }
  }

  send(message) {
    if (!this.child) return false;
    const body = Buffer.from(JSON.stringify(message), 'utf8');
    this.child.stdin.write(`Content-Length: ${body.length}\r\n\r\n`);
    this.child.stdin.write(body);
    return true;
  }

  request(method, params) {
    return new Promise((resolve, reject) => {
      const id = this.nextId++;
      this.pending.set(id, { resolve, reject });
      if (!this.send({ jsonrpc: '2.0', id, method, params })) {
        this.pending.delete(id);
        reject(new Error('lume lsp is not running'));
      }
    });
  }

  notify(method, params) {
    this.send({ jsonrpc: '2.0', method, params });
  }

  async stop(timeoutMs = 2000) {
    if (!this.child) return;
    this.stopping = true;
    const child = this.child;
    try {
      await Promise.race([
        this.request('shutdown', null),
        new Promise((resolve) => setTimeout(resolve, timeoutMs)),
      ]);
      this.notify('exit', null);
    } catch (error) {
      // fall through to the kill below
    }
    await new Promise((resolve) => {
      const timer = setTimeout(() => { child.kill(); resolve(); }, timeoutMs);
      child.once('exit', () => { clearTimeout(timer); resolve(); });
    });
  }
}

module.exports = { LspClient };
