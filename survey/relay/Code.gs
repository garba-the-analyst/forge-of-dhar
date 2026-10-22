/**
 * Shaping Dhar survey relay: a Google Apps Script web app.
 *
 * WHAT IT DOES
 *   The survey page posts a finished response here (the answers as text, plus the PDF copy the
 *   page made on the respondent's device). This script checks it, then
 *     1. emails it to the owner of the script with the PDF attached. If the respondent gave an
 *        email address, it becomes the Reply-To of the message, so pressing Reply in Gmail
 *        writes to the respondent; and
 *     2. saves it as one row in a Google Sheet on the same account ("Shaping Dhar responses"):
 *        one row per response, one column per question code, plus a "Questions" sheet holding
 *        the wording of every question. That is the record to analyse, and the safety net:
 *        if the email cannot be sent (for example Google's daily mail limit), the response is
 *        still saved and the respondent still sees "sent".
 *
 * WHAT IT CANNOT DO
 *   Nobody can send mail "from" an address they do not control: the message is sent from the
 *   owner's own Gmail account, with the display name "Shaping Dhar survey". The respondent's
 *   address appears in Reply-To and inside the message, not in From.
 *
 * WHO SEES WHAT
 *   Only the owner of this script: the inbox and the sheet are on the owner's Google account and
 *   private unless the owner shares them. Apart from the sheet, the script keeps nothing. It
 *   remembers response IDs and a counter for a few hours (the script cache) so a retry is not
 *   recorded twice and a flood is slowed down.
 *
 * SETUP (about ten minutes, on a computer; full steps in relay/SETUP.md)
 *   1. Go to script.google.com, sign in as the Gmail account that should receive responses,
 *      and choose New project.
 *   2. Replace everything in the editor with this file. Save.
 *   3. Choose the function selfTest in the toolbar and press Run. Approve the permission
 *      prompt (it is your own script, so "Advanced" then "Go to ... (unsafe)" is expected).
 *      A test email with a PDF arrives in your inbox, and the log sheet is created.
 *   4. Deploy > New deployment > type "Web app" > Execute as: Me > Who has access: Anyone.
 *      Copy the web app URL (it ends in /exec) into relayUrl in assets/config.js.
 *   5. After changing this code later, use Deploy > Manage deployments > edit > New version.
 *      The URL stays the same.
 *
 * SAFETY
 *   - The page sends a shared token. It is visible in the page source, so it only stops random
 *     requests that do not know it. The real protection is below: strict validation, a size
 *     limit, a per-hour limit, a check of Google's daily mail quota, no HTML in the message, and
 *     neutralised spreadsheet formulas in the log.
 *   - Free Gmail accounts may send about 100 emails a day through Apps Script (Google's
 *     published quota, which can change). Past that the response is saved to the sheet only.
 *     With LOG_TO_SHEET switched off, the script answers "quota" instead and the survey page
 *     offers the respondent the plain email route.
 *   - Nothing here is logged to the Executions list except error messages, never answers.
 */

var CONFIG = {
  /* Must equal relayToken in assets/config.js. Leave '' to switch the token check off. */
  TOKEN: 'db81919a8f6168304dfcedc0',

  /* Where responses are sent. '' = the Google account that owns this script. */
  RECIPIENT: '',

  /* Display name of the sender and the start of every subject (handy for a Gmail filter). */
  SENDER_NAME: 'Shaping Dhar survey',
  SUBJECT_PREFIX: 'Shaping Dhar survey response',

  /* Size limits. A real response is about 15 KB of text and a 150 KB PDF. */
  MAX_BODY_CHARS: 3500000,   /* the whole request */
  MAX_TEXT_CHARS: 200000,    /* the answers as text */
  MAX_PDF_BYTES: 2000000,    /* the PDF after decoding */

  /* Flood control. MAX_PER_HOUR counts attempts, across all respondents. */
  MAX_PER_HOUR: 40,
  QUOTA_RESERVE: 5,          /* stop when Google's remaining daily mail quota falls below this */

  DONE_TTL_SECONDS: 21600,   /* how long a delivered response ID is remembered (6 h is the maximum) */
  LOCK_WAIT_MS: 15000,

  /* The response log. true = save every response in a Google Sheet as well as emailing it.
     LOG_SPREADSHEET_ID '' = create "Shaping Dhar responses" on first use and remember it; or paste
     the ID of a spreadsheet you made yourself (the long part of its web address). */
  LOG_TO_SHEET: true,
  LOG_SPREADSHEET_ID: '',
  RESPONSES_SHEET: 'Responses',
  QUESTIONS_SHEET: 'Questions',
  MAX_CELL_CHARS: 45000      /* a cell holds at most 50,000 characters */
};

