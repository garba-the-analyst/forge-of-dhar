/*
 * sandbox.js: an imitation of the few Google services relay/Code.gs uses, so the real script can
 * run under Node for tests (relay_test.js) and behind a local web server (mock_apps_script.js).
 *
 * The imitation follows the behaviour that matters here: base64Decode returns SIGNED bytes, a
 * cache value must be a string, MailApp.sendEmail counts recipients against a daily quota, and a
 * sheet has a fixed number of columns (26 to start) that must be extended before it is written
 * past, and accepts only strings, numbers and booleans as cell values.
 */
'use strict';
const fs = require('fs');
const path = require('path');
const vm = require('vm');

const SOURCE = fs.readFileSync(path.join(__dirname, '..', 'Code.gs'), 'utf8');

/* ---- a fresh imitation of Google for each test ------------------------------------------ */

/* ---- a spreadsheet, with the limits that matter ------------------------------------------------ */

function checkCell(v) {
  if (!(v === '' || typeof v === 'string' || typeof v === 'number' || typeof v === 'boolean')) {
    throw new Error('Cannot convert ' + typeof v + ' to a cell value');
  }
}

function makeSheet(w, name) {
  const sh = {
    name, rows: [], maxCols: 26, frozen: 0,
    getName() { return this.name; },
    setName(n) { this.name = n; return this; },
    getLastRow() { return this.rows.length; },
    getLastColumn() { return this.rows.reduce((m, r) => Math.max(m, r.length), 0); },
    getMaxColumns() { return this.maxCols; },
    insertColumnsAfter(position, n) { if (position !== this.maxCols) { throw new Error('only appending columns is imitated'); } this.maxCols += n; },
    setFrozenRows(n) { this.frozen = n; },
    getRange(r, c, nr, nc) {
      const self = this;
      return {
        getValues() {
          const out = [];
          for (let i = 0; i < nr; i++) {
            const row = [];
            for (let j = 0; j < nc; j++) { const v = (self.rows[r - 1 + i] || [])[c - 1 + j]; row.push(v === undefined ? '' : v); }
            out.push(row);
          }
          return out;
        },
        setValues(vals) {
          if (w.sheetThrows) { throw new Error('Service Spreadsheets failed while accessing document'); }
          if (vals.length !== nr || vals.some(v => v.length !== nc)) { throw new Error('The number of rows or columns in the data does not match the range'); }
          if (c - 1 + nc > self.maxCols) { throw new Error('The coordinates of the range are outside the dimensions of the sheet.'); }
          vals.forEach((row, i) => {
            row.forEach(checkCell);
            while (self.rows.length < r + i) { self.rows.push([]); }
            const target = self.rows[r - 1 + i];
            row.forEach((v, j) => { target[c - 1 + j] = v; });
          });
        }
      };
    },
    appendRow(vals) {
      if (w.sheetThrows) { throw new Error('Service Spreadsheets failed while accessing document'); }
      if (vals.length > this.maxCols) { throw new Error('The coordinates of the range are outside the dimensions of the sheet.'); }
      vals.forEach(checkCell);
      this.rows.push(vals.slice());
    }
  };
  return sh;
}

function makeBook(w, id, title) {
  const book = {
    id, title, sheets: [makeSheet(w, 'Sheet1')],
    getId() { return this.id; },
    getUrl() { return 'https://docs.google.com/spreadsheets/d/' + this.id + '/edit'; },
    getSheets() { return this.sheets; },
    getSheetByName(n) { return this.sheets.find(s => s.name === n) || null; },
    insertSheet(n) { const s = makeSheet(w, n); this.sheets.push(s); return s; }
  };
  w.books.set(id, book);
  return book;
}

function world(options) {
  options = options || {};
  const w = { outbox: [], errors: [], quota: options.quota === undefined ? 100 : options.quota, cache: new Map(), lockFree: true, sendThrows: !!options.sendThrows, sheetThrows: false, books: new Map(), props: new Map() };
  const sandbox = {
    console: { log() {}, error(m) { w.errors.push(String(m)); } },
    ContentService: {
      MimeType: { JSON: 'JSON' },
      createTextOutput(s) { return { content: s, mime: null, setMimeType(m) { this.mime = m; return this; } }; }
    },
    MailApp: {
      sendEmail(m) {
        if (w.sendThrows) { throw new Error('Service invoked too many times'); }
        w.outbox.push(m);
        w.quota -= 1;
      },
      getRemainingDailyQuota() { return w.quota; }
    },
    CacheService: {
      getScriptCache() {
        return {
          get(k) { return w.cache.has(k) ? w.cache.get(k) : null; },
          put(k, v, ttl) { if (typeof v !== 'string') { throw new Error('cache value must be a string'); } w.cache.set(k, v); w.lastTtl = ttl; },
          remove(k) { w.cache.delete(k); }
        };
      }
    },
    LockService: {
      getScriptLock() { return { tryLock() { return w.lockFree; }, releaseLock() {} }; }
    },

    PropertiesService: {
      getScriptProperties() {
        return { getProperty(k) { return w.props.has(k) ? w.props.get(k) : null; }, setProperty(k, v) { w.props.set(k, String(v)); } };
      }
    },
    SpreadsheetApp: {
      create(name) {
        if (w.sheetThrows) { throw new Error('Service Spreadsheets failed while accessing document'); }
        return makeBook(w, 'book' + (w.books.size + 1), name);
      },
      openById(id) {
        if (w.sheetThrows) { throw new Error('Service Spreadsheets failed while accessing document'); }
        if (!w.books.has(id)) { throw new Error('No spreadsheet with id ' + id); }
        return w.books.get(id);
      }
    },
    Session: { getEffectiveUser() { return { getEmail() { return options.owner === undefined ? 'owner@example.com' : options.owner; } }; } },
    Utilities: {
      base64Decode(s) {
        if (!/^[A-Za-z0-9+\/]*={0,2}$/.test(s)) { throw new Error('Invalid base64'); }
        return Array.from(Buffer.from(s, 'base64')).map(b => (b > 127 ? b - 256 : b));   /* signed, like Java */
      },
      base64Encode(bytes) { return Buffer.from(bytes.map(b => b & 255)).toString('base64'); },
      newBlob(data, type, name) {
        const bytes = typeof data === 'string' ? Array.from(Buffer.from(data, 'utf8')) : data;
        return { bytes, type: type || 'text/plain', name: name || '', getName() { return this.name; }, getBytes() { return this.bytes; } };
      },
      formatDate(d, tz, fmt) {
        const p = n => String(n).padStart(2, '0');
        const map = { yyyy: d.getUTCFullYear(), MM: p(d.getUTCMonth() + 1), dd: p(d.getUTCDate()), HH: p(d.getUTCHours()), mm: p(d.getUTCMinutes()), ss: p(d.getUTCSeconds()) };
        return fmt.replace(/'[^']*'|yyyy|MM|dd|HH|mm|ss/g, t => t[0] === "'" ? t.slice(1, -1) : map[t]);
      }
    }
  };
  vm.createContext(sandbox);
  vm.runInContext(SOURCE, sandbox, { filename: 'Code.gs' });
  w.run = (src) => vm.runInContext(src, sandbox);
  w.sandbox = sandbox;
  w.post = (body, raw) => {
    const out = sandbox.doPost({ postData: { contents: raw !== undefined ? raw : JSON.stringify(body), type: 'text/plain' } });
    if (w.check) { w.check(out.mime === 'JSON', 'reply is JSON'); }
    return JSON.parse(out.content);
  };
  return w;
}

module.exports = { world, SOURCE };
