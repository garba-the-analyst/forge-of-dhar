/*
 * pdf.js: writes the PDF copy of a survey response. No libraries, no network.
 *
 *   DharPdf.build(model)  ->  Promise<Uint8Array>   the bytes of a PDF file
 *   DharPdf.supported()   ->  boolean                false on browsers too old to build it
 *
 * It needs assets/pdf-fonts.js (window.DHAR_PDF_FONTS) to be loaded first. survey.js loads
 * both files when the respondent reaches the review step and falls back to a text-only email
 * if anything here fails, so a problem in this file can never stop a response being sent.
 *
 * THE MODEL (built by survey.js, see pdfModel() there)
 *   {
 *     title, subtitle,                       heading block on page 1
 *     meta: [[label, value], ...],           small table under the heading
 *     sections: [{ title, questions: [Q] }],
 *     footer,                                text at the foot of every page, left
 *     created: Date,                         goes in the PDF's own metadata
 *     note                                   optional line at the very end
 *   }
 *   Q = { code, text, hint, kind, ...}  where kind is one of
 *     'none'                               not answered
 *     'text'    value                      one choice, or typed text (line breaks kept)
 *     'list'    items[]                    several choices
 *     'scale'   value, max, legend         a 1-5 or 0-10 answer
 *     'grid'    legend, rows[{label,value}]  a grid of 1-5 ratings (value null = not rated)
 *
 * HOW THE FILE IS BUILT
 *   - A4 pages, text laid out and wrapped here using real glyph widths from the fonts.
 *   - Fonts are embedded as TrueType (Identity-H), so any character the fonts have is shown
 *     and the text stays selectable and searchable (a ToUnicode map is written for each font).
 *   - Text is normalised (NFC) first so letters such as e with a dot below are single glyphs.
 *   - A character that no font has is drawn as "?" and the PDF says so on its last page.
 *   - Page content and fonts are deflate-compressed when the browser has CompressionStream.
 *   - The file is standard PDF 1.7, checked with qpdf, pypdf and poppler in tests/.
 */
