#!/usr/bin/env node
/*
 * mock_apps_script.js: serves the real relay/Code.gs over HTTP the way an Apps Script web app
 * behaves, so the survey page can be tested end to end without Google.
 *
 * What it imitates (from Google's documentation and the known behaviour of web apps):
 *   - POST /macros/s/MOCK/exec  answers "302 Found" with a Location on another ORIGIN (another
 *     port here, script.googleusercontent.com there); the browser follows it with a GET, and
 *     THAT response carries the JSON.
 *   - the 302 and the final response both send "Access-Control-Allow-Origin: *".
 *   - there is no answer to a CORS pre-flight (OPTIONS): a page that triggers one fails here
 *     exactly as it would against Google. The page avoids it by sending text/plain.
 * Mail is not sent: MailApp is the sandbox's, and the "emails" can be read from /__outbox.
 *
 * Control endpoints (used by tests/run_tests.py):
 *   GET  /__outbox   the emails the relay "sent" (attachments as base64)
 *   GET  /__log      every request seen: method, path, content type, body size
 *   GET  /__sheets   the log spreadsheet: { Responses: [[...]], Questions: [[...]] } (or {} before the first response)
 *   POST /__mode     JSON merged into the mode: { noCors, html, dropFirst, delayMs, sendThrows, sheetThrows, logToSheet, quota }
 *   POST /__reset    fresh relay state and mode
 *
 * Usage: node relay/test/mock_apps_script.js [port]     prints {"port": N, "echoPort": M} when ready
 */
'use strict';
const http = require('http');
const { world } = require('./sandbox');

let w, mode, echo, log, posts, echoPort = 0;

function reset() {
  w = world();
  mode = { noCors: false, html: false, dropFirst: false, delayMs: 0 };
  echo = new Map();
  log = [];
  posts = 0;
}
reset();

function readBody(req) {
  return new Promise((resolve) => {
    const chunks = [];
    req.on('data', c => chunks.push(c));
    req.on('end', () => resolve(Buffer.concat(chunks).toString('utf8')));
    req.on('error', () => resolve(''));
  });
}

function cors(res) { if (!mode.noCors) { res.setHeader('Access-Control-Allow-Origin', '*'); } }

function json(res, status, obj) {
  res.writeHead(status, { 'Content-Type': 'application/json', 'Cache-Control': 'no-store' });
  res.end(JSON.stringify(obj));
}


/* The second origin: where Google's redirect sends the browser to fetch the answer. */
const echoServer = http.createServer((req, res) => {
  const url = new URL(req.url, 'http://127.0.0.1');
  cors(res);
  if (url.pathname !== '/macros/echo') { res.writeHead(404); return res.end(); }
  if (mode.html) {
    res.writeHead(200, { 'Content-Type': 'text/html; charset=utf-8' });
    return res.end('<!doctype html><title>Sign in</title><p>Sign in to continue</p>');
  }
  res.writeHead(200, { 'Content-Type': 'application/json; charset=utf-8', 'Cache-Control': 'no-store' });
  res.end(echo.get(url.searchParams.get('user_content_key')) || '{}');
});

const server = http.createServer(async (req, res) => {
  const url = new URL(req.url, 'http://127.0.0.1');
  const entry = { method: req.method, path: url.pathname, type: req.headers['content-type'] || '', size: 0, origin: req.headers.origin || '', cookie: !!req.headers.cookie };
  log.push(entry);

  if (url.pathname === '/__outbox') {
    return json(res, 200, w.outbox.map(m => Object.assign({}, m, {
      attachments: (m.attachments || []).map(a => ({ name: a.name, type: a.type, base64: Buffer.from(a.bytes.map(b => b & 255)).toString('base64') }))
    })));
  }
  if (url.pathname === '/__sheets') {
    const book = [...w.books.values()][0];
    if (!book) { return json(res, 200, {}); }
    /* a real sheet returns every row as wide as the sheet, with blanks where nothing was written */
    const padded = (sheet) => { const n = sheet.getLastColumn(); return sheet.rows.map(r => Array.from({ length: n }, (_, i) => (r[i] === undefined ? '' : r[i]))); };
    return json(res, 200, { Responses: padded(book.getSheetByName('Responses')), Questions: padded(book.getSheetByName('Questions')) });
  }
  if (url.pathname === '/__log') { return json(res, 200, log.filter(l => !l.path.startsWith('/__'))); }
  if (url.pathname === '/__reset') { reset(); return json(res, 200, { ok: true }); }
  if (url.pathname === '/__mode') {
    const patch = JSON.parse((await readBody(req)) || '{}');
    if ('quota' in patch) { w.quota = patch.quota; delete patch.quota; }
    if ('sendThrows' in patch) { w.sendThrows = !!patch.sendThrows; delete patch.sendThrows; }
    if ('sheetThrows' in patch) { w.sheetThrows = !!patch.sheetThrows; delete patch.sheetThrows; }
    if ('logToSheet' in patch) { w.run('CONFIG.LOG_TO_SHEET = ' + (patch.logToSheet ? 'true' : 'false')); delete patch.logToSheet; }
    Object.assign(mode, patch);
    return json(res, 200, mode);
  }

  if (url.pathname === '/macros/s/MOCK/exec') {
    if (req.method === 'OPTIONS') { res.writeHead(405); return res.end(); }          /* no pre-flight support */
    let out;
    if (req.method === 'POST') {
      const body = await readBody(req);
      entry.size = body.length;
      posts += 1;
      if (mode.dropFirst && posts === 1) { req.socket.destroy(); return; }          /* connection reset, mid-request */
      if (mode.delayMs) { await new Promise(r => setTimeout(r, mode.delayMs)); }
      out = w.sandbox.doPost({ postData: { contents: body, type: req.headers['content-type'] } });
    } else {
      out = w.sandbox.doGet();
    }
    const key = String(echo.size + 1);
    echo.set(key, out.content);
    cors(res);
    res.writeHead(302, { Location: 'http://127.0.0.1:' + echoPort + '/macros/echo?user_content_key=' + key, 'Cache-Control': 'no-store' });
    return res.end();
  }

  res.writeHead(404);
  res.end();
});

echoServer.listen(0, '127.0.0.1', () => {
  echoPort = echoServer.address().port;
  server.listen(Number(process.argv[2]) || 0, '127.0.0.1', () => {
    process.stdout.write(JSON.stringify({ port: server.address().port, echoPort }) + '\n');
  });
});