var PROTOCOL = 1;            /* must equal RELAY_PROTOCOL in assets/survey.js */
var RELAY_VERSION = '1.0';

var ID_RE = /^dhar-\d{8}-\d{6}-[a-z0-9]{6,12}$/;
var PDF_NAME_RE = /^[A-Za-z0-9._-]{1,80}\.pdf$/;
var BASE64_RE = /^[A-Za-z0-9+\/]+={0,2}$/;
var EMAIL_RE = /^[A-Za-z0-9.!#$%&'*+\/=?^_`{|}~-]+@[A-Za-z0-9](?:[A-Za-z0-9-]{0,61}[A-Za-z0-9])?(?:\.[A-Za-z0-9](?:[A-Za-z0-9-]{0,61}[A-Za-z0-9])?)+$/;
var SHAPE = 'SHAPING DHAR SURVEY RESPONSE';
var END_MARK = '== END OF RESPONSE ==';

/* The first columns of the Responses sheet; question columns (A1, A2, ...) follow, in the order
   they are first seen. */
var FIXED_COLUMNS = ['received_utc', 'response_id', 'survey_version', 'submitted', 'roles', 'answered', 'reply_to', 'pdf_copy', 'status', 'response_text'];

/* ------------------------------------------------------------------------- *
 * Entry points
 * ------------------------------------------------------------------------- */

/** The survey page posts here. The body is JSON sent as text/plain (see assets/survey.js). */
function doPost(e) {
  var result;
  try {
    result = handle_(e);
  } catch (err) {
    console.error('relay error: ' + (err && err.message));
    result = fail_('server', 'The relay hit an error. Please use the email route.', true);
  }
  return reply_(result);
}

/** Opening the web app URL in a browser shows that it is alive. It reveals nothing else. */
function doGet() {
  return reply_({ ok: true, service: 'shaping-dhar-relay', version: RELAY_VERSION, protocol: PROTOCOL });
}

/* ------------------------------------------------------------------------- *
 * The work
 * ------------------------------------------------------------------------- */

function handle_(e) {
  var raw = e && e.postData && e.postData.contents;
  if (typeof raw !== 'string' || !raw) { return fail_('bad-request', 'Empty request.'); }
  if (raw.length > CONFIG.MAX_BODY_CHARS) { return fail_('too-large', 'The response is too large.'); }

  var req;
  try { req = JSON.parse(raw); } catch (err) { return fail_('bad-request', 'Not valid JSON.'); }
  if (!req || typeof req !== 'object' || req.v !== PROTOCOL) { return fail_('bad-request', 'Unknown request format.'); }
  if (CONFIG.TOKEN && !tokenOk_(req.token)) { return fail_('forbidden', 'Not allowed.'); }
  if (typeof req.id !== 'string' || !ID_RE.test(req.id)) { return fail_('bad-request', 'Missing or malformed response ID.'); }

  var gate = admit_(req.id);
  if (gate.reply) { return gate.reply; }

  try {
    var message = compose_(req);
    var result = deliver_(req.id, message, gate.canEmail, req.test === true);
    CacheService.getScriptCache().put('id:' + req.id, 'done', CONFIG.DONE_TTL_SECONDS);
    return result;
  } catch (err) {
    CacheService.getScriptCache().remove('id:' + req.id);   /* so a retry can succeed */
    if (err instanceof Reject) { return fail_(err.code, err.message); }
    throw err;
  }
}

/* Decides whether this response may proceed. Returns { reply } to answer at once, or
   { reply: null, canEmail } to proceed (canEmail is false when Google's daily mail quota is
   nearly used up and the response will only be logged). One lock makes the duplicate check, the
   hourly counter and the "pending" mark atomic. */
function admit_(id) {
  var lock = LockService.getScriptLock();
  if (!lock.tryLock(CONFIG.LOCK_WAIT_MS)) { return { reply: fail_('busy', 'The relay is busy. Please try again.', true) }; }
  try {
    var cache = CacheService.getScriptCache();
    var seen = cache.get('id:' + id);
    if (seen === 'done') { return { reply: { ok: true, id: id, duplicate: true, delivered: 'emailed' } }; }
    if (seen === 'pending') { return { reply: fail_('busy', 'This response is already being processed.', true) }; }

    var hourKey = 'h:' + Utilities.formatDate(new Date(), 'UTC', 'yyyyMMddHH');
    var used = parseInt(cache.get(hourKey) || '0', 10) || 0;
    if (used >= CONFIG.MAX_PER_HOUR) { return { reply: fail_('too-many', 'Too many responses this hour. Please use the email route.', true) }; }

    var canEmail = MailApp.getRemainingDailyQuota() >= CONFIG.QUOTA_RESERVE;
    if (!canEmail && !CONFIG.LOG_TO_SHEET) { return { reply: fail_('quota', 'The daily sending limit has been reached. Please use the email route.', true) }; }

    cache.put(hourKey, String(used + 1), 3700);
    cache.put('id:' + id, 'pending', 600);
    return { reply: null, canEmail: canEmail };
  } finally {
    lock.releaseLock();
  }
}

/* Validates the request and builds the email. Throws Reject for anything wrong with the
   response itself. A bad PDF is dropped (the text is the record) and noted, not fatal. */
function compose_(req) {
  if (typeof req.text !== 'string') { throw new Reject('bad-request', 'Missing answers.'); }
  var text = cleanText_(req.text);
  if (text.length > CONFIG.MAX_TEXT_CHARS) { throw new Reject('too-large', 'The answers are too long.'); }
  if (text.trim().indexOf(SHAPE) !== 0) { throw new Reject('bad-request', 'These do not look like survey answers.'); }

  var id = req.id;
  var replyTo = oneLine_(req.replyTo, 254);
  if (!EMAIL_RE.test(replyTo)) { replyTo = ''; }

  var base = oneLine_(req.subject, 160);
  if (base.toLowerCase().indexOf(CONFIG.SUBJECT_PREFIX.toLowerCase()) !== 0) {
    base = CONFIG.SUBJECT_PREFIX + (base ? ': ' + base : '');
  }
  var subject = (req.test === true ? '[TEST] ' : '') + base + ' [' + id + ']';

  var blob = null, pdfNote = '';
  if (req.pdf) {
    var made = pdfBlob_(req.pdf);
    blob = made.blob;
    pdfNote = made.note;
  }

  var trailer = [
    '',
    '-- ',
    'Received by the Shaping Dhar relay ' + Utilities.formatDate(new Date(), 'UTC', "yyyy-MM-dd HH:mm 'UTC'"),
    'Response ID: ' + id,
    'PDF attached: ' + (blob ? 'yes (' + blob.getName() + ')' : 'no' + (pdfNote ? ' (' + pdfNote + ')' : '')),
    'Reply-To: ' + (replyTo || 'none given, the respondent chose not to share an email address')
  ];

  var mail = {
    to: recipient_(),
    subject: subject,
    body: text + '\n' + trailer.join('\n'),
    name: CONFIG.SENDER_NAME
  };
  if (replyTo) { mail.replyTo = replyTo; }
  if (blob) { mail.attachments = [blob]; }
  return { mail: mail, attached: !!blob, note: pdfNote, text: text, replyTo: replyTo };
}

/* Emails and logs the response. Either one is enough: the respondent is told "sent" if at least
   one worked, and the failure of the other is written to the Executions list (never the answers).
   Throws only when neither worked, so the page can offer the email route. */
function deliver_(id, message, canEmail, isTest) {
  var emailed = false, logged = false, why = '';
  if (canEmail) {
    try {
      MailApp.sendEmail(message.mail);
      emailed = true;
    } catch (err) {
      why = 'mail: ' + (err && err.message);
      console.error('relay mail error: ' + (err && err.message));
    }
  }
  if (CONFIG.LOG_TO_SHEET) {
    try {
      logResponse_(id, message, (isTest ? 'test-' : '') + (emailed ? 'emailed' : 'stored'));
      logged = true;
    } catch (err) {
      why += (why ? '; ' : '') + 'log: ' + (err && err.message);
      console.error('relay log error: ' + (err && err.message));
    }
  }
  if (!emailed && !logged) { throw new Error('Neither the email nor the log worked (' + why + ')'); }
  return {
    ok: true, id: id,
    delivered: emailed ? 'emailed' : 'stored',
    attached: emailed && message.attached,
    logged: logged,
    note: message.note
  };
}

/* Decodes and checks the PDF. Never throws: returns {blob: null, note} when it must be dropped. */
function pdfBlob_(pdf) {
  try {
    if (typeof pdf !== 'object' || typeof pdf.name !== 'string' || typeof pdf.data !== 'string') { return { blob: null, note: 'PDF malformed' }; }
    if (!PDF_NAME_RE.test(pdf.name)) { return { blob: null, note: 'PDF name not accepted' }; }
    var b64 = pdf.data.replace(/\s+/g, '');
    if (b64.length > Math.ceil(CONFIG.MAX_PDF_BYTES * 4 / 3) + 8) { return { blob: null, note: 'PDF too large' }; }
    if (!BASE64_RE.test(b64)) { return { blob: null, note: 'PDF not valid base64' }; }
    var bytes = Utilities.base64Decode(b64);   /* signed bytes (-128..127) in Apps Script */
    if (bytes.length < 100 || bytes.length > CONFIG.MAX_PDF_BYTES) { return { blob: null, note: 'PDF size not accepted' }; }
    var magic = [37, 80, 68, 70, 45];          /* "%PDF-" */
    for (var i = 0; i < magic.length; i++) {
      if ((bytes[i] & 255) !== magic[i]) { return { blob: null, note: 'not a PDF' }; }
    }
    return { blob: Utilities.newBlob(bytes, 'application/pdf', pdf.name), note: '' };
  } catch (err) {
    return { blob: null, note: 'PDF could not be read' };
  }
}

function recipient_() {
  var to = CONFIG.RECIPIENT || Session.getEffectiveUser().getEmail();
  if (!to) { throw new Error('No recipient: set CONFIG.RECIPIENT'); }
  return to;
}

/* ------------------------------------------------------------------------- *
 * The response log (a Google Sheet)
 * ------------------------------------------------------------------------- */

/* The Responses sheet has FIXED_COLUMNS first, then one column per question code. The Questions
   sheet lists the wording of each question, once per survey version. Both sheets are created on
   first use. Returns { book, responses, questions }. */
function logBook_() {
  var props = PropertiesService.getScriptProperties();
  var id = CONFIG.LOG_SPREADSHEET_ID || props.getProperty('LOG_SPREADSHEET_ID');
  var book, fresh = false;
  if (id) {
    book = SpreadsheetApp.openById(id);
  } else {
    book = SpreadsheetApp.create('Shaping Dhar responses');
    props.setProperty('LOG_SPREADSHEET_ID', book.getId());
    fresh = true;
  }
  var responses = book.getSheetByName(CONFIG.RESPONSES_SHEET);
  if (!responses) { responses = fresh ? book.getSheets()[0].setName(CONFIG.RESPONSES_SHEET) : book.insertSheet(CONFIG.RESPONSES_SHEET); }
  if (responses.getLastRow() === 0) {
    ensureColumns_(responses, FIXED_COLUMNS.length);
    responses.getRange(1, 1, 1, FIXED_COLUMNS.length).setValues([FIXED_COLUMNS]);
    responses.setFrozenRows(1);
  }
  var questions = book.getSheetByName(CONFIG.QUESTIONS_SHEET);
  if (!questions) {
    questions = book.insertSheet(CONFIG.QUESTIONS_SHEET);
    questions.getRange(1, 1, 1, 3).setValues([['code', 'survey_version', 'question']]);
    questions.setFrozenRows(1);
  }
  return { book: book, responses: responses, questions: questions };
}

/* A sheet starts with 26 columns; the survey has about 100 question codes. */
function ensureColumns_(sheet, needed) {
  var have = sheet.getMaxColumns();
  if (needed > have) { sheet.insertColumnsAfter(have, needed - have); }
}

/* Makes a value safe to store: numbers stay numbers, long text is cut to fit a cell, and text that
   a spreadsheet would run as a formula (starting with = + - @ or a control character) gets a
   leading apostrophe, which Sheets treats as "this is text". Without it, a respondent could type
   a formula into an answer. */
function cell_(value) {
  if (typeof value === 'number') { return value; }
  var s = String(value == null ? '' : value);
  if (/^(0|-?[1-9][0-9]{0,8})$/.test(s)) { return Number(s); }   /* not "0801...": a leading zero is part of a phone number */
  if (s.length > CONFIG.MAX_CELL_CHARS) { s = s.slice(0, CONFIG.MAX_CELL_CHARS) + ' [cut: see the email]'; }
  if (/^[=+\-@\t\r]/.test(s)) { s = "'" + s; }
  return s;
}

/* Appends one row to Responses and any new question wording to Questions. The lock keeps two
   responses that arrive together from writing the same cells. */
function logResponse_(id, message, status) {
  var parsed = parseResponse_(message.text);
  if (!parsed) { throw new Error('The response could not be read for the log.'); }
  var lock = LockService.getScriptLock();
  if (!lock.tryLock(CONFIG.LOCK_WAIT_MS)) { throw new Error('The log is busy.'); }
  try {
    var sheets = logBook_();
    var sheet = sheets.responses;

    var lastCol = sheet.getLastColumn();
    var headers = sheet.getRange(1, 1, 1, lastCol).getValues()[0];
    var column = {};
    headers.forEach(function (name, i) { column[name] = i; });
    var added = [];
    parsed.answers.forEach(function (a) {
      if (!(a.code in column) && added.indexOf(a.code) === -1) { added.push(a.code); }
    });
    if (added.length) {
      ensureColumns_(sheet, lastCol + added.length);
      sheet.getRange(1, lastCol + 1, 1, added.length).setValues([added]);
      added.forEach(function (name) { headers.push(name); column[name] = headers.length - 1; });
    }

    var h = parsed.header;
    var row = [];
    for (var i = 0; i < headers.length; i++) { row.push(''); }
    var fixed = {
      received_utc: Utilities.formatDate(new Date(), 'UTC', "yyyy-MM-dd'T'HH:mm:ss'Z'"),
      response_id: id,
      survey_version: h['survey version'] || '',
      submitted: h['submitted'] || '',
      roles: h['roles'] || '',
      answered: h['questions answered'] || '',
      reply_to: message.replyTo || '',
      pdf_copy: h['pdf copy'] || '',
      status: status,
      response_text: message.text
    };
    FIXED_COLUMNS.forEach(function (name) { row[column[name]] = cell_(fixed[name]); });
    parsed.answers.forEach(function (a) { row[column[a.code]] = cell_(a.value); });
    sheet.appendRow(row);

    /* The Questions sheet: wording as the respondent saw it, once per code and survey version. */
    var version = h['survey version'] || '';
    var known = {};
    var qLast = sheets.questions.getLastRow();
    if (qLast > 1) {
      sheets.questions.getRange(2, 1, qLast - 1, 2).getValues().forEach(function (r) { known[r[0] + '|' + r[1]] = true; });
    }
    parsed.answers.forEach(function (a) {
      var key = a.code + '|' + version;
      if (!known[key]) {
        known[key] = true;
        sheets.questions.appendRow([a.code, cell_(version), cell_(a.question)]);
      }
    });
  } finally {
    lock.releaseLock();
  }
}

/* Reads the report text the page writes (the format tools/parse_responses.py documents) into
   { header: { 'survey version': '1.0', ... }, answers: [{ code, question, value }] }, or null when
   it does not start with the response marker. Mirrors the Python parser so the log and a CSV made
   from the emails agree. */
function parseResponse_(text) {
  var lines = String(text).replace(/\r\n?/g, '\n').split('\n');
  var i = 0;
  while (i < lines.length && lines[i].trim() !== SHAPE) { i++; }
  if (i >= lines.length) { return null; }
  var header = {};
  for (i = i + 1; i < lines.length && lines[i].trim() !== ''; i++) {
    var colon = lines[i].indexOf(':');
    if (colon > 0) { header[lines[i].slice(0, colon).trim().toLowerCase()] = lines[i].slice(colon + 1).trim(); }
  }
  var answers = [], code = null, question = '', raw = [];
  function flush() {
    if (code !== null) { answers.push({ code: code, question: question, value: answerValue_(raw) }); }
    code = null;
    raw = [];
  }
  for (; i < lines.length; i++) {
    var line = lines[i].replace(/[ \t]+$/, '');
    if (line.trim() === END_MARK) { break; }
    var m = /^\[([A-Z]+[0-9]+[a-z]?)\]\s+(.*)$/.exec(line);
    if (m) { flush(); code = m[1]; question = m[2]; }
    else if (line.indexOf('== ') === 0) { flush(); }
    else if (code !== null) { raw.push(line); }
  }
  flush();
  return { header: header, answers: answers };
}

/* One question's answer lines as a single value: the number for a 1-5 or 0-10 scale, the option
   text, the options joined with " | ", "statement: number" pairs for a grid, or the typed text. */
function answerValue_(raw) {
  var lines = raw.map(function (l) { return l.indexOf('  ') === 0 ? l.slice(2) : l; });
  while (lines.length && !lines[lines.length - 1].trim()) { lines.pop(); }
  if (!lines.length) { return ''; }
  var m;
  if (lines.length === 1 && (m = /^\s*(\d+) of (\d+)(?: \(.*\))?$/.exec(lines[0]))) { return m[1]; }
  if (lines.every(function (l) { return l.indexOf('- ') === 0; })) {
    return lines.map(function (l) { return l.slice(2).replace(/^(.*): (\d+) of \d+$/, '$1: $2'); }).join(' | ');
  }
  var rows = lines.slice(1).filter(function (l) { return l.trim(); });
  if (/^\(1 = .*\)$/.test(lines[0]) && rows.every(function (l) { return /^- (.*): (\d+) of \d+$/.test(l); })) {
    return rows.map(function (l) { var g = /^- (.*): (\d+) of \d+$/.exec(l); return g[1] + ': ' + g[2]; }).join(' | ');
  }
  return lines.join('\n');
}

/* ------------------------------------------------------------------------- *
 * Helpers
 * ------------------------------------------------------------------------- */

function Reject(code, message) { this.code = code; this.message = message; }

function fail_(code, message, retry) { return { ok: false, code: code, message: message, retry: retry === true }; }

function reply_(obj) {
  return ContentService.createTextOutput(JSON.stringify(obj)).setMimeType(ContentService.MimeType.JSON);
}

/* Compares without stopping at the first difference. */
function tokenOk_(given) {
  var want = String(CONFIG.TOKEN);
  var got = typeof given === 'string' ? given : '';
  var diff = want.length ^ got.length;
  for (var i = 0; i < want.length; i++) { diff |= want.charCodeAt(i) ^ (got.charCodeAt(i) || 0); }
  return diff === 0;
}

/* One line, no control characters (so a header cannot be injected), at most `max` characters. */
function oneLine_(s, max) {
  return String(s == null ? '' : s).replace(/[\x00-\x1F\x7F]+/g, ' ').replace(/\s+/g, ' ').trim().slice(0, max);
}

function cleanText_(s) {
  return String(s).replace(/\r\n?/g, '\n').replace(/[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]/g, '');
}

/* ------------------------------------------------------------------------- *
 * Run this once from the editor (setup step 3). It grants the permissions the web app needs,
 * sends one test email with a tiny PDF to the owner, and creates the log sheet, through the same
 * code path as a real response (the row is marked test-emailed).
 * ------------------------------------------------------------------------- */
function selfTest() {
  var stamp = Utilities.formatDate(new Date(), 'UTC', 'yyyyMMdd-HHmmss');
  var request = {
    v: PROTOCOL,
    token: CONFIG.TOKEN,
    id: 'dhar-' + stamp + '-selftest',
    subject: 'self test',
    test: true,
    replyTo: '',
    text: SHAPE + '\nSurvey version: self-test\nRoles: none\n\n== END OF RESPONSE ==',
    pdf: { name: 'shaping-dhar-self-test.pdf', data: tinyPdfBase64_() }
  };
  var result = handle_({ postData: { contents: JSON.stringify(request) } });
  console.log(JSON.stringify(result));
  if (!result.ok) { throw new Error('Self test failed: ' + result.code + ' ' + result.message); }
  console.log('Self test passed. Check the inbox of ' + recipient_() + '.');
  if (CONFIG.LOG_TO_SHEET) { console.log('Every response is also saved here: ' + logBook_().book.getUrl()); }
}

/* A valid one-page PDF, built with correct byte offsets so every viewer opens it. */
function tinyPdfBase64_() {
  var objects = [
    '<< /Type /Catalog /Pages 2 0 R >>',
    '<< /Type /Pages /Kids [3 0 R] /Count 1 >>',
    '<< /Type /Page /Parent 2 0 R /MediaBox [0 0 300 120] /Contents 4 0 R /Resources << /Font << /F1 5 0 R >> >> >>',
    null,
    '<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>'
  ];
  var stream = 'BT /F1 14 Tf 20 60 Td (Shaping Dhar relay self test) Tj ET';
  objects[3] = '<< /Length ' + stream.length + ' >>\nstream\n' + stream + '\nendstream';
  var out = '%PDF-1.4\n', offsets = [];
  for (var i = 0; i < objects.length; i++) {
    offsets.push(out.length);
    out += (i + 1) + ' 0 obj\n' + objects[i] + '\nendobj\n';
  }
  var xref = out.length;
  out += 'xref\n0 ' + (objects.length + 1) + '\n0000000000 65535 f \n';
  for (var j = 0; j < offsets.length; j++) { out += ('0000000000' + offsets[j]).slice(-10) + ' 00000 n \n'; }
  out += 'trailer\n<< /Size ' + (objects.length + 1) + ' /Root 1 0 R >>\nstartxref\n' + xref + '\n%%EOF\n';
  return Utilities.base64Encode(Utilities.newBlob(out).getBytes());
}