(function (global) {
  'use strict';

  /* ---- page geometry (points; 1 pt = 1/72 inch) ----------------------------------- */
  var PAGE_W = 595.28, PAGE_H = 841.89;
  var MARGIN_X = 54, MARGIN_TOP = 64, MARGIN_BOTTOM = 68;
  var CONTENT_W = PAGE_W - 2 * MARGIN_X;
  var GUTTER = 38;                       /* column for the question code */
  var TEXT_X = MARGIN_X + GUTTER;
  var TEXT_W = CONTENT_W - GUTTER;

  /* ---- look ------------------------------------------------------------------------ */
  var INK = [0.09, 0.11, 0.14];
  var GREY = [0.39, 0.42, 0.46];
  var RULE = [0.80, 0.82, 0.85];
  var TEMPER = [[0.831, 0.671, 0.271], [0.678, 0.404, 0.149], [0.424, 0.275, 0.647], [0.165, 0.353, 0.651]];

  var SIZE = { title: 25, subtitle: 11, heading: 13, question: 10.5, hint: 8.8, answer: 9.8, meta: 9.6, small: 8 };
  var LEAD = { title: 30, subtitle: 15, heading: 18, question: 14.4, hint: 12, answer: 13.8, meta: 14.5, small: 11 };

  /* Which faces a kind of text prefers, in order. The first one that has the character wins. */
  var STYLE = {
    title:   ['archivoBold', 'dejavu'],
    bold:    ['archivoBold', 'dejavu'],
    brand:   ['archivo', 'dejavu'],
    answer:  ['dejavu', 'archivo']
  };
  var ALIAS = { archivo: 'F1', archivoBold: 'F2', dejavu: 'F3' };
  var SUBSET_TAG = { archivo: 'DHARAA', archivoBold: 'DHARAB', dejavu: 'DHARAC' };

  /* ---- small helpers --------------------------------------------------------------- */
  function num(n) {
    var s = (Math.round(n * 100) / 100).toFixed(2);
    return s.replace(/\.?0+$/, '') || '0';
  }
  function toBytes(str) {
    var a = new Uint8Array(str.length);
    for (var i = 0; i < str.length; i++) { a[i] = str.charCodeAt(i) & 0xFF; }
    return a;
  }
  function concat(chunks) {
    var total = 0, i;
    for (i = 0; i < chunks.length; i++) { total += chunks[i].length; }
    var out = new Uint8Array(total), at = 0;
    for (i = 0; i < chunks.length; i++) { out.set(chunks[i], at); at += chunks[i].length; }
    return out;
  }
  function hex(n, digits) {
    var s = n.toString(16).toUpperCase();
    while (s.length < digits) { s = '0' + s; }
    return s;
  }
  function pdfString(s) {                 /* a (literal string); only plain ASCII goes in here */
    return '(' + String(s).replace(/[^\x20-\x7E]/g, '?').replace(/([\\()])/g, '\\$1') + ')';
  }
  function base64ToBytes(b64) {
    var bin = global.atob(b64), out = new Uint8Array(bin.length);
    for (var i = 0; i < bin.length; i++) { out[i] = bin.charCodeAt(i); }
    return out;
  }
  function pad(n, w) { var s = String(n); while (s.length < w) { s = '0' + s; } return s; }

  function deflate(bytes) {               /* resolves to compressed bytes, or null when unavailable */
    if (typeof global.CompressionStream === 'undefined' || typeof global.Response === 'undefined') { return Promise.resolve(null); }
    try {
      var cs = new global.CompressionStream('deflate');   /* "deflate" is the zlib format PDF calls FlateDecode */
      var writer = cs.writable.getWriter();
      writer.write(bytes);
      writer.close();
      return new global.Response(cs.readable).arrayBuffer().then(function (buf) { return new Uint8Array(buf); }, function () { return null; });
    } catch (e) {
      return Promise.resolve(null);
    }
  }

  /* ---- fonts and text shaping ------------------------------------------------------ */

  function Face(key, data) {
    this.key = key;
    this.data = data;
    this.alias = ALIAS[key];
    this.used = {};                       /* glyph id -> code point, for the width table and ToUnicode */
  }
  Face.prototype.glyph = function (cp) {
    var g = this.data.cmap[cp];
    return g === undefined ? -1 : g;
  };
  Face.prototype.advance = function (gid) {            /* in 1/1000 of the font size */
    return this.data.adv[gid] * 1000 / this.data.upm;
  };

  /* Turns text into drawable items {face, gid, cp, adv}. Marks doc.lost when a character is missing. */
  function shape(doc, text, style) {
    var s = String(text == null ? '' : text);
    if (s.normalize) { s = s.normalize('NFC'); }
    s = s.replace(/[\u2028\u2029]/g, '\n').replace(/\t/g, '    ')
      .replace(/[\u0000-\u0008\u000B\u000C\u000E-\u001F\u007F\u200B-\u200F\u202A-\u202E\u2060\uFEFF]/g, '');
    var prefer = STYLE[style], items = [];
    var chars = Array.from ? Array.from(s) : s.split('');
    for (var i = 0; i < chars.length; i++) {
      var ch = chars[i];
      if (ch === '\r') { continue; }
      var cp = ch.codePointAt ? ch.codePointAt(0) : ch.charCodeAt(0);
      if (cp === 10) { items.push({ nl: true }); continue; }
      var face = null, gid = -1;
      for (var f = 0; f < prefer.length; f++) {
        var cand = doc.faces[prefer[f]];
        var g = cand.glyph(cp);
        if (g >= 0) { face = cand; gid = g; break; }
      }
      if (!face) {                         /* nothing has it: draw "?" and remember to say so */
        doc.lost = true;
        face = doc.faces[prefer[0]]; cp = 63; gid = face.glyph(63);
      }
      items.push({ face: face, gid: gid, cp: cp, adv: face.advance(gid) });
    }
    return items;
  }

  /* Breaks items into lines no wider than `width` points. Explicit line breaks are kept. */
  function wrap(items, size, width) {
    var paragraphs = [[]], i;
    for (i = 0; i < items.length; i++) {
      if (items[i].nl) { paragraphs.push([]); } else { paragraphs[paragraphs.length - 1].push(items[i]); }
    }
    var lines = [];
    paragraphs.forEach(function (para) {
      if (!para.length) { lines.push({ items: [], width: 0, blank: true }); return; }
      var line = [], lineW = 0, k = 0, n = para.length;
      function w(it) { return it.adv * size / 1000; }
      function push() { lines.push({ items: line, width: lineW }); line = []; lineW = 0; }
      while (k < n) {
        var spaces = [], spaceW = 0, word = [], wordW = 0;
        while (k < n && (para[k].cp === 32)) { spaces.push(para[k]); spaceW += w(para[k]); k++; }
        while (k < n && para[k].cp !== 32) { word.push(para[k]); wordW += w(para[k]); k++; }
        if (!word.length) { break; }       /* trailing spaces */
        if (line.length && lineW + spaceW + wordW > width) { push(); }
        if (!line.length) { spaces = []; spaceW = 0; }
        if (wordW > width) {               /* a single word wider than the line (a long link): break it by character */
          for (var c = 0; c < word.length; c++) {
            var cw = w(word[c]);
            if (line.length && lineW + cw > width) { push(); }
            line.push(word[c]); lineW += cw;
          }
        } else {
          line = line.concat(spaces, word); lineW += spaceW + wordW;
        }
      }
      if (line.length) { push(); }
    });
    return lines;
  }

  function widthOf(items, size) {
    var t = 0;
    for (var i = 0; i < items.length; i++) { t += items[i].adv * size / 1000; }
    return t;
  }

  /* ---- the document being laid out ------------------------------------------------- */

  function Doc(fontData) {
    this.faces = {};
    this.lost = false;
    for (var key in ALIAS) { if (Object.prototype.hasOwnProperty.call(ALIAS, key)) { this.faces[key] = new Face(key, fontData[key]); } }
    this.pages = [];
    this.page = null;
    this.y = 0;
    this.newPage();
  }
  Doc.prototype.newPage = function () {
    this.page = { ops: [] };
    this.pages.push(this.page);
    this.y = MARGIN_TOP;
  };
  Doc.prototype.room = function () { return PAGE_H - MARGIN_BOTTOM - this.y; };
  Doc.prototype.ensure = function (h) { if (h > this.room()) { this.newPage(); } };

  Doc.prototype.rect = function (x, yTop, w, h, color) {
    this.page.ops.push(num(color[0]) + ' ' + num(color[1]) + ' ' + num(color[2]) + ' rg ' +
      num(x) + ' ' + num(PAGE_H - yTop - h) + ' ' + num(w) + ' ' + num(h) + ' re f');
  };

  /* Draws one line of items with its text baseline at `baseline` (measured from the top). */
  Doc.prototype.line = function (items, x, baseline, size, color, page) {
    var ops = (page || this.page).ops, seg = [], face = null, sx = x, cur = x, i;
    function flush() {
      if (!seg.length) { return; }
      ops.push('q ' + num(color[0]) + ' ' + num(color[1]) + ' ' + num(color[2]) + ' rg BT /' + face.alias + ' ' + num(size) +
        ' Tf 1 0 0 1 ' + num(sx) + ' ' + num(PAGE_H - baseline) + ' Tm <' + seg.join('') + '> Tj ET Q');
      seg = [];
    }
    for (i = 0; i < items.length; i++) {
      var it = items[i];
      if (it.face !== face) { flush(); face = it.face; sx = cur; }
      seg.push(hex(it.gid, 4));
      it.face.used[it.gid] = it.cp;
      cur += it.adv * size / 1000;
    }
    flush();
  };

  /* A row is {h, draw(doc, yTop)}; blocks of rows are placed top to bottom, across pages. */
  function baselineFor(yTop, lead, size) { return yTop + (lead - size) / 2 + size * 0.8; }

  function textRows(doc, text, style, sizeKey, x, width, color) {
    var size = SIZE[sizeKey], lead = LEAD[sizeKey];
    return wrap(shape(doc, text, style), size, width).map(function (ln) {
      if (ln.blank) { return { h: lead * 0.55, draw: function () {} }; }
      return { h: lead, draw: function (d, y) { d.line(ln.items, x, baselineFor(y, lead, size), size, color); } };
    });
  }

  function gap(h) { return { h: h, draw: function () {} }; }

  Doc.prototype.place = function (rows, keepTogether) {
    var total = 0, lead = 0, i;
    for (i = 0; i < rows.length; i++) { total += rows[i].h; if (i < 3) { lead += rows[i].h; } }
    var usable = PAGE_H - MARGIN_BOTTOM - MARGIN_TOP;
    this.ensure(keepTogether && total <= usable ? total : lead);
    for (i = 0; i < rows.length; i++) {
      this.ensure(rows[i].h);
      rows[i].draw(this, this.y);
      this.y += rows[i].h;
    }
  };

  /* ---- content ---------------------------------------------------------------------- */

  function answerRows(doc, q) {
    var rows = [], size = SIZE.answer;
    switch (q.kind) {
      case 'text':
        return textRows(doc, q.value, 'answer', 'answer', TEXT_X, TEXT_W, INK);
      case 'list':
        q.items.forEach(function (item) {
          var lines = wrap(shape(doc, item, 'answer'), size, TEXT_W - 12);
          var bullet = shape(doc, '\u2022', 'brand');
          lines.forEach(function (ln, i) {
            rows.push({ h: LEAD.answer, draw: function (d, y) {
              if (i === 0) { d.line(bullet, TEXT_X + 2, baselineFor(y, LEAD.answer, size), size, GREY); }
              d.line(ln.items, TEXT_X + 12, baselineFor(y, LEAD.answer, size), size, INK);
            } });
          });
        });
        return rows;
      case 'scale':
        var value = shape(doc, q.value + ' of ' + q.max, 'bold');
        rows.push({ h: LEAD.question, draw: function (d, y) { d.line(value, TEXT_X, baselineFor(y, LEAD.question, SIZE.question), SIZE.question, INK); } });
        if (q.legend) { rows = rows.concat(textRows(doc, '(' + q.legend + ')', 'brand', 'hint', TEXT_X, TEXT_W, GREY)); }
        return rows;
      case 'grid':
        if (q.legend) { rows = rows.concat(textRows(doc, '(' + q.legend + ')', 'brand', 'hint', TEXT_X, TEXT_W, GREY)); rows.push(gap(3)); }
        q.rows.forEach(function (r) {
          var lines = wrap(shape(doc, r.label, 'answer'), size, TEXT_W - 70);
          var val = shape(doc, r.value === null || r.value === undefined ? 'not rated' : r.value + ' of 5', r.value === null || r.value === undefined ? 'brand' : 'bold');
          var vsize = r.value === null || r.value === undefined ? SIZE.hint : size;
          lines.forEach(function (ln, i) {
            rows.push({ h: LEAD.answer, draw: function (d, y) {
              var base = baselineFor(y, LEAD.answer, size);
              d.line(ln.items, TEXT_X, base, size, INK);
              if (i === 0) {
                d.line(val, TEXT_X + TEXT_W - widthOf(val, vsize), base, vsize, r.value === null || r.value === undefined ? GREY : INK);
                if (lines.length === 1) { return; }
              }
            } });
          });
          rows.push(gap(2.5));
        });
        return rows;
      default:                              /* 'none' */
        return textRows(doc, '(not answered)', 'brand', 'answer', TEXT_X, TEXT_W, GREY);
    }
  }

  function questionRows(doc, q) {
    var rows = [], size = SIZE.question;
    var qLines = wrap(shape(doc, q.text, 'bold'), size, TEXT_W);
    var code = shape(doc, q.code, 'bold');
    qLines.forEach(function (ln, i) {
      rows.push({ h: LEAD.question, draw: function (d, y) {
        var base = baselineFor(y, LEAD.question, size);
        if (i === 0) { d.line(code, MARGIN_X, base, SIZE.hint, GREY); }
        d.line(ln.items, TEXT_X, base, size, INK);
      } });
    });
    if (q.hint) { rows = rows.concat(textRows(doc, q.hint, 'brand', 'hint', TEXT_X, TEXT_W, GREY)); }
    rows.push(gap(3));
    rows = rows.concat(answerRows(doc, q));
    rows.push(gap(11));
    return rows;
  }

  function heading(doc, title, index) {
    doc.ensure(18 + 22 + 90);                /* a heading never sits alone at the foot of a page */
    if (doc.y > MARGIN_TOP + 1) { doc.y += 12; }
    var color = TEMPER[index % TEMPER.length], size = SIZE.heading;
    var items = shape(doc, title, 'bold');
    doc.rect(MARGIN_X, doc.y + 1, 4, LEAD.heading, color);
    doc.line(items, MARGIN_X + 12, baselineFor(doc.y, LEAD.heading, size) + 1, size, INK);
    doc.y += LEAD.heading + 12;
  }

  function titleBlock(doc, model) {
    var x = MARGIN_X;
    for (var i = 0; i < TEMPER.length; i++) { doc.rect(x + i * 30, MARGIN_TOP - 38, 26, 5, TEMPER[i]); }
    var title = wrap(shape(doc, model.title, 'title'), SIZE.title, CONTENT_W);
    title.forEach(function (ln) {
      doc.line(ln.items, MARGIN_X, baselineFor(doc.y, LEAD.title, SIZE.title), SIZE.title, INK);
      doc.y += LEAD.title;
    });
    if (model.subtitle) {
      doc.place(textRows(doc, model.subtitle, 'brand', 'subtitle', MARGIN_X, CONTENT_W, GREY));
    }
    doc.y += 8;
    doc.rect(MARGIN_X, doc.y, CONTENT_W, 0.6, RULE);
    doc.y += 10;
    (model.meta || []).forEach(function (pair) {
      var label = shape(doc, pair[0], 'brand');
      var rows = textRows(doc, pair[1], 'brand', 'meta', MARGIN_X + 104, CONTENT_W - 104, INK);
      rows.forEach(function (r, i) {
        var inner = r.draw;
        if (i === 0) {
          r.draw = function (d, y) {
            d.line(label, MARGIN_X, baselineFor(y, LEAD.meta, SIZE.meta), SIZE.meta, GREY);
            inner(d, y);
          };
        }
      });
      doc.place(rows, true);
    });
    doc.y += 4;
    doc.rect(MARGIN_X, doc.y, CONTENT_W, 0.6, RULE);
    doc.y += 8;
  }

  function layout(model, fontData) {
    var doc = new Doc(fontData);
    titleBlock(doc, model);
    (model.sections || []).forEach(function (sec, si) {
      heading(doc, sec.title, si);
      sec.questions.forEach(function (q) { doc.place(questionRows(doc, q), true); });
    });
    var notes = [];
    if (model.note) { notes.push(model.note); }
    if (doc.lost) { notes.push('Some characters in the answers could not be shown in this PDF and appear as "?". The email text has them exactly as typed.'); }
    notes.forEach(function (n) {
      doc.y += 4;
      doc.place(textRows(doc, n, 'brand', 'hint', MARGIN_X, CONTENT_W, GREY), true);
    });

    /* Footer on every page, now that the page count is known. */
    var count = doc.pages.length;
    doc.pages.forEach(function (page, i) {
      var left = shape(doc, model.footer || '', 'brand');
      var right = shape(doc, 'Page ' + (i + 1) + ' of ' + count, 'brand');
      doc.page = page;
      doc.rect(MARGIN_X, PAGE_H - 50, CONTENT_W, 0.5, RULE);
      doc.line(left, MARGIN_X, PAGE_H - 36, SIZE.small, GREY, page);
      doc.line(right, MARGIN_X + CONTENT_W - widthOf(right, SIZE.small), PAGE_H - 36, SIZE.small, GREY, page);
    });
    return doc;
  }

  /* ---- writing the file -------------------------------------------------------------- */

  function widthTable(face) {
    var gids = Object.keys(face.used).map(Number).sort(function (a, b) { return a - b; });
    var parts = [], i = 0;
    while (i < gids.length) {
      var start = gids[i], run = [Math.round(face.advance(gids[i]))];
      while (i + 1 < gids.length && gids[i + 1] === gids[i] + 1) { i++; run.push(Math.round(face.advance(gids[i]))); }
      parts.push(start + ' [' + run.join(' ') + ']');
      i++;
    }
    return '[' + parts.join(' ') + ']';
  }

  function toUnicodeCMap(face) {
    var gids = Object.keys(face.used).map(Number).sort(function (a, b) { return a - b; });
    var out = ['/CIDInit /ProcSet findresource begin', '12 dict begin', 'begincmap',
      '/CIDSystemInfo << /Registry (Adobe) /Ordering (UCS) /Supplement 0 >> def', '/CMapName /Adobe-Identity-UCS def',
      '/CMapType 2 def', '1 begincodespacerange', '<0000> <FFFF>', 'endcodespacerange'];
    for (var i = 0; i < gids.length; i += 100) {
      var chunk = gids.slice(i, i + 100);
      out.push(chunk.length + ' beginbfchar');
      chunk.forEach(function (g) {
        var cp = face.used[g], u;
        if (cp > 0xFFFF) {
          var c = cp - 0x10000;
          u = hex(0xD800 + (c >> 10), 4) + hex(0xDC00 + (c & 0x3FF), 4);
        } else { u = hex(cp, 4); }
        out.push('<' + hex(g, 4) + '> <' + u + '>');
      });
      out.push('endbfchar');
    }
    out.push('endcmap', 'CMapName currentdict /CMap defineresource pop', 'end', 'end');
    return toBytes(out.join('\n'));
  }

  function pdfDate(d) {
    var off = -d.getTimezoneOffset(), sign = off >= 0 ? '+' : '-';
    off = Math.abs(off);
    return 'D:' + d.getFullYear() + pad(d.getMonth() + 1, 2) + pad(d.getDate(), 2) + pad(d.getHours(), 2) +
      pad(d.getMinutes(), 2) + pad(d.getSeconds(), 2) + sign + pad(Math.floor(off / 60), 2) + "'" + pad(off % 60, 2) + "'";
  }

  function randomHex(bytes) {
    var a = new Uint8Array(bytes), s = '', i;
    if (global.crypto && global.crypto.getRandomValues) { global.crypto.getRandomValues(a); }
    else { for (i = 0; i < bytes; i++) { a[i] = Math.floor(Math.random() * 256); } }
    for (i = 0; i < bytes; i++) { s += hex(a[i], 2); }
    return s;
  }

  function streamObject(extra, raw, packed) {
    var data = packed || raw;
    var dict = '<< /Length ' + data.length + (packed ? ' /Filter /FlateDecode' : '') + (extra ? ' ' + extra : '') + ' >>\nstream\n';
    return concat([toBytes(dict), data, toBytes('\nendstream')]);
  }

  function assemble(doc, model, packedMap) {
    var objects = [];                        /* index = id - 1 */
    var order = ['archivo', 'archivoBold', 'dejavu'].filter(function (k) { return Object.keys(doc.faces[k].used).length > 0; });
    var next = 4, fontIds = {}, pageIds = [], i;
    order.forEach(function (k) { fontIds[k] = next; next += 5; });
    doc.pages.forEach(function () { pageIds.push(next); next += 2; });

    function put(id, bytes) { objects[id - 1] = typeof bytes === 'string' ? toBytes(bytes) : bytes; }

    put(1, '<< /Type /Catalog /Pages 2 0 R /Lang (en) /ViewerPreferences << /DisplayDocTitle true >> >>');
    put(2, '<< /Type /Pages /Count ' + pageIds.length + ' /Kids [' + pageIds.map(function (id) { return id + ' 0 R'; }).join(' ') + '] >>');
    put(3, '<< /Title ' + pdfString(model.title + ' response') + ' /Creator ' + pdfString('Shaping Dhar survey page') +
      ' /Producer ' + pdfString('Dhar survey pdf.js') + ' /CreationDate ' + pdfString(pdfDate(model.created || new Date())) + ' >>');

    order.forEach(function (k) {
      var face = doc.faces[k], d = face.data, id = fontIds[k];
      var base = SUBSET_TAG[k] + '+' + d.ps;
      var scale = 1000 / d.upm;
      var ttf = base64ToBytes(d.ttf);
      var unicodeMap = toUnicodeCMap(face);
      put(id, '<< /Type /Font /Subtype /Type0 /BaseFont /' + base + ' /Encoding /Identity-H /DescendantFonts [' + (id + 1) + ' 0 R] /ToUnicode ' + (id + 4) + ' 0 R >>');
      put(id + 1, '<< /Type /Font /Subtype /CIDFontType2 /BaseFont /' + base + ' /CIDSystemInfo << /Registry (Adobe) /Ordering (Identity) /Supplement 0 >> /FontDescriptor ' +
        (id + 2) + ' 0 R /DW 1000 /W ' + widthTable(face) + ' /CIDToGIDMap /Identity >>');
      put(id + 2, '<< /Type /FontDescriptor /FontName /' + base + ' /Flags 32 /FontBBox [' + d.bbox.map(function (v) { return Math.round(v * scale); }).join(' ') +
        '] /ItalicAngle ' + d.italic + ' /Ascent ' + Math.round(d.ascent * scale) + ' /Descent ' + Math.round(d.descent * scale) +
        ' /CapHeight ' + Math.round(d.cap * scale) + ' /StemV ' + d.stemv + ' /FontFile2 ' + (id + 3) + ' 0 R >>');
      put(id + 3, streamObject('/Length1 ' + ttf.length, ttf, packedMap['font:' + k]));
      put(id + 4, streamObject('', unicodeMap, packedMap['map:' + k]));
    });

    var fontRes = order.map(function (k) { return '/' + doc.faces[k].alias + ' ' + fontIds[k] + ' 0 R'; }).join(' ');
    doc.pages.forEach(function (page, n) {
      var pid = pageIds[n], raw = toBytes(page.ops.join('\n'));
      put(pid, '<< /Type /Page /Parent 2 0 R /MediaBox [0 0 ' + num(PAGE_W) + ' ' + num(PAGE_H) + '] /Resources << /Font << ' + fontRes + ' >> >> /Contents ' + (pid + 1) + ' 0 R >>');
      put(pid + 1, streamObject('', raw, packedMap['page:' + n]));
    });

    var chunks = [toBytes('%PDF-1.7\n%\xE2\xE3\xCF\xD3\n')], offset = chunks[0].length, offsets = [];
    for (i = 0; i < objects.length; i++) {
      var head = toBytes((i + 1) + ' 0 obj\n'), tail = toBytes('\nendobj\n');
      offsets.push(offset);
      chunks.push(head, objects[i], tail);
      offset += head.length + objects[i].length + tail.length;
    }
    var xref = 'xref\n0 ' + (objects.length + 1) + '\n0000000000 65535 f \n';
    offsets.forEach(function (o) { xref += pad(o, 10) + ' 00000 n \n'; });
    var id = randomHex(16);
    xref += 'trailer\n<< /Size ' + (objects.length + 1) + ' /Root 1 0 R /Info 3 0 R /ID [<' + id + '> <' + id + '>] >>\nstartxref\n' + offset + '\n%%EOF\n';
    chunks.push(toBytes(xref));
    return concat(chunks);
  }

  function supported() {
    return typeof Uint8Array !== 'undefined' && typeof Promise !== 'undefined' && typeof global.atob === 'function' && !!global.DHAR_PDF_FONTS;
  }

  function build(model) {
    return new Promise(function (resolve, reject) {
      try {
        if (!supported()) { throw new Error('This browser cannot build the PDF.'); }
        var doc = layout(model, global.DHAR_PDF_FONTS);
        /* Compress what is worth compressing, then write the file. */
        var jobs = [], names = [];
        doc.pages.forEach(function (page, n) { names.push('page:' + n); jobs.push(deflate(toBytes(page.ops.join('\n')))); });
        ['archivo', 'archivoBold', 'dejavu'].forEach(function (k) {
          var face = doc.faces[k];
          if (!Object.keys(face.used).length) { return; }
          names.push('font:' + k); jobs.push(deflate(base64ToBytes(face.data.ttf)));
          names.push('map:' + k); jobs.push(deflate(toUnicodeCMap(face)));
        });
        Promise.all(jobs).then(function (results) {
          var packed = {};
          names.forEach(function (name, i) { packed[name] = results[i]; });
          try { resolve(assemble(doc, model, packed)); } catch (e) { reject(e); }
        }, reject);
      } catch (e) {
        reject(e);
      }
    });
  }

  global.DharPdf = { build: build, supported: supported };
})(typeof window !== 'undefined' ? window : globalThis);
