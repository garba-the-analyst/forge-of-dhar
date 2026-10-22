/*
 * survey.js: the engine behind the "Shaping Dhar" survey page.
 *
 * It reads the question bank (questions.js) and the settings (config.js) and does
 * five jobs:
 *
 *   1. RENDER      builds every step of the survey as accessible HTML.
 *   2. BRANCH      shows only the steps and questions that apply to the roles
 *                  and answers the respondent has given (live, as they type).
 *   3. VALIDATE    checks required questions before moving on.
 *   4. REPORT      turns the visible, answered questions into a plain-text email.
 *   5. HAND OFF    opens the respondent's own email app, addressed to the project,
 *                  with fallbacks for long messages (see config.js).
 *
 * There is no server. Nothing is transmitted by this page itself: the only way an
 * answer leaves the device is the email the respondent presses Send on. Unfinished
 * answers are kept in the browser's localStorage on this device only.
 *
 * Plain script (no modules, no build step, no dependencies) so it also works when
 * index.html is opened straight from disk.
 */
(function () {
  'use strict';

  var SURVEY = window.DHAR_SURVEY;
  var CONFIG = window.DHAR_CONFIG;
  var mount = document.getElementById('survey');
  if (!SURVEY || !CONFIG || !mount) { return; }

  /* ======================================================================= *
   * 1. State
   * ======================================================================= */

  /* answers: { CODE: value, 'CODE#other': text }.
     value is a string (text, radio), an array of option ids (checkbox), a number
     (likert, scale) or { rowIndex: number } (grid). */
  var state = { answers: {}, stepId: 'start' };

  /* dom.q[code] = { el, num, err, inputs... }; dom.step[id] = <section> */
  var dom = { q: {}, step: {}, deep: {} };

  /* The last step is built by this file, not by the question bank. */
  var REVIEW = { id: 'review', title: 'Review and send', reportTitle: 'REVIEW', questions: [] };

  var STORAGE_KEY = CONFIG.storagePrefix + ':' + SURVEY.version;

  var reduceMotion = window.matchMedia && window.matchMedia('(prefers-reduced-motion: reduce)').matches;

  /* The folder this script was loaded from. The PDF code (pdf.js, pdf-fonts.js) sits beside it
     and is loaded on demand, so the survey itself stays light. */
  var ASSET_BASE = (function () {
    var src = document.currentScript && document.currentScript.src;
    return src ? src.replace(/[^\/]*$/, '') : 'assets/';
  })();

  /* The PDF copy can be switched off in config.js (pdfEnabled: false). */
  var PDF_ON = CONFIG.pdfEnabled !== false;

  /* Direct delivery through the relay (relay/Code.gs). Off unless config.js gives an https URL.
     RELAY_PROTOCOL must equal PROTOCOL in relay/Code.gs. */
  var RELAY_PROTOCOL = 1;
  /* https only, except a web server on this computer (http://localhost, used by the tests). */
  var RELAY_URL = typeof CONFIG.relayUrl === 'string' && /^(https:\/\/|http:\/\/(localhost|127\.0\.0\.1)[:\/])/i.test(CONFIG.relayUrl.trim()) ? CONFIG.relayUrl.trim() : '';
  var RELAY_ON = RELAY_URL !== '' && typeof window.fetch === 'function' && typeof Promise !== 'undefined';

  /* ======================================================================= *
   * 2. Small helpers
   * ======================================================================= */

  /* h('div', {class: 'x', onclick: fn}, child, [children], 'text') */
  function h(tag, attrs) {
    var node = document.createElement(tag);
    if (attrs) {
      Object.keys(attrs).forEach(function (k) {
        var v = attrs[k];
        if (v === null || v === undefined || v === false) { return; }
        if (k === 'class') { node.className = v; }
        else if (k === 'text') { node.textContent = v; }
        else if (k.slice(0, 2) === 'on') { node.addEventListener(k.slice(2), v); }
        else { node.setAttribute(k, v === true ? '' : v); }
      });
    }
    for (var i = 2; i < arguments.length; i++) { add(node, arguments[i]); }
    return node;
  }

  function add(node, kid) {
    if (kid === null || kid === undefined || kid === false) { return; }
    if (Array.isArray(kid)) { kid.forEach(function (k) { add(node, k); }); return; }
    node.appendChild(typeof kid === 'string' ? document.createTextNode(kid) : kid);
  }

  function enc(s) { return encodeURIComponent(s); }

  function pad2(n) { return (n < 10 ? '0' : '') + n; }

  /* "2026-10-17 16:34 (UTC+01:00)" in the respondent's own time zone. */
  function stamp(d) {
    var off = -d.getTimezoneOffset();
    var sign = off >= 0 ? '+' : '-';
    off = Math.abs(off);
    return d.getFullYear() + '-' + pad2(d.getMonth() + 1) + '-' + pad2(d.getDate()) + ' ' +
      pad2(d.getHours()) + ':' + pad2(d.getMinutes()) +
      ' (UTC' + sign + pad2(Math.floor(off / 60)) + ':' + pad2(off % 60) + ')';
  }

  function fileStamp(d) {
    return d.getFullYear() + pad2(d.getMonth() + 1) + pad2(d.getDate()) + '-' + pad2(d.getHours()) + pad2(d.getMinutes());
  }

  function pdfFileName(d) { return 'shaping-dhar-response-' + fileStamp(d) + '.pdf'; }

  /* A reference for one response: "dhar-20261019-154500-k3x9ab". It is printed in the report, so a
     response that arrives twice (relay and email) can be recognised, and the relay ignores a
     repeated one. The shape must match ID_RE in relay/Code.gs. */
  function responseId(d) {
    var chars = 'abcdefghijklmnopqrstuvwxyz0123456789', out = '', buf = null, i;
    try { buf = new Uint8Array(6); (window.crypto || window.msCrypto).getRandomValues(buf); } catch (e) { buf = null; }
    for (i = 0; i < 6; i++) { out += chars.charAt((buf ? buf[i] : Math.floor(Math.random() * 256)) % 36); }
    return 'dhar-' + d.getFullYear() + pad2(d.getMonth() + 1) + pad2(d.getDate()) + '-' +
      pad2(d.getHours()) + pad2(d.getMinutes()) + pad2(d.getSeconds()) + '-' + out;
  }

  function recipient() { return CONFIG.recipientUser + '@' + CONFIG.recipientDomain; }

  /* Storage can be missing or throw (private windows, blocked site data). Never rely on it. */
  function storageGet() {
    try { return window.localStorage.getItem(STORAGE_KEY); } catch (e) { return null; }
  }
  function storageSet(value) {
    try { window.localStorage.setItem(STORAGE_KEY, value); return true; } catch (e) { return false; }
  }
  function storageClear() {
    try { window.localStorage.removeItem(STORAGE_KEY); } catch (e) { /* nothing to do */ }
  }

  /* ======================================================================= *
   * 3. Question bank access, options and branching
   * ======================================================================= */

  function allQuestions() {
    var out = [];
    SURVEY.sections.forEach(function (s) { s.questions.forEach(function (q) { out.push(q); }); });
    return out;
  }

  /* String options get positional ids ("o1", "o2", ...); objects keep their own. */
  function optionsOf(q) {
    if (!q._opts) {
      q._opts = (q.options || []).map(function (o, i) {
        return typeof o === 'string' ? { id: 'o' + (i + 1), label: o } : o;
      });
    }
    return q._opts;
  }

  function optionById(q, id) {
    var list = optionsOf(q);
    for (var i = 0; i < list.length; i++) { if (list[i].id === id) { return list[i]; } }
    return null;
  }

  function rolesPicked() { return state.answers.ROLE || []; }

  /* Evaluates a showIf condition against the current answers (see questions.js). */
  function test(c) {
    if (!c) { return true; }
    if (c.all) { return c.all.every(test); }
    if (c.any) { return c.any.some(test); }
    if (c.role) { return rolesPicked().indexOf(c.role) !== -1; }
    if (c.roleAny) { return c.roleAny.some(function (r) { return rolesPicked().indexOf(r) !== -1; }); }
    if (c.q) {
      var v = state.answers[c.q];
      if (Object.prototype.hasOwnProperty.call(c, 'is')) { return v === c.is; }
      if (Object.prototype.hasOwnProperty.call(c, 'has')) { return Array.isArray(v) && v.indexOf(c.has) !== -1; }
      if (c.hasAny) { return Array.isArray(v) && c.hasAny.some(function (id) { return v.indexOf(id) !== -1; }); }
    }
    return true;
  }

  function sectionVisible(sec) { return test(sec.showIf); }

  function visibleQuestions(sec) {
    return sec.questions.filter(function (q) { return test(q.showIf); });
  }

  /* The steps the respondent will walk through right now, review step last. */
  function steps() {
    return SURVEY.sections.filter(sectionVisible).concat([REVIEW]);
  }

  function stepIndex(list, id) {
    for (var i = 0; i < list.length; i++) { if (list[i].id === id) { return i; } }
    return -1;
  }

  /* ======================================================================= *
   * 4. Answers: reading, "is it answered?", validation
   * ======================================================================= */

  function otherText(q) { return (state.answers[q.code + '#other'] || '').trim(); }

  function chosenOther(q) {
    var v = state.answers[q.code];
    if (q.type === 'radio') { var o = optionById(q, v); return !!(o && o.other); }
    if (q.type === 'checkbox' && Array.isArray(v)) {
      return v.some(function (id) { var o = optionById(q, id); return !!(o && o.other); });
    }
    return false;
  }

  function isAnswered(q) {
    var v = state.answers[q.code];
    switch (q.type) {
      case 'text': case 'textarea': case 'email': return typeof v === 'string' && v.trim() !== '';
      case 'radio': return typeof v === 'string' && v !== '';
      case 'checkbox': return Array.isArray(v) && v.length > 0;
      case 'likert': case 'scale': return typeof v === 'number';
      case 'grid': return !!v && q.rows.every(function (_, i) { return typeof v[i] === 'number'; });
      default: return false;
    }
  }

  function gridMissing(q) {
    var v = state.answers[q.code] || {};
    return q.rows.filter(function (_, i) { return typeof v[i] !== 'number'; }).length;
  }

  /* Returns '' when the question is fine, otherwise a plain instruction. */
  function problemWith(q) {
    if (!q.required) { return ''; }
    if (!isAnswered(q)) {
      switch (q.type) {
        case 'radio': return 'Choose one option.';
        case 'checkbox': return 'Choose at least one option.';
        case 'likert': return 'Pick a number from 1 to 5.';
        case 'scale': return 'Pick a number from ' + q.from + ' to ' + q.to + '.';
        case 'grid':
          var n = gridMissing(q);
          return 'Rate every line. ' + n + (n === 1 ? ' line is' : ' lines are') + ' still unrated.';
        default: return 'Add an answer.';
      }
    }
    if (chosenOther(q) && otherText(q) === '') { return 'Say what "Other" is, or untick it.'; }
    return '';
  }

  /* ======================================================================= *
   * 5. Rendering
   * ======================================================================= */

  function qid(q, suffix) { return suffix + '-' + q.code; }

  function questionShell(q, isGroup) {
    var legendId = qid(q, 'lg');
    var textNode = h('span', { class: 'q-text-body' }, q.text);
    var optional = q.required ? null : h('span', { class: 'q-opt', text: ' Optional' });
    var num = h('span', { class: 'q-num', 'aria-hidden': 'true' });
    var title = isGroup ?
      h('p', { class: 'q-text', id: legendId }, num, h('span', null, textNode, optional)) :
      h('label', { class: 'q-text', id: legendId, 'for': qid(q, 'in') }, num, h('span', null, textNode, optional));
    var hint = q.hint ? h('p', { class: 'q-hint', id: qid(q, 'hint'), text: q.hint }) : null;
    var err = h('p', { class: 'q-err', id: qid(q, 'err'), hidden: true });
    var describedBy = (q.hint ? qid(q, 'hint') + ' ' : '') + qid(q, 'err');
    var el = h('div', { class: 'q', id: qid(q, 'q'), 'data-code': q.code }, title, hint);
    /* Checkbox lists and grids need an outer group. Radio, likert and scale rows
       carry their own radiogroup role, so they do not get a second one. */
    if (q.type === 'checkbox' || q.type === 'grid') {
      el.setAttribute('role', 'group');
      el.setAttribute('aria-labelledby', legendId);
      el.setAttribute('aria-describedby', describedBy);
    }
    return { el: el, num: num, err: err, describedBy: describedBy, body: null };
  }

  function renderQuestion(q) {
    var grouped = ['radio', 'checkbox', 'likert', 'scale', 'grid'].indexOf(q.type) !== -1;
    var shell = questionShell(q, grouped);
    var rec = { el: shell.el, num: shell.num, err: shell.err, inputs: [], others: {}, count: null, q: q, describedBy: shell.describedBy };
    var body;
    switch (q.type) {
      case 'radio': body = renderChoice(q, rec, 'radio'); break;
      case 'checkbox': body = renderChoice(q, rec, 'checkbox'); break;
      case 'likert': body = renderSegment(q, rec, 1, 5, q.labels || {}, 'likert'); break;
      case 'scale': body = renderSegment(q, rec, q.from, q.to, { 1: (q.labels || {}).from, 5: (q.labels || {}).to }, 'scale'); break;
      case 'grid': body = renderGrid(q, rec); break;
      default: body = renderText(q, rec, shell.describedBy); break;
    }
    shell.el.appendChild(body);
    shell.el.appendChild(shell.err);
    dom.q[q.code] = rec;
    return shell.el;
  }

  /* radio and checkbox lists, with optional "Other" text box and "None" exclusivity */
  function renderChoice(q, rec, kind) {
    var list = h('div', { class: 'opts' + (q.layout === 'chips' ? ' chips' : '') });
    if (kind === 'radio') {
      list.setAttribute('role', 'radiogroup');
      list.setAttribute('aria-labelledby', qid(q, 'lg'));
      list.setAttribute('aria-describedby', rec.describedBy);
    }

    var lastGroup = null;
    optionsOf(q).forEach(function (o) {
      if (o.group && o.group !== lastGroup) {
        list.appendChild(h('p', { class: 'opt-group', text: o.group }));
        lastGroup = o.group;
      }
      var inputId = 'in-' + q.code + '-' + o.id;
      var input = h('input', { type: kind, name: q.code, id: inputId, value: o.id });
      input.addEventListener('change', function () { onChoice(q, o, input); });
      rec.inputs.push(input);

      var body = h('span', { class: 'opt-body' }, h('span', { class: 'opt-label', text: o.label }),
        o.hint ? h('span', { class: 'opt-hint', text: o.hint }) : null);
      var wrap = h('div', { class: 'opt-wrap' }, h('label', { class: 'opt', 'for': inputId }, input, body));

      if (o.other) {
        var other = h('input', {
          type: 'text', class: 'field other', id: 'in-' + q.code + '-other-text', maxlength: '200',
          placeholder: 'Please say what', 'aria-label': 'Other: please say what', hidden: true
        });
        other.addEventListener('input', function () {
          state.answers[q.code + '#other'] = other.value;
          clearError(q); save();
        });
        rec.others[o.id] = other;
        wrap.appendChild(other);
      }
      list.appendChild(wrap);
    });

    var out = h('div', { class: 'q-body' }, list);
    if (q.max) {
      rec.count = h('p', { class: 'q-count', 'aria-live': 'polite' });
      out.appendChild(rec.count);
    }
    return out;
  }

  function onChoice(q, option, input) {
    if (q.type === 'radio') {
      state.answers[q.code] = option.id;
    } else {
      var cur = (state.answers[q.code] || []).slice();
      var at = cur.indexOf(option.id);
      if (input.checked) {
        if (option.exclusive) { cur = []; }
        else { cur = cur.filter(function (id) { var o = optionById(q, id); return !(o && o.exclusive); }); }
        if (at === -1) { cur.push(option.id); }
      } else if (at !== -1) {
        cur.splice(at, 1);
      }
      state.answers[q.code] = cur;
    }
    clearError(q);
    syncQuestion(q);
    refresh();
    save();
  }

  /* 1-5 / 0-10 button rows. `ends` carries the labels at the low and high end. */
  function segmentRow(q, rec, name, from, to, ends, chips, onPick, labelledBy) {
    var row = h('div', { class: 'seg' + (chips ? ' seg-chips' : ''), role: 'radiogroup', 'aria-labelledby': labelledBy });
    for (var n = from; n <= to; n++) {
      (function (value) {
        var id = 'in-' + name.replace(/[^A-Za-z0-9]/g, '-') + '-' + value;
        var input = h('input', { type: 'radio', name: name, id: id, value: String(value) });
        input.addEventListener('change', function () { onPick(value); });
        rec.inputs.push(input);
        var spoken = value + ' of ' + to + (value === from && ends.low ? ', ' + ends.low : '') +
          (value === to && ends.high ? ', ' + ends.high : '') +
          (ends.mid && value === ends.midValue ? ', ' + ends.mid : '');
        row.appendChild(h('label', { class: 'seg-item', 'for': id }, input,
          h('span', { class: 'seg-n', 'aria-hidden': 'true', text: String(value) }),
          h('span', { class: 'sr', text: spoken })));
      })(n);
    }
    return row;
  }

  function endsFrom(labels, from, to) {
    var mid = labels[3] && from === 1 && to === 5 ? labels[3] : '';
    return { low: labels[1] || '', high: labels[5] || '', mid: mid, midValue: 3 };
  }

  function renderSegment(q, rec, from, to, labels, kind) {
    var ends = endsFrom(labels, from, to);
    var row = segmentRow(q, rec, q.code, from, to, ends, kind === 'scale', function (value) {
      state.answers[q.code] = value;
      clearError(q); syncQuestion(q); refresh(); save();
    }, qid(q, 'lg'));
    row.setAttribute('aria-describedby', rec.describedBy);
    var legend = h('div', { class: 'seg-ends', 'aria-hidden': 'true' },
      h('span', { text: ends.low }), ends.mid ? h('span', { class: 'mid', text: ends.mid }) : null, h('span', { text: ends.high }));
    return h('div', { class: 'q-body' }, row, legend);
  }

  function renderGrid(q, rec) {
    var labels = q.labels || {};
    var ends = endsFrom(labels, 1, 5);
    var body = h('div', { class: 'q-body grid' },
      h('p', { class: 'grid-key', text: '1 means ' + ends.low.toLowerCase() + '. 5 means ' + ends.high.toLowerCase() + '.' }));
    q.rows.forEach(function (rowText, i) {
      var labelId = 'gr-' + q.code + '-' + i;
      var row = segmentRow(q, rec, q.code + '.' + i, 1, 5, ends, false, function (value) {
        var cur = state.answers[q.code] || {};
        cur[i] = value;
        state.answers[q.code] = cur;
        clearError(q); syncQuestion(q); refresh(); save();
      }, labelId);
      body.appendChild(h('div', { class: 'grid-row' }, h('p', { class: 'grid-label', id: labelId, text: rowText }), row));
    });
    return body;
  }

  function renderText(q, rec, describedBy) {
    var common = {
      id: qid(q, 'in'), name: q.code, 'aria-describedby': describedBy,
      placeholder: q.placeholder || '', autocomplete: q.autocomplete || 'off'
    };
    var input;
    if (q.type === 'textarea') {
      input = h('textarea', Object.assign({ class: 'field', rows: '4', maxlength: '4000' }, common));
    } else {
      input = h('input', Object.assign({ class: 'field', type: q.type === 'email' ? 'email' : 'text', maxlength: '300' }, common));
    }
    input.addEventListener('input', function () {
      state.answers[q.code] = input.value;
      clearError(q); refresh(); save();
    });
    rec.inputs.push(input);
    return h('div', { class: 'q-body' }, input);
  }

  function renderSection(sec) {
    var headingId = 'h-' + sec.id;
    var el = h('section', { class: 'step', id: 'step-' + sec.id, hidden: true, 'aria-labelledby': headingId, 'data-step': sec.id });
    var count = h('p', { class: 'step-count' });
    var heading = h('h2', { class: 'step-title' + (sec.hideHeading ? ' sr' : ''), id: headingId, tabindex: '-1', text: sec.title });
    el.appendChild(h('header', { class: 'step-head' }, count, heading, sec.intro ? h('p', { class: 'step-intro', text: sec.intro }) : null));

    var body = h('div', { class: 'questions' });
    sec.questions.forEach(function (q) {
      var qEl = renderQuestion(q);
      if (q.group) {
        var d = dom.deep[q.group.id];
        if (!d) {
          var meta = h('span', { class: 'deep-meta' });
          var details = h('details', { class: 'deep', 'data-group': q.group.id },
            h('summary', null, h('span', { class: 'deep-title', text: q.group.title }), meta),
            h('div', { class: 'deep-body' }));
          d = dom.deep[q.group.id] = { el: details, meta: meta, body: details.lastChild, codes: [] };
          body.appendChild(details);
        }
        d.body.appendChild(qEl);
        d.codes.push(q.code);
      } else {
        body.appendChild(qEl);
      }
    });
    el.appendChild(body);
    dom.step[sec.id] = { el: el, count: count, heading: heading, sec: sec };
    return el;
  }

  /* ======================================================================= *
   * 6. Syncing the page with the answers
   * ======================================================================= */

  /* Pushes the stored answer for one question into its inputs (used after every
     change, and once after a saved draft is restored). */
  function syncQuestion(q) {
    var rec = dom.q[q.code];
    if (!rec) { return; }
    var v = state.answers[q.code];
    var i;
    if (q.type === 'radio' || q.type === 'checkbox') {
      var picked = q.type === 'radio' ? (v ? [v] : []) : (Array.isArray(v) ? v : []);
      var full = !!q.max && picked.length >= q.max;
      rec.inputs.forEach(function (input) {
        var id = input.value;
        var o = optionById(q, id);
        var on = picked.indexOf(id) !== -1;
        input.checked = on;
        input.disabled = full && !on && !(o && o.exclusive);
        if (rec.others[id]) {
          rec.others[id].hidden = !on;
          if (rec.others[id].value !== (state.answers[q.code + '#other'] || '')) {
            rec.others[id].value = state.answers[q.code + '#other'] || '';
          }
        }
      });
      if (rec.count) {
        rec.count.textContent = picked.length + ' of ' + q.max + ' chosen';
      }
    } else if (q.type === 'likert' || q.type === 'scale') {
      rec.inputs.forEach(function (input) { input.checked = (typeof v === 'number' && String(v) === input.value); });
    } else if (q.type === 'grid') {
      for (i = 0; i < rec.inputs.length; i++) {
        var input = rec.inputs[i];
        var row = parseInt(input.name.split('.')[1], 10);
        input.checked = !!v && typeof v[row] === 'number' && String(v[row]) === input.value;
      }
    } else if (rec.inputs[0] && rec.inputs[0].value !== (typeof v === 'string' ? v : '')) {
      rec.inputs[0].value = typeof v === 'string' ? v : '';
    }
  }

  function syncAll() { allQuestions().forEach(syncQuestion); }

  function showError(q, message) {
    var rec = dom.q[q.code];
    rec.err.textContent = message;
    rec.err.hidden = false;
    rec.el.classList.add('has-error');
    if (isTextLike(q)) { rec.inputs.forEach(function (input) { input.setAttribute('aria-invalid', 'true'); }); }
  }

  function clearError(q) {
    var rec = dom.q[q.code];
    if (!rec || rec.err.hidden) { return; }
    rec.err.hidden = true;
    rec.err.textContent = '';
    rec.el.classList.remove('has-error');
    rec.inputs.forEach(function (input) { input.removeAttribute('aria-invalid'); });
  }

  function isTextLike(q) { return q.type === 'text' || q.type === 'textarea' || q.type === 'email'; }

  /* Re-evaluates branching and updates everything that depends on it. */
  function refresh() {
    var list = steps();
    if (stepIndex(list, state.stepId) === -1) { state.stepId = list[0].id; }
    var index = stepIndex(list, state.stepId);
    var current = list[index];

    SURVEY.sections.forEach(function (sec) {
      var s = dom.step[sec.id];
      s.el.hidden = (sec.id !== state.stepId);
      if (sec.id === state.stepId) {
        var visible = visibleQuestions(sec);
        var n = 0;
        sec.questions.forEach(function (q) {
          var shown = visible.indexOf(q) !== -1;
          dom.q[q.code].el.hidden = !shown;
          if (shown && !q.group) { n += 1; dom.q[q.code].num.textContent = String(n); }
        });
      }
    });
    dom.step.review.el.hidden = (state.stepId !== 'review');

    /* Folded blocks: show a block only when one of its questions applies. */
    Object.keys(dom.deep).forEach(function (id) {
      var d = dom.deep[id];
      var qs = d.codes.map(function (code) { return dom.q[code].q; });
      var applicable = qs.filter(function (q) { return test(q.showIf); });
      var answered = applicable.filter(isAnswered).length;
      d.el.hidden = applicable.length === 0;
      d.meta.textContent = answered + ' of ' + applicable.length + ' answered';
    });
    var applicableBlocks = Object.keys(dom.deep).filter(function (id) { return !dom.deep[id].el.hidden; });
    if (state.stepId === 'areas' && applicableBlocks.length === 1 && !dom.deep[applicableBlocks[0]].opened) {
      dom.deep[applicableBlocks[0]].el.open = true;   /* a lone block is opened once, for the respondent's convenience */
      dom.deep[applicableBlocks[0]].opened = true;
    }

    /* Part counter, progress band, page mode, buttons. */
    var total = list.length;
    Object.keys(dom.step).forEach(function (id) {
      if (dom.step[id].count) {
        var at = stepIndex(list, id);
        dom.step[id].count.textContent = at === -1 || at === 0 ? '' : 'Part ' + (at + 1) + ' of ' + total;
      }
    });
    var progress = (index + 1) / total;
    document.documentElement.style.setProperty('--p', progress.toFixed(3));
    dom.bar.setAttribute('aria-valuemax', String(total));
    dom.bar.setAttribute('aria-valuenow', String(index + 1));
    dom.bar.setAttribute('aria-valuetext', 'Part ' + (index + 1) + ' of ' + total + ': ' + current.title);
    document.body.setAttribute('data-step', state.stepId);

    var last = index === total - 1;
    dom.back.hidden = index === 0;
    dom.next.hidden = last;
    dom.next.textContent = index === total - 2 ? 'Review answers' : 'Next';
  }

  /* ======================================================================= *
   * 7. Navigation and validation
   * ======================================================================= */

  function scrollToEl(el) {
    try { el.scrollIntoView({ block: 'start', behavior: reduceMotion ? 'auto' : 'smooth' }); } catch (e) { el.scrollIntoView(); }
  }

  /* Validates the visible required questions of a step. Returns the failing questions. */
  function validateStep(sec) {
    var bad = [];
    visibleQuestions(sec).forEach(function (q) {
      var message = problemWith(q);
      if (message) { showError(q, message); bad.push(q); } else { clearError(q); }
    });
    return bad;
  }

  function focusQuestion(q) {
    var rec = dom.q[q.code];
    var target = rec.inputs.filter(function (i) { return !i.disabled; })[0] || rec.inputs[0];
    if (target) { target.focus({ preventScroll: true }); }
    try { rec.el.scrollIntoView({ block: 'center', behavior: reduceMotion ? 'auto' : 'smooth' }); } catch (e) { rec.el.scrollIntoView(); }
  }

  function setNavError(count) {
    if (!count) { dom.navErr.hidden = true; dom.navErr.textContent = ''; return; }
    dom.navErr.textContent = count === 1 ?
      'One question still needs an answer. It is marked above.' :
      count + ' questions still need an answer. The first one is marked above.';
    dom.navErr.hidden = false;
  }

  function go(stepId, options) {
    state.stepId = stepId;
    setNavError(0);
    if (stepId !== 'start') { prefetchPdf(); }
    if (stepId === 'review') { buildReview(); }
    refresh();
    save();
    var s = dom.step[stepId];
    if (!options || !options.quiet) {
      s.heading.focus({ preventScroll: true });
      scrollToEl(dom.stage);
    }
  }

  function onNext() {
    var list = steps();
    var index = stepIndex(list, state.stepId);
    var sec = list[index];
    if (sec.id !== 'review') {
      var bad = validateStep(sec);
      if (bad.length) { setNavError(bad.length); focusQuestion(bad[0]); return; }
    }
    if (index < list.length - 1) { go(list[index + 1].id); }
  }

  function onBack() {
    var list = steps();
    var index = stepIndex(list, state.stepId);
    if (index > 0) { go(list[index - 1].id); }
  }

  /* ======================================================================= *
   * 8. The report (what lands in the inbox)
   * ======================================================================= */

  function roleShortNames() {
    var picked = rolesPicked();
    return SURVEY.roleQuestion.options.filter(function (o) { return picked.indexOf(o.id) !== -1; })
      .map(function (o) { return o.short || o.label; });
  }

  /* Shortens text for the compact report: cut at a word, end with "..." */
  function clip(text, n) {
    var t = String(text).replace(/\s+/g, ' ').trim();
    if (t.length <= n) { return t; }
    var cut = t.slice(0, n);
    var space = cut.lastIndexOf(' ');
    if (space > n * 0.6) { cut = cut.slice(0, space); }
    return cut.replace(/[ ,;:.]+$/, '') + '...';
  }

  var COMPACT_QUESTION_CHARS = 60;
  var COMPACT_ROW_CHARS = 40;

  function withHint(q) { return q.text + (q.hint ? ' (' + q.hint + ')' : ''); }

  function indentLines(text) {
    return String(text).replace(/\r\n?/g, '\n').trim().split('\n').map(function (l) { return '  ' + l; });
  }

  function labelFor(q, id) {
    var o = optionById(q, id);
    if (!o) { return id; }
    if (o.other) { var t = otherText(q); return 'Other: ' + (t || '(not specified)'); }
    return o.label;
  }

  /* One answered question as report lines. `compact` shortens the question wording
     (and drops the scale anchors) but never touches the answer itself. */
  function formatQuestion(q, compact) {
    var v = state.answers[q.code];
    var lines = ['[' + q.code + '] ' + (compact ? clip(q.text, COMPACT_QUESTION_CHARS) : withHint(q))];
    var labels = q.labels || {};
    switch (q.type) {
      case 'radio': lines.push('  ' + labelFor(q, v)); break;
      case 'checkbox': v.forEach(function (id) { lines.push('  - ' + labelFor(q, id)); }); break;
      case 'likert':
        lines.push('  ' + v + ' of 5' + (compact ? '' : ' (1 = ' + labels[1] + ', 5 = ' + labels[5] + ')')); break;
      case 'scale':
        lines.push('  ' + v + ' of ' + q.to + (compact ? '' : ' (' + q.from + ' = ' + labels.from + ', ' + q.to + ' = ' + labels.to + ')')); break;
      case 'grid':
        if (!compact) { lines.push('  (1 = ' + labels[1] + ', 5 = ' + labels[5] + ')'); }
        q.rows.forEach(function (row, i) {
          if (v && typeof v[i] === 'number') { lines.push('  - ' + (compact ? clip(row, COMPACT_ROW_CHARS) : row) + ': ' + v[i] + ' of 5'); }
        });
        break;
      default: lines = lines.concat(indentLines(v));
    }
    return lines;
  }

  /* The report lists the essentials first (contact, basics, overall view), then the role
     sections, then the optional area detail. If an email app ever cuts a long message,
     the part it loses is the least important one. The roles are in the header. */
  var REPORT_FIRST = ['closing', 'about', 'shared'];

  function reportSections() {
    var list = steps().filter(function (s) { return s.id !== 'review' && s.id !== 'start'; });
    var first = [];
    REPORT_FIRST.forEach(function (id) {
      list.forEach(function (s) { if (s.id === id) { first.push(s); } });
    });
    return first.concat(list.filter(function (s) { return REPORT_FIRST.indexOf(s.id) === -1; }));
  }

  /* Builds the plain-text response from the questions that are currently visible and answered.
     Answers to questions that branching has hidden are kept in storage but never reported.
     compact=true gives the same answers with shortened question wording (see buildMailto).
     `when` fixes the timestamp (so the text and the PDF agree); `pdfName` adds a "PDF copy:"
     header line so the owner can pair an attachment with its message. */
  function buildReport(compact, when, pdfName) {
    var now = when || new Date();
    var shown = 0, answered = 0, body = [];
    reportSections().forEach(function (sec) {
      var chunk = [];
      visibleQuestions(sec).forEach(function (q) {
        shown += 1;
        if (isAnswered(q)) { answered += 1; chunk = chunk.concat(formatQuestion(q, compact), ['']); }
      });
      if (chunk.length) { body = body.concat(['== ' + sec.reportTitle + ' ==', ''], chunk); }
    });

    var tz = '';
    try { tz = Intl.DateTimeFormat().resolvedOptions().timeZone || ''; } catch (e) { /* optional */ }
    var head = [
      'SHAPING DHAR SURVEY RESPONSE',
      'Survey version: ' + SURVEY.version,
      'Submitted: ' + stamp(now) + (tz ? ' ' + tz : ''),
      'Roles: ' + roleShortNames().join('; '),
      'Questions answered: ' + answered + ' of ' + shown + ' shown',
      'Question wording: ' + (compact ? 'shortened' : 'full')
    ];
    if (pdfName) { head.push('PDF copy: ' + pdfName); }
    if (dom.id) { head.push('Response ID: ' + dom.id); }
    head.push('');
    var text = head.concat(body, ['== END OF RESPONSE ==']).join('\n');
    return { text: text, answered: answered, shown: shown, date: now };
  }

  /* One visible question, described for the PDF (the shape assets/pdf.js documents). Unlike the
     email text, the PDF also lists the visible questions that were left blank. */
  function describeQuestion(q) {
    var d = { code: q.code, text: q.text, hint: q.hint || '', kind: 'none' };
    if (!isAnswered(q)) { return d; }
    var v = state.answers[q.code], labels = q.labels || {};
    switch (q.type) {
      case 'radio': d.kind = 'text'; d.value = labelFor(q, v); break;
      case 'checkbox': d.kind = 'list'; d.items = v.map(function (id) { return labelFor(q, id); }); break;
      case 'likert': d.kind = 'scale'; d.value = v; d.max = 5; d.legend = '1 = ' + labels[1] + ', 5 = ' + labels[5]; break;
      case 'scale': d.kind = 'scale'; d.value = v; d.max = q.to; d.legend = q.from + ' = ' + labels.from + ', ' + q.to + ' = ' + labels.to; break;
      case 'grid':
        d.kind = 'grid';
        d.legend = '1 = ' + labels[1] + ', 5 = ' + labels[5];
        d.rows = q.rows.map(function (row, i) { return { label: row, value: v && typeof v[i] === 'number' ? v[i] : null }; });
        break;
      default: d.kind = 'text'; d.value = String(v);
    }
    return d;
  }

  function pdfModel(report, when, name) {
    var sections = [];
    reportSections().forEach(function (sec) {
      var qs = visibleQuestions(sec).map(describeQuestion);
      if (qs.length) { sections.push({ title: sec.title, questions: qs }); }
    });
    var tz = '';
    try { tz = Intl.DateTimeFormat().resolvedOptions().timeZone || ''; } catch (e) { /* optional */ }
    return {
      title: SURVEY.title + ' survey',
      subtitle: 'A copy of the questions and your answers',
      meta: [
        ['Survey version', SURVEY.version],
        ['Submitted', stamp(when) + (tz ? ' ' + tz : '')],
        ['Roles', roleShortNames().join('; ')],
        ['Answered', report.answered + ' of ' + report.shown + ' questions'],
        ['File', name]
      ],
      sections: sections,
      footer: SURVEY.title + ' survey, version ' + SURVEY.version + ', ' + stamp(when).replace(/ \(.*$/, ''),
      created: when
    };
  }

  /* The first email address found in a visible, answered question marked `replyTo: true` in
     questions.js (the contact question). The relay makes it the Reply-To of the message.
     Returns '' when the respondent gave none, for example because they chose to stay anonymous. */
  function respondentEmail() {
    var found = '';
    allQuestions().forEach(function (q) {
      if (found || !q.replyTo) { return; }
      var sec = null;
      SURVEY.sections.forEach(function (s) { if (s.questions.indexOf(q) !== -1) { sec = s; } });
      if (!sec || !sectionVisible(sec) || visibleQuestions(sec).indexOf(q) === -1 || !isAnswered(q)) { return; }
      var m = /[^\s@<>",;:()\[\]\\]+@[^\s@<>",;:()\[\]\\]+\.[A-Za-z]{2,}/.exec(String(state.answers[q.code]));
      if (m && m[0].length <= 254) { found = m[0]; }
    });
    return found;
  }

  function subjectLine() {
    var s = CONFIG.subjectPrefix + ': ' + roleShortNames().join(', ');
    return s.length > 110 ? s.slice(0, 107) + '...' : s;
  }

  /* ======================================================================= *
   * 9. Email hand-off
   * ======================================================================= */

  var TRUNCATION_NOTE = '[Shortened by the survey page. Your full answers were copied: select all of this message, paste, and send.]';

  /* Fits `text` into a link of at most `limit` encoded characters. `base` is the
     length of everything in the link that is not the body. Cuts at a line break and
     appends TRUNCATION_NOTE when it has to cut. */
  function fitBody(text, base, limit, newline) {
    function size(s) { return enc(s.split('\n').join(newline)).length; }
    if (base + size(text) <= limit) { return { body: text, truncated: false }; }
    var budget = limit - base - size('\n' + TRUNCATION_NOTE);
    var lines = text.split('\n'), kept = [], used = 0;
    for (var i = 0; i < lines.length; i++) {
      var cost = size(lines[i] + '\n');
      if (used + cost > budget) { break; }
      kept.push(lines[i]);
      used += cost;
    }
    return { body: kept.join('\n') + '\n' + TRUNCATION_NOTE, truncated: true };
  }

  function mailtoLimit() {
    var ua = (navigator && navigator.userAgent) || '';
    return /Windows/i.test(ua) ? CONFIG.mailtoLimitWindows : CONFIG.mailtoLimitOther;
  }

  /* Chooses what goes into a link, in three tiers:
       full     the complete report fits                          -> sent as is
       compact  it does not, but every answer fits with shortened  -> nothing is lost
                question wording
       cut      even that is too long                              -> compact report cut at a line
                break (essentials come first) and marked as cut */
  function pickBody(full, compact, baseLength, limit, newline) {
    var a = fitBody(full, baseLength, limit, newline);
    if (!a.truncated) { return { body: a.body, tier: 'full' }; }
    var b = fitBody(compact, baseLength, limit, newline);
    return { body: b.body, tier: b.truncated ? 'cut' : 'compact' };
  }

  function buildMailto(subject, full, compact) {
    var to = recipient();
    var base = 'mailto:' + to + '?subject=' + enc(subject) + '&body=';
    var pick = pickBody(full, compact, base.length, mailtoLimit(), '\r\n');
    return { url: base + enc(pick.body.split('\n').join('\r\n')), tier: pick.tier };
  }

  var PROVIDERS = [
    { id: 'gmail', label: 'Gmail',
      build: function (to, su, body) { return 'https://mail.google.com/mail/?view=cm&fs=1&to=' + enc(to) + '&su=' + enc(su) + '&body=' + enc(body); } },
    { id: 'outlook', label: 'Outlook',
      build: function (to, su, body) { return 'https://outlook.live.com/mail/0/deeplink/compose?to=' + enc(to) + '&subject=' + enc(su) + '&body=' + enc(body); } },
    { id: 'yahoo', label: 'Yahoo Mail',
      build: function (to, su, body) { return 'https://compose.mail.yahoo.com/?to=' + enc(to) + '&subject=' + enc(su) + '&body=' + enc(body); } }
  ];

  function buildWebLinks(subject, full, compact) {
    var to = recipient();
    return PROVIDERS.map(function (p) {
      var base = p.build(to, subject, '');
      var pick = pickBody(full, compact, base.length, CONFIG.webComposeLimit, '\n');
      return { id: p.id, label: p.label, url: p.build(to, subject, pick.body), tier: pick.tier };
    });
  }

  function legacyCopy(text) {
    var ta = h('textarea', { 'aria-hidden': 'true', tabindex: '-1', style: 'position:fixed;top:0;left:0;opacity:0' });
    ta.value = text;
    document.body.appendChild(ta);
    ta.focus();
    ta.select();
    var ok = false;
    try { ok = document.execCommand('copy'); } catch (e) { ok = false; }
    document.body.removeChild(ta);
    return ok;
  }

  /* Resolves to true when the text reached the clipboard. */
  function copyText(text) {
    if (navigator.clipboard && window.isSecureContext) {
      return navigator.clipboard.writeText(text).then(function () { return true; }, function () { return legacyCopy(text); });
    }
    return Promise.resolve(legacyCopy(text));
  }

  function announce(message) {
    dom.live.textContent = '';
    window.setTimeout(function () { dom.live.textContent = message; }, 30);
  }

  /* ======================================================================= *
   * 10. The review step
   * ======================================================================= */

  function renderReview() {
    var headingId = 'h-review';
    var count = h('p', { class: 'step-count' });
    var heading = h('h2', { class: 'step-title', id: headingId, tabindex: '-1', text: REVIEW.title });
    dom.summary = h('p', { class: 'review-summary' });
    dom.reportBox = h('textarea', {
      class: 'field report', readonly: true, rows: '14', id: 'report-text', spellcheck: 'false',
      'aria-label': 'Your answers, exactly as they will be emailed'
    });
    dom.sendBtn = h('button', { type: 'button', class: 'btn primary big', id: 'btn-send', text: RELAY_ON ? 'Send my answers' : (PDF_ON ? 'Download PDF and email it' : 'Send by email'), onclick: RELAY_ON ? onRelaySend : onSend });
    dom.emailBtn = RELAY_ON ? h('button', { type: 'button', class: 'btn ghost', id: 'btn-email', text: 'Send it from my own email app instead', onclick: onSend }) : null;
    dom.pdfNote = h('p', { class: 'send-note', id: 'pdf-note', role: 'status', hidden: !PDF_ON });
    dom.relayNote = RELAY_ON ? h('p', { class: 'send-note', id: 'relay-note', role: 'status' }) : null;
    dom.sent = h('div', { class: 'sent', id: 'sent', hidden: true, tabindex: '-1', role: 'region', 'aria-labelledby': 'sent-title' });

    var intro = RELAY_ON ?
      'Pressing "Send my answers" sends your answers and a PDF copy of your questions and answers to the Dhar project over an encrypted connection. You do not need to open your email app. Nothing is sent until you press the button.' :
      (PDF_ON ?
        'Sending saves a PDF copy of your questions and answers on this device and opens your email app with a message already written and addressed to the Dhar project. Attach the PDF, then press Send there. Nothing is sent until you press Send.' :
        'Sending opens your email app with your answers already written and addressed to the Dhar project. Nothing is sent until you press Send there.');
    var sendRow = RELAY_ON ?
      h('div', { class: 'send-row' }, dom.sendBtn, dom.pdfNote,
        h('p', { class: 'send-note', text: 'The message passes through a small service on Google\'s servers that the project runs. It saves your answers in a private spreadsheet and emails them to Abdullahi Baba Garba. If you gave an email address, he can reply to it.' }),
        dom.relayNote,
        h('div', { class: 'send-alt' },
          h('p', { class: 'send-note', text: 'Prefer to send it yourself?' }), dom.emailBtn)) :
      h('div', { class: 'send-row' }, dom.sendBtn, dom.pdfNote,
        h('p', { class: 'send-note', text: 'Your email app opens with the message ready. If it does not, the options appear below.' }));

    var el = h('section', { class: 'step', id: 'step-review', hidden: true, 'aria-labelledby': headingId, 'data-step': 'review' },
      h('header', { class: 'step-head' }, count, heading, h('p', { class: 'step-intro', text: intro })),
      dom.summary,
      h('details', { class: 'preview' }, h('summary', { text: RELAY_ON ? 'Read exactly what will be sent' : 'Read exactly what will be emailed' }), dom.reportBox),
      sendRow,
      dom.sent);
    dom.step.review = { el: el, count: count, heading: heading, sec: REVIEW };
    return el;
  }

  /* ---- the PDF copy: loaded on demand, built when the review step opens ---------------- */

  var pdfCode = null;   /* promise for pdf-fonts.js + pdf.js, started at most once at a time */

  function loadScript(src) {
    return new Promise(function (resolve, reject) {
      var el = document.createElement('script');
      el.src = src;
      el.async = true;
      el.onload = function () { resolve(); };
      el.onerror = function () { reject(new Error('Could not load ' + src)); };
      document.head.appendChild(el);
    });
  }

  function loadPdfCode() {
    if (!pdfCode) {
      pdfCode = loadScript(ASSET_BASE + 'pdf-fonts.js')
        .then(function () { return loadScript(ASSET_BASE + 'pdf.js'); })
        .then(function () { if (!window.DharPdf || !window.DharPdf.supported()) { throw new Error('PDF not supported here'); } });
      pdfCode.catch(function () { pdfCode = null; });   /* a later attempt may succeed */
    }
    return pdfCode;
  }

  /* Once the respondent has started, fetch the PDF code quietly so the review step is instant. */
  function prefetchPdf() {
    if (PDF_ON && !pdfCode && typeof Promise !== 'undefined') { loadPdfCode().catch(function () { /* reported on the review step */ }); }
  }

  /* Labels and enabled state of the send buttons. Two modes:
       relay on   "Send my answers" (relay) plus "Send it from my own email app instead"
       relay off  one button that opens the email draft */
  function setSendState() {
    var p = dom.pdf;
    var busy = !!p && p.status === 'preparing';
    var label;
    if (dom.delivered) { label = 'Sent'; }
    else if (dom.sending) { label = 'Sending...'; }
    else if (busy) { label = 'Preparing your PDF...'; }
    else if (RELAY_ON) { label = 'Send my answers'; }
    else if (PDF_ON && p && p.status === 'ready') { label = 'Download PDF and email it'; }
    else { label = 'Send by email'; }
    dom.sendBtn.textContent = label;
    dom.sendBtn.disabled = !!(dom.delivered || dom.sending || busy);
    dom.sendBtn.setAttribute('aria-busy', dom.sending ? 'true' : 'false');
    if (dom.emailBtn) { dom.emailBtn.disabled = !!(dom.delivered || dom.sending || busy); }

    if (!PDF_ON || !p) { return; }
    if (p.status === 'preparing') {
      dom.pdfNote.textContent = 'Making the PDF copy of your answers on this device.';
    } else if (p.status === 'ready') {
      dom.pdfNote.textContent = 'PDF ready: ' + p.name + ' (' + Math.max(1, Math.round(p.size / 1024)) + ' KB).';
    } else {
      dom.pdfNote.textContent = RELAY_ON ?
        'The PDF could not be made on this device. Your answers will be sent as text without it.' :
        'The PDF could not be made on this device. Your email will carry your answers as text instead.';
    }
  }

  function setRelayNote(text) { if (dom.relayNote) { dom.relayNote.textContent = text || ''; } }

  /* The preview shows exactly what will be emailed, including whether it names a PDF copy. */
  function refreshPreview() {
    var named = PDF_ON && dom.pdf && dom.pdf.status !== 'failed';
    dom.reportBox.value = buildReport(false, dom.when, named ? dom.pdf.name : null).text;
  }

  function startPdf(report) {
    dom.pdfToken = (dom.pdfToken || 0) + 1;
    var token = dom.pdfToken, when = dom.when, name = pdfFileName(when);
    var mine = dom.pdf = { status: 'preparing', name: name };
    setSendState();

    function fail() {
      if (token !== dom.pdfToken || mine.status !== 'preparing') { return; }
      mine.status = 'failed';
      refreshPreview();
      setSendState();
    }
    window.setTimeout(fail, 20000);   /* a very slow connection must not block sending */

    loadPdfCode().then(function () {
      return window.DharPdf.build(pdfModel(report, when, name));
    }).then(function (bytes) {
      if (token !== dom.pdfToken || mine.status !== 'preparing') { return; }
      var blob = new Blob([bytes], { type: 'application/pdf' });
      var file = null;
      try { file = new File([blob], name, { type: 'application/pdf' }); } catch (e) { file = null; }
      mine.status = 'ready';
      mine.blob = blob;
      mine.bytes = bytes;
      mine.file = file;
      mine.size = bytes.length;
      setSendState();
    }).catch(fail);
  }

  function buildReview() {
    dom.when = new Date();
    dom.id = responseId(dom.when);
    dom.delivered = false;
    dom.sending = false;
    setRelayNote('');
    var report = buildReport(false, dom.when, PDF_ON ? pdfFileName(dom.when) : null);
    dom.summary.textContent = 'You answered ' + report.answered + ' questions. Roles: ' + (roleShortNames().join(', ') || 'none') + '.';
    dom.reportBox.value = report.text;
    dom.sent.hidden = true;
    if (PDF_ON && typeof Promise !== 'undefined') {
      startPdf(report);
    } else {
      dom.pdf = null;
      setSendState();
    }
  }

  /* Re-checks every visible required question. Used as a safety net before sending:
     returns the first step that still has a problem, or null. */
  function firstInvalidStep() {
    var list = steps();
    for (var i = 0; i < list.length - 1; i++) {
      var bad = visibleQuestions(list[i]).filter(function (q) { return problemWith(q) !== ''; });
      if (bad.length) { return { step: list[i], questions: bad }; }
    }
    return null;
  }

  function openMailto(url) {
    var a = h('a', { href: url, hidden: true });
    document.body.appendChild(a);
    a.click();
    document.body.removeChild(a);
  }

  /* Safety net before any send: if a required question still has a problem, go back to it.
     Returns true when everything is fine. */
  function readyToSend() {
    var invalid = firstInvalidStep();
    if (!invalid) { return true; }
    go(invalid.step.id, { quiet: true });
    validateStep(invalid.step);
    setNavError(invalid.questions.length);
    focusQuestion(invalid.questions[0]);
    return false;
  }

  /* The email-draft route: copy the text, save the PDF, open the respondent's email app. */
  function onSend() {
    if (!readyToSend()) { return; }
    var when = dom.when || new Date();
    var pdf = PDF_ON && dom.pdf && dom.pdf.status === 'ready' ? dom.pdf : null;
    var report = buildReport(false, when, pdf ? pdf.name : null);   /* complete wording: clipboard, download, preview */
    var compact = buildReport(true, when, pdf ? pdf.name : null);   /* same answers, shorter question wording */
    var subject = subjectLine();
    var mail = buildMailto(subject, report.text, compact.text);
    var links = buildWebLinks(subject, report.text, compact.text);

    /* Everything here runs inside the click, because browsers only allow these actions then:
       copy the full text, save the PDF, open the email app. */
    var copied = copyText(report.text);
    if (pdf && CONFIG.pdfAutoDownload !== false) { downloadPdf(pdf); }
    openMailto(mail.url);
    copied.then(function (ok) { showSent(report, subject, mail, links, ok, pdf); });
  }

  function downloadPdf(pdf) {
    var url = URL.createObjectURL(pdf.blob);
    var a = h('a', { href: url, download: pdf.name, hidden: true });
    document.body.appendChild(a);
    a.click();
    document.body.removeChild(a);
    window.setTimeout(function () { URL.revokeObjectURL(url); }, 60000);   /* some phones need the link alive for a while */
  }

  function canSharePdf(pdf) {
    try {
      return !!(pdf && pdf.file && typeof navigator.share === 'function' && navigator.canShare && navigator.canShare({ files: [pdf.file] }));
    } catch (e) { return false; }
  }

  /* The share sheet attaches the file for you, but it cannot choose the recipient, so the
     address is copied for pasting into the To box and also written at the top of the text. */
  function sharePdf(pdf, subject, report) {
    copyText(recipient());
    var data = { files: [pdf.file], title: subject, text: 'To: ' + recipient() + '\nSubject: ' + subject + '\n\n' + report.text };
    navigator.share(data).then(function () { announce('Shared.'); }, function (err) {
      if (!err || err.name !== 'AbortError') { announce('Sharing did not work. Download the PDF and attach it in your email app.'); }
    });
  }

  /* ---- direct delivery through the relay (relay/Code.gs) ------------------------------------ */

  function bytesToBase64(bytes) {
    var step = 0x8000, parts = [], i;
    for (i = 0; i < bytes.length; i += step) {
      parts.push(String.fromCharCode.apply(null, bytes.subarray ? bytes.subarray(i, i + step) : bytes.slice(i, i + step)));
    }
    return window.btoa(parts.join(''));
  }

  /* The request body. It is JSON sent as text/plain: that is a "simple" request, so the browser
     does not need a CORS pre-flight, which Apps Script web apps do not answer. */
  function relayBody(report, subject, pdf) {
    try {
      return JSON.stringify({
        v: RELAY_PROTOCOL,
        token: CONFIG.relayToken || '',
        id: dom.id,
        survey: SURVEY.version,
        subject: subject,
        text: report.text,
        replyTo: respondentEmail(),
        pdf: pdf && pdf.bytes ? { name: pdf.name, data: bytesToBase64(pdf.bytes) } : null
      });
    } catch (e) {
      return null;
    }
  }

  /* One attempt. Always resolves, never rejects, to one of:
       { kind: 'ok',          data }   the relay accepted it (data.ok === true)
       { kind: 'rejected',    data }   the relay answered, but said no (data.code says why)
       { kind: 'unreachable', why }    no usable answer: offline, timed out, blocked, or a reply this
                                       page is not allowed to read. The response may or may not have
                                       arrived, which is why the caller retries and then falls back. */
  function postToRelay(body) {
    var controller = typeof window.AbortController === 'function' ? new window.AbortController() : null;
    var timer = null;
    var timeout = new Promise(function (resolve) {
      timer = window.setTimeout(function () {
        if (controller) { controller.abort(); }
        resolve({ kind: 'unreachable', why: 'timeout' });
      }, CONFIG.relayTimeoutMs || 30000);
    });
    var attempt = window.fetch(RELAY_URL, {
      method: 'POST',
      headers: { 'Content-Type': 'text/plain;charset=utf-8' },
      body: body,
      redirect: 'follow',
      credentials: 'omit',
      cache: 'no-store',
      referrerPolicy: 'no-referrer',
      signal: controller ? controller.signal : undefined
    }).then(function (res) {
      return res.text().then(function (text) {
        var data = null;
        try { data = JSON.parse(text); } catch (e) { data = null; }
        if (data && typeof data === 'object' && typeof data.ok === 'boolean') {
          return { kind: data.ok ? 'ok' : 'rejected', data: data };
        }
        return { kind: 'rejected', data: { ok: false, code: 'bad-response', message: 'Unexpected reply (HTTP ' + res.status + ').' } };
      });
    }, function () {
      return { kind: 'unreachable', why: 'network' };
    });
    return Promise.race([attempt, timeout]).then(function (outcome) {
      window.clearTimeout(timer);
      return outcome;
    });
  }

  /* One retry after a network failure. Safe: the relay recognises the response ID and does not
     email the same response twice. */
  function sendToRelay(body) {
    return postToRelay(body).then(function (outcome) {
      if (outcome.kind !== 'unreachable') { return outcome; }
      setRelayNote('Still trying...');
      return new Promise(function (resolve) { window.setTimeout(resolve, 2000); }).then(function () { return postToRelay(body); });
    });
  }

  function forgetDraft() {
    discarded = true;
    window.clearTimeout(saveTimer);
    storageClear();
  }

  function onRelaySend() {
    if (dom.sending || dom.delivered || !readyToSend()) { return; }
    var when = dom.when || new Date();
    var pdf = PDF_ON && dom.pdf && dom.pdf.status === 'ready' ? dom.pdf : null;
    var report = buildReport(false, when, pdf ? pdf.name : null);
    var subject = subjectLine();
    var body = relayBody(report, subject, pdf);

    dom.sending = true;
    dom.sent.hidden = true;
    setSendState();
    setRelayNote('Sending your answers...');
    announce('Sending your answers.');

    var outcome = body ?
      sendToRelay(body) :
      Promise.resolve({ kind: 'rejected', data: { ok: false, code: 'client', message: 'This browser could not prepare the message.' } });
    outcome.then(function (result) {
      dom.sending = false;
      setRelayNote('');
      if (result.kind === 'ok') {
        dom.delivered = true;
        setSendState();
        forgetDraft();
        showRelayDelivered(result.data, report, pdf);
      } else {
        setSendState();
        showRelayFallback(result, report, subject, pdf);
      }
    });
  }

  /* ---- the confirmation panels --------------------------------------------------------------- */

  function openPanel(title) {
    var box = dom.sent;
    box.textContent = '';
    box.appendChild(h('h3', { class: 'sent-title', id: 'sent-title', text: title }));
    return box;
  }

  function revealPanel(box, message) {
    box.hidden = false;
    box.focus({ preventScroll: true });
    scrollToEl(box);
    announce(message);
  }

  function downloadReport(report) {
    var blob = new Blob([report.text.replace(/\n/g, '\r\n')], { type: 'text/plain;charset=utf-8' });
    var url = URL.createObjectURL(blob);
    var a = h('a', { href: url, download: 'dhar-survey-response-' + fileStamp(report.date) + '.txt', hidden: true });
    document.body.appendChild(a);
    a.click();
    document.body.removeChild(a);
    window.setTimeout(function () { URL.revokeObjectURL(url); }, 2000);
  }

  function copyButton(report) {
    return h('button', {
      type: 'button', class: 'btn ghost', text: 'Copy answers',
      onclick: function () { copyText(report.text).then(function (ok) { announce(ok ? 'Answers copied.' : 'Copy failed. Select the text in the box above and copy it.'); }); }
    });
  }

  function textFileButton(report) {
    return h('button', { type: 'button', class: 'btn ghost', text: 'Download as a text file', onclick: function () { downloadReport(report); } });
  }

  /* The note shown when the draft was shortened or cut for the email app's length limit. */
  function appendTierNote(box, mail, links, copiedOk) {
    if (mail.tier === 'compact') {
      box.appendChild(h('p', { class: 'note', text: 'The message is long, so your email app received your answers with the long question wording shortened. Every answer is included.' }));
    } else if (mail.tier === 'cut') {
      var roomy = links.filter(function (l) { return l.tier !== 'cut'; })[0];
      box.appendChild(h('p', { class: 'warn' }, h('strong', { text: 'Your email may be cut short. ' }),
        'Your email app can only take part of a long message, so it opened with the first part of your answers (contact details and basics come first). ' +
        (roomy ? 'The "Open ' + roomy.label + '" button below carries all your answers without any pasting. Otherwise ' : 'To send everything, ') +
        (copiedOk ?
          'the full set is on your clipboard: select everything in the message, paste, then send.' :
          'press "Copy answers" below, then select everything in the message, paste, and send.')));
    }
  }

  /* The buttons for the email route: PDF, share, copy, text file, webmail. */
  function emailActions(report, subject, links, pdf) {
    var actions = h('div', { class: 'actions' });
    var shareable = canSharePdf(pdf);
    if (pdf) {
      actions.appendChild(h('button', { type: 'button', class: 'btn ghost', text: 'Download the PDF', onclick: function () { downloadPdf(pdf); } }));
    }
    if (shareable) {
      actions.appendChild(h('button', { type: 'button', class: 'btn ghost', text: 'Share the PDF', onclick: function () { sharePdf(pdf, subject, report); } }));
    }
    actions.appendChild(copyButton(report));
    actions.appendChild(textFileButton(report));
    links.forEach(function (l) {
      actions.appendChild(h('a', { class: 'btn ghost', href: l.url, target: '_blank', rel: 'noopener', text: 'Open ' + l.label }));
    });
    return { el: actions, shareable: shareable };
  }

  function appendEmailFooter(box, subject, pdf, shareable) {
    if (shareable) {
      box.appendChild(h('p', { class: 'note', text: '"Share the PDF" attaches the file for you from your phone\'s share menu. It cannot fill in the address, so the address is copied for you to paste into the To box.' }));
    }
    box.appendChild(h('p', { class: 'sent-manual' }, 'Writing it yourself: to ', h('strong', { text: recipient() }),
      ', subject "' + subject + '", and paste your answers in the body' + (pdf ? ', then attach the PDF.' : '.')));
  }

  /* The email route, after the email app was asked to open. */
  function showSent(report, subject, mail, links, copiedOk, pdf) {
    var box = openPanel('Your email is ready');
    var steps = h('ol', { class: 'sent-steps' });
    if (pdf) {
      steps.appendChild(h('li', null,
        CONFIG.pdfAutoDownload !== false ? 'A PDF copy of your questions and answers was saved to this device as ' : 'Your PDF copy is ready: ',
        h('strong', { text: pdf.name }), '. If you cannot find it, use "Download the PDF" below.'));
      steps.appendChild(h('li', { text: 'In the email that opened, attach that PDF (look for the paperclip). The message also lists your answers as text, so nothing is lost if you cannot attach it.' }));
    } else {
      steps.appendChild(h('li', { text: 'Check the message in your email app. It should list your answers and end with "END OF RESPONSE".' }));
    }
    steps.appendChild(h('li', { text: 'Press Send in your email app. Until you do, nothing has been sent.' }));
    box.appendChild(steps);
    appendTierNote(box, mail, links, copiedOk);

    var acts = emailActions(report, subject, links, pdf);
    box.appendChild(h('p', { class: 'sent-lead', text: 'Nothing opened, or you use webmail? Pick another way:' }));
    box.appendChild(acts.el);
    appendEmailFooter(box, subject, pdf, acts.shareable);

    box.appendChild(h('div', { class: 'sent-done' },
      h('p', { text: 'Thank you. Your answers help decide what gets built and how it is taught.' }),
      h('button', {
        type: 'button', class: 'btn ghost', text: 'I have sent it. Clear my answers from this device',
        onclick: discard
      })));

    revealPanel(box, copiedOk ? 'Your email is ready. Your answers are also copied.' : 'Your email is ready.');
  }

  /* The relay accepted the response. */
  function showRelayDelivered(data, report, pdf) {
    var box = openPanel('Your answers were sent');
    var emailed = data.delivered !== 'stored';
    var sentPdf = !!pdf && emailed && data.attached !== false;
    box.appendChild(h('p', { text: emailed ?
      'Your answers' + (sentPdf ? ' and a PDF copy' : '') + ' were sent to the Dhar project.' :
      'Your answers were received and saved by the Dhar project.' }));
    if (data.duplicate) {
      box.appendChild(h('p', { class: 'note', text: 'This response had already arrived, so it was not sent a second time.' }));
    } else if (pdf && emailed && data.attached === false) {
      box.appendChild(h('p', { class: 'note', text: 'The PDF copy could not be attached, but all your answers are in the message.' }));
    }
    box.appendChild(h('p', { class: 'sent-manual' }, 'Reference: ', h('strong', { text: dom.id }), '. Quote it if you write to the project about this response.'));
    box.appendChild(h('p', { class: 'sent-manual', text: 'Your unfinished answers were removed from this device. The copy below is only what this page is showing now.' }));

    var actions = h('div', { class: 'actions' });
    if (pdf) { actions.appendChild(h('button', { type: 'button', class: 'btn ghost', text: 'Download my copy (PDF)', onclick: function () { downloadPdf(pdf); } })); }
    actions.appendChild(copyButton(report));
    actions.appendChild(textFileButton(report));
    box.appendChild(h('p', { class: 'sent-lead', text: 'Keep a copy for yourself if you like:' }));
    box.appendChild(actions);

    box.appendChild(h('div', { class: 'sent-done' },
      h('p', { text: 'Thank you. Your answers help decide what gets built and how it is taught.' }),
      h('button', { type: 'button', class: 'btn ghost', text: 'Start a blank survey', onclick: discard })));

    revealPanel(box, 'Your answers were sent.');
  }

  /* The relay could not take the response (or its answer could not be read). Offer the email
     route, which always works, and a retry. */
  function showRelayFallback(outcome, report, subject, pdf) {
    var compact = buildReport(true, dom.when || new Date(), pdf ? pdf.name : null);
    var mail = buildMailto(subject, report.text, compact.text);
    var links = buildWebLinks(subject, report.text, compact.text);
    var data = outcome.data || {};
    var title, lead, canRetry;
    if (outcome.kind === 'unreachable') {
      title = 'We could not confirm that your answers arrived';
      lead = 'Your connection may have dropped, or the sending service did not answer. Your answers may have arrived anyway. To be certain, send them by email as well. If both arrive, that is fine: this response has the reference ' + dom.id + ' and duplicates are recognised.';
      canRetry = true;
    } else if (data.code === 'busy' || data.code === 'too-many' || data.code === 'quota' || data.code === 'server') {
      title = 'Your answers have not been sent yet';
      lead = 'The sending service is busy or at its limit right now. You can try again in a moment, or send your answers by email instead. Your answers are still on this page.';
      canRetry = true;
    } else {
      title = 'Your answers have not been sent yet';
      lead = 'The sending service did not accept this response' + (data.code ? ' (' + data.code + ')' : '') + '. Please send your answers by email instead. Your answers are still on this page.';
      canRetry = false;
    }

    var box = openPanel(title);
    box.appendChild(h('p', { class: 'warn', text: lead }));
    var steps = h('ol', { class: 'sent-steps' });
    steps.appendChild(h('li', { text: 'Press "Open my email app". It opens a message already addressed to the Dhar project with your answers written in it' + (pdf && CONFIG.pdfAutoDownload !== false ? ', and saves a PDF copy to this device.' : '.') }));
    if (pdf) {
      steps.appendChild(h('li', { text: 'Attach the PDF to that email (look for the paperclip). The message also lists your answers as text, so nothing is lost if you cannot attach it.' }));
    }
    steps.appendChild(h('li', { text: 'Press Send in your email app. Until you do, nothing has been sent by email.' }));
    box.appendChild(steps);

    var main = h('div', { class: 'actions' });
    main.appendChild(h('a', {
      class: 'btn primary', href: mail.url, text: 'Open my email app',
      onclick: function () {
        copyText(report.text);
        if (pdf && CONFIG.pdfAutoDownload !== false) { downloadPdf(pdf); }
      }
    }));
    if (canRetry) {
      main.appendChild(h('button', { type: 'button', class: 'btn ghost', text: 'Try sending again', onclick: function () { dom.sent.hidden = true; onRelaySend(); } }));
    }
    box.appendChild(main);
    appendTierNote(box, mail, links, false);

    var acts = emailActions(report, subject, links, pdf);
    box.appendChild(h('p', { class: 'sent-lead', text: 'Or pick another way:' }));
    box.appendChild(acts.el);
    appendEmailFooter(box, subject, pdf, acts.shareable);

    revealPanel(box, title + '. Email options are shown below.');
  }

  /* ======================================================================= *
   * 11. Saving and restoring (this device only)
   * ======================================================================= */

  var saveTimer = null;
  var discarded = false;   /* set while the draft is being thrown away, so unloading the page cannot save it again */

  function save() {
    window.clearTimeout(saveTimer);
    saveTimer = window.setTimeout(saveNow, 250);
  }

  /* "Start over" and "I have sent it": forget the draft and reload a blank survey. */
  function discard() {
    forgetDraft();
    window.location.reload();
  }

  function saveNow() {
    window.clearTimeout(saveTimer);
    if (discarded) { return; }
    storageSet(JSON.stringify({ v: SURVEY.version, answers: state.answers, stepId: state.stepId, at: Date.now() }));
  }

  /* Returns true when a saved draft with at least one answer was restored. */
  function restore() {
    var raw = storageGet();
    if (!raw) { return false; }
    var data;
    try { data = JSON.parse(raw); } catch (e) { return false; }
    if (!data || data.v !== SURVEY.version || !data.answers || typeof data.answers !== 'object') { return false; }
    var known = {};
    allQuestions().forEach(function (q) { known[q.code] = true; known[q.code + '#other'] = true; });
    var kept = 0;
    Object.keys(data.answers).forEach(function (k) {
      if (known[k]) { state.answers[k] = data.answers[k]; kept += 1; }
    });
    if (typeof data.stepId === 'string') { state.stepId = data.stepId; }
    return kept > 0;
  }

  /* ======================================================================= *
   * 12. Start-up
   * ======================================================================= */

  /* The wording on the start page and in the footer says how answers travel, so it must match
     the mode in config.js. index.html carries the email-route wording (also what shows without
     JavaScript); with the relay on, this replaces it. */
  function applyDeliveryText() {
    if (!RELAY_ON) { return; }
    var privacy = document.getElementById('privacy');
    var foot = document.getElementById('foot-note');
    if (privacy) {
      privacy.textContent = 'When you finish and press Send, your answers and a PDF copy of them are sent over an encrypted connection to a small service on Google\'s servers that the project runs, and it saves them in a private Google Sheet and emails them to Abdullahi Baba Garba, who leads the project. He sees only what you type, and your email address only if you give it. Nothing is sent before you press Send, and unfinished answers stay on this device. If you would rather send them yourself, an email option sits next to the Send button. Answers are never published with your name. This page loads nothing from other sites.';
    }
    if (foot) {
      foot.textContent = 'Answers are sent only when you press Send. Unfinished answers stay on your device.';
    }
  }

  function init() {
    mount.textContent = '';

    dom.bar = document.getElementById('temper');
    dom.live = document.getElementById('live');
    dom.stage = document.getElementById('stage') || mount;

    var form = h('form', { class: 'survey-form', novalidate: true, autocomplete: 'on' });
    SURVEY.sections.forEach(function (sec) { form.appendChild(renderSection(sec)); });
    form.appendChild(renderReview());

    dom.navErr = h('p', { class: 'nav-err', role: 'alert', hidden: true });
    dom.back = h('button', { type: 'button', class: 'btn ghost', text: 'Back', onclick: onBack });
    dom.next = h('button', { type: 'submit', class: 'btn primary', text: 'Next' });
    form.appendChild(dom.navErr);
    form.appendChild(h('div', { class: 'nav' }, dom.back, dom.next));
    form.addEventListener('submit', function (e) { e.preventDefault(); onNext(); });
    mount.appendChild(form);

    applyDeliveryText();
    var restored = restore();
    syncAll();
    if (restored) {
      var note = document.getElementById('restored');
      if (note) {
        note.hidden = false;
        var restart = document.getElementById('restart');
        if (restart) { restart.addEventListener('click', discard); }
      }
    }
    if (state.stepId === 'review') { buildReview(); }
    refresh();

    window.addEventListener('pagehide', saveNow);
    document.addEventListener('visibilitychange', function () { if (document.visibilityState === 'hidden') { saveNow(); } });
    document.documentElement.setAttribute('data-ready', 'true');
  }

  init();
})();
