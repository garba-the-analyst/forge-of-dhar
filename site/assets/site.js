/*
 * site.js - the little behaviour the Dhar page has. No libraries.
 *
 * Without JavaScript the page still reads: the first example tab is visible, the status board shows
 * every row, and the raw benchmark table is open (this script fills it, then closes it).
 *
 *   1. Tabs (WAI-ARIA tabs pattern: arrow keys, Home, End).
 *   2. Copy buttons on the code windows (Clipboard API, with a textarea fallback).
 *   3. Status board filter (+ the counts on the buttons).
 *   4. Speed chart: log-scale bars drawn from the JSON in #bench-data, Median/Mean toggle.
 *   5. Current-section highlight in the header nav.
 */
(function () {
  "use strict";

  /* ---------- 1. Tabs ---------- */
  var tabs = Array.prototype.slice.call(document.querySelectorAll('[role="tab"]'));
  function selectTab(tab, focus) {
    tabs.forEach(function (t) {
      var on = t === tab;
      t.setAttribute("aria-selected", on ? "true" : "false");
      t.tabIndex = on ? 0 : -1;
      document.getElementById(t.getAttribute("aria-controls")).hidden = !on;
    });
    if (focus) tab.focus();
  }
  tabs.forEach(function (tab, i) {
    tab.addEventListener("click", function () { selectTab(tab, false); });
    tab.addEventListener("keydown", function (e) {
      var j = null;
      if (e.key === "ArrowRight") j = (i + 1) % tabs.length;
      else if (e.key === "ArrowLeft") j = (i + tabs.length - 1) % tabs.length;
      else if (e.key === "Home") j = 0;
      else if (e.key === "End") j = tabs.length - 1;
      if (j !== null) { e.preventDefault(); selectTab(tabs[j], true); }
    });
  });

  /* ---------- 2. Copy buttons ---------- */
  function copyText(text) {
    if (navigator.clipboard && navigator.clipboard.writeText) {
      return navigator.clipboard.writeText(text);
    }
    return new Promise(function (resolve, reject) {
      var ta = document.createElement("textarea");
      ta.value = text; ta.setAttribute("readonly", "");
      ta.style.position = "fixed"; ta.style.opacity = "0";
      document.body.appendChild(ta); ta.select();
      try { document.execCommand("copy") ? resolve() : reject(new Error("copy refused")); }
      catch (err) { reject(err); }
      document.body.removeChild(ta);
    });
  }
  Array.prototype.forEach.call(document.querySelectorAll(".win .copy"), function (btn) {
    btn.addEventListener("click", function () {
      var code = btn.closest(".win").querySelector("code");
      copyText(code.textContent).then(function () { btn.textContent = "Copied"; },
                                      function () { btn.textContent = "Press Ctrl+C"; });
      setTimeout(function () { btn.textContent = "Copy"; }, 1800);
    });
  });

  /* ---------- 3. Status filter ---------- */
  var rows = Array.prototype.slice.call(document.querySelectorAll("#board > li"));
  var fbtns = Array.prototype.slice.call(document.querySelectorAll("[data-filter]"));
  fbtns.forEach(function (b) {
    var f = b.getAttribute("data-filter");
    var n = f === "all" ? rows.length : rows.filter(function (r) { return r.dataset.status === f; }).length;
    b.querySelector(".count").textContent = n;
    b.addEventListener("click", function () {
      fbtns.forEach(function (x) { x.setAttribute("aria-pressed", x === b ? "true" : "false"); });
      rows.forEach(function (r) { r.hidden = !(f === "all" || r.dataset.status === f); });
    });
  });

  /* ---------- 4. Speed chart ---------- */
  var dataEl = document.getElementById("bench-data");
  var chart = document.getElementById("chart");
  if (dataEl && chart) {
    var data = JSON.parse(dataEl.textContent);
    var LO = 0.3, HI = 1000;                       // axis range, ms (log scale)
    var metric = "median";
    var verdict = document.getElementById("verdict");
    var all = [];
    data.groups.forEach(function (g) { g.rows.forEach(function (r) { all.push(r); }); });
    var us = all.filter(function (r) { return r.us; })[0];

    var frac = function (v) { return Math.log(v / LO) / Math.log(HI / LO); };
    var fmt = function (v) { return v < 10 ? v.toFixed(2) : v < 100 ? v.toFixed(1) : String(Math.round(v)); };
    var x1 = function (v) { return (Math.round(v * 10) / 10).toFixed(1) + "×"; };

    // fill the raw-numbers table once
    var tbody = document.querySelector("#raw tbody");
    if (tbody) {
      all.forEach(function (r) {
        var tr = document.createElement("tr");
        [r.name, r.median.toFixed(2), r.mean.toFixed(2), r.sd.toFixed(2)].forEach(function (c, i) {
          var td = document.createElement("td");
          if (i) td.className = "num";
          td.textContent = c; tr.appendChild(td);
        });
        tbody.appendChild(tr);
      });
    }

    var rowsByName = {};
    var el = function (tag, cls, text) {
      var e = document.createElement(tag);
      if (cls) e.className = cls;
      if (text) e.textContent = text;
      return e;
    };
    data.groups.forEach(function (g) {
      chart.appendChild(el("p", "group-label", g.label));
      var ul = el("ul", "bars");
      ul.style.listStyle = "none";
      g.rows.slice().sort(function (a, b) { return a.median - b.median; }).forEach(function (r) {
        var li = el("li", "bar-row" + (r.us ? " us" : ""));
        li.appendChild(el("span", "bar-name", r.name));
        var track = el("span", "bar-track");
        track.appendChild(el("span", "bar-fill"));
        track.appendChild(el("span", "bar-val"));
        li.appendChild(track); ul.appendChild(li);
        rowsByName[r.name] = { row: r, track: track };
      });
      chart.appendChild(ul);
    });

    // axis: ticks at 1, 10, 100, 1000 ms with minor ticks at 3, 30, 300
    var axis = el("div", "axis");
    axis.appendChild(el("span"));
    var line = el("div", "axis-line");
    [[0.3, ""], [1, "1 ms"], [3, ""], [10, "10 ms"], [30, ""], [100, "100 ms"], [300, ""], [1000, "1 s"]].forEach(function (t) {
      var i = el("i"); i.style.left = (frac(t[0]) * 100) + "%"; line.appendChild(i);
      if (t[1]) { var s = el("span", "", t[1]); s.style.left = (frac(t[0]) * 100) + "%"; line.appendChild(s); }
    });
    axis.appendChild(line);
    chart.appendChild(axis);

    var draw = function () {
      Object.keys(rowsByName).forEach(function (k) {
        var o = rowsByName[k], v = o.row[metric];
        o.track.style.setProperty("--w", (frac(v) * 100).toFixed(2) + "%");
        o.track.querySelector(".bar-val").textContent = fmt(v) + " ms";
        // the track's own width variable also positions the label
        o.track.querySelector(".bar-fill").style.setProperty("--w", (frac(v) * 100).toFixed(2) + "%");
      });
      var c = all[0], rt = all.filter(function (r) { return /Node|PHP|Java|Python/.test(r.name); });
      var slow = us[metric] / c[metric];
      var f = rt.map(function (r) { return r[metric] / us[metric]; });
      verdict.innerHTML = "";
      verdict.appendChild(document.createTextNode("By the " + metric + ", Dhar is "));
      verdict.appendChild(el("b", "", x1(slow) + " slower than C"));
      verdict.appendChild(document.createTextNode(" and "));
      verdict.appendChild(el("b", "", x1(Math.min.apply(null, f)) + " to " + x1(Math.max.apply(null, f)) + " faster"));
      verdict.appendChild(document.createTextNode(" than Node.js, PHP, Java and Python."));
    };
    Array.prototype.forEach.call(document.querySelectorAll("[data-metric]"), function (b) {
      b.addEventListener("click", function () {
        metric = b.getAttribute("data-metric");
        Array.prototype.forEach.call(document.querySelectorAll("[data-metric]"), function (x) {
          x.setAttribute("aria-pressed", x === b ? "true" : "false");
        });
        draw();
      });
    });
    draw();
    var det = document.querySelector("details.raw");
    if (det) det.open = false;          // table is open in the markup for no-JS readers
  }

  /* ---------- 5. Nav highlight ---------- */
  if ("IntersectionObserver" in window) {
    var links = {};
    Array.prototype.forEach.call(document.querySelectorAll(".bar nav a"), function (a) { links[a.getAttribute("href").slice(1)] = a; });
    var io = new IntersectionObserver(function (entries) {
      entries.forEach(function (en) {
        if (en.isIntersecting && links[en.target.id]) {
          Object.keys(links).forEach(function (k) { links[k].removeAttribute("aria-current"); });
          links[en.target.id].setAttribute("aria-current", "true");
        }
      });
    }, { rootMargin: "-45% 0px -50% 0px" });
    Object.keys(links).forEach(function (id) { var s = document.getElementById(id); if (s) io.observe(s); });
  }
})();
