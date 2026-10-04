// Duck stats: fetches /stats/data and draws it. No libraries, plain SVG.
(() => {
  const $ = (id) => document.getElementById(id);
  const number = new Intl.NumberFormat('en-IN');
  const compact = new Intl.NumberFormat('en', { notation: 'compact', maximumFractionDigits: 1 });
  const countryName = (() => {
    try { const names = new Intl.DisplayNames(['en'], { type: 'region' }); return (code) => (code === 'XX' ? 'Unknown' : names.of(code) || code); }
    catch { return (code) => code; }
  })();
  const shortDay = (day) => new Date(`${day}T00:00:00Z`).toLocaleDateString('en-GB', { day: 'numeric', month: 'short', timeZone: 'UTC' });
  const longDay = (day) => new Date(`${day}T00:00:00Z`).toLocaleDateString('en-GB', { weekday: 'short', day: 'numeric', month: 'short', timeZone: 'UTC' });
  const escape = (text) => String(text).replace(/[&<>"]/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;' })[c]);

  let data = null;

  // ---------- screen states ----------
  function show(state) {
    for (const id of ['loading', 'error', 'empty', 'full']) $(id).hidden = id !== state;
  }

  async function load() {
    const button = $('refresh');
    button.disabled = true;
    button.setAttribute('aria-busy', 'true');
    if (!data) show('loading');
    try {
      const response = await fetch('/stats/data', { cache: 'no-store' });
      const body = await response.json().catch(() => null);
      if (!response.ok || !body || body.error) throw new Error((body && body.error) || `The site answered ${response.status}.`);
      data = body;
      render();
    } catch (error) {
      $('error-detail').textContent = error.message || 'Something went wrong reaching the site.';
      $('updated').textContent = data ? 'Could not refresh. Showing the last numbers.' : 'Not loaded.';
      if (!data) show('error');
    } finally {
      button.disabled = false;
      button.removeAttribute('aria-busy');
    }
  }

  // ---------- the page ----------
  function render() {
    const time = new Date(data.updatedAt).toLocaleTimeString('en-IN', { hour: 'numeric', minute: '2-digit', timeZone: 'Asia/Kolkata' });
    $('updated').textContent = `Updated ${time}, India time.`;

    if (!data.first) {
      const note = $('empty-downloads');
      note.hidden = !data.totals;
      if (data.totals) note.textContent = `Downloads so far: ${number.format(data.totals.dmg)} from the site, ${number.format(data.totals.zip)} through Terminal, Homebrew and updates.`;
      show('empty');
      return;
    }
    show('full');

    const days = data.days;
    const today = days[days.length - 1];
    const yesterday = days[days.length - 2];
    // Averages only count days since counting began, so a new setup does not read as a slump.
    const counted = days.slice(0, -1).filter((d) => d.day >= data.first);
    const average = (list) => (list.length ? Math.round(list.reduce((sum, d) => sum + d.macs, 0) / list.length) : 0);

    $('today').textContent = number.format(today.macs);
    $('today-sub').textContent = yesterday.day >= data.first
      ? `So far. Yesterday was ${number.format(yesterday.macs)}.`
      : 'So far. Counting started today.';
    $('avg7').textContent = number.format(average(counted.slice(-7)));
    $('avg30').textContent = number.format(average(counted));
    $('dmg-total').textContent = data.totals ? number.format(data.totals.dmg) : '–';
    $('zip-total').textContent = data.totals ? number.format(data.totals.zip) : '–';

    drawMacs();
    drawDownloads();
    drawShares($('versions'), data.versions, (v) => `Duck ${v}`);
    drawShares($('countries'), foldOther(data.countries, 8), (c) => (c === 'Other' ? 'Other' : countryName(c)));
    tables();
  }

  function foldOther(rows, keep) {
    if (rows.length <= keep + 1) return rows;
    const rest = rows.slice(keep).reduce((sum, r) => sum + r.n, 0);
    return [...rows.slice(0, keep), { name: 'Other', n: rest }];
  }

  // ---------- column charts ----------
  const NS = 'http://www.w3.org/2000/svg';
  const el = (name, attrs) => { const node = document.createElementNS(NS, name); for (const k in attrs) node.setAttribute(k, attrs[k]); return node; };

  function niceMax(value) {
    if (value <= 4) return 4;
    const step = 10 ** Math.floor(Math.log10(value));
    for (const m of [1, 2, 2.5, 5, 10]) if (m * step >= value) return m * step;
    return 10 * step;
  }

  // A bar with a 4px round top and a square foot on the baseline.
  function column(x, y, w, h, round) {
    const r = round ? Math.min(4, w / 2, h) : 0;
    return `M${x},${y + h}V${y + r}Q${x},${y} ${x + r},${y}H${x + w - r}Q${x + w},${y} ${x + w},${y + r}V${y + h}Z`;
  }

  // columns: [{ day, parts: [{ cls, value }], tip }]
  function columns(host, rows, label) {
    host.textContent = '';
    const width = Math.max(280, host.clientWidth);
    const height = 180;
    const pad = { top: 8, right: 4, bottom: 24, left: 32 };
    const innerW = width - pad.left - pad.right;
    const innerH = height - pad.top - pad.bottom;
    const total = (r) => r.parts.reduce((sum, p) => sum + (p.value || 0), 0);
    const max = niceMax(Math.max(...rows.map(total)));
    const band = innerW / rows.length;
    const barW = Math.min(24, Math.max(3, band - 2));
    const y = (v) => pad.top + innerH - (v / max) * innerH;

    const svg = el('svg', { viewBox: `0 0 ${width} ${height}`, role: 'img', 'aria-label': label });

    for (const tick of [0, max / 2, max]) {
      svg.append(el('line', { class: 'gridline', x1: pad.left, x2: width - pad.right, y1: y(tick), y2: y(tick) }));
      const text = el('text', { class: 'axis', x: pad.left - 8, y: y(tick) + 4, 'text-anchor': 'end' });
      text.textContent = compact.format(tick);
      svg.append(text);
    }

    rows.forEach((row, i) => {
      const x = pad.left + i * band + (band - barW) / 2;
      let base = 0;
      const drawn = row.parts.filter((p) => p.value > 0);
      drawn.forEach((part, j) => {
        const top = j === drawn.length - 1;
        const y0 = y(base + part.value);
        // 2px of card between stacked parts, so they read apart without an outline.
        const h = Math.max(1, y(base) - y0 - (j > 0 ? 2 : 0));
        svg.append(el('path', { class: `col ${part.cls}`, d: column(x, y0, barW, h, top) }));
        base += part.value;
      });

      const hit = el('rect', { class: 'hit', x: pad.left + i * band, y: pad.top, width: band, height: innerH, tabindex: 0, 'aria-label': row.tip.replace(/<[^>]+>/g, '') });
      hit.addEventListener('pointerenter', (e) => tip(hit, row.tip, e));
      hit.addEventListener('pointerdown', (e) => tip(hit, row.tip, e));
      hit.addEventListener('pointerleave', untip);
      hit.addEventListener('focus', () => tip(hit, row.tip));
      hit.addEventListener('blur', untip);
      svg.append(hit);
    });

    for (const i of [0, Math.floor((rows.length - 1) / 2), rows.length - 1]) {
      const text = el('text', { class: 'axis', x: pad.left + i * band + band / 2, y: height - 6, 'text-anchor': i === 0 ? 'start' : i === rows.length - 1 ? 'end' : 'middle' });
      text.textContent = i === rows.length - 1 ? 'Today' : shortDay(rows[i].day);
      svg.append(text);
    }
    host.append(svg);
  }

  function drawMacs() {
    const last = data.days.length - 1;
    columns($('macs-chart'), data.days.map((d, i) => ({
      day: d.day,
      parts: [{ cls: i === last ? 'partial' : '', value: d.macs }],
      tip: `<b>${number.format(d.macs)} Macs</b><br>${longDay(d.day)}${i === last ? ', so far' : ''}`,
    })), 'Macs that ran Duck each day, last 30 days');
  }

  function drawDownloads() {
    columns($('downloads-chart'), data.days.map((d) => ({
      day: d.day,
      parts: [{ cls: 'dmg', value: d.dmg || 0 }, { cls: 'zip', value: d.zip || 0 }],
      tip: d.dmg === null
        ? `<b>Not saved</b><br>${longDay(d.day)}`
        : `<b>${number.format(d.dmg)}</b> site · <b>${number.format(d.zip)}</b> Terminal, Homebrew, updates<br>${longDay(d.day)}`,
    })), 'Downloads each day, last 30 days');
  }

  // ---------- share bars ----------
  function drawShares(host, rows, name) {
    const sum = rows.reduce((total, r) => total + r.n, 0) || 1;
    const top = rows.length ? rows[0].n : 1;
    host.innerHTML = rows.length
      ? rows.map((r) => {
          const share = Math.round((r.n / sum) * 100);
          return `<li><span class="name">${escape(name(r.name))}</span><span class="track"><span class="fill" style="width:${(r.n / top) * 100}%"></span></span><span class="share">${share < 1 ? '<1' : share}%</span></li>`;
        }).join('')
      : '<li><span class="name">Nothing yet</span></li>';
  }

  // ---------- tables ----------
  function tables() {
    const rows = [...data.days].reverse();
    $('macs-table').innerHTML = `<table><thead><tr><th>Day</th><th>Macs</th></tr></thead><tbody>${
      rows.map((d) => `<tr><td>${longDay(d.day)}</td><td>${number.format(d.macs)}</td></tr>`).join('')
    }</tbody></table>`;
    const cell = (v) => (v === null ? '–' : number.format(v));
    $('downloads-table').innerHTML = `<table><thead><tr><th>Day</th><th>Site</th><th>Terminal, Homebrew, updates</th></tr></thead><tbody>${
      rows.map((d) => `<tr><td>${longDay(d.day)}</td><td>${cell(d.dmg)}</td><td>${cell(d.zip)}</td></tr>`).join('')
    }</tbody></table>`;
  }

  // ---------- tooltip ----------
  let lit = null;
  function tip(target, html, event) {
    const box = $('tip');
    if (lit) lit.classList.remove('on');
    lit = target;
    target.classList.add('on');
    box.innerHTML = html;
    box.hidden = false;
    const rect = target.getBoundingClientRect();
    const w = box.offsetWidth;
    const x = Math.min(window.innerWidth - w - 8, Math.max(8, rect.left + rect.width / 2 - w / 2));
    box.style.left = `${x}px`;
    box.style.top = `${Math.max(8, rect.top - box.offsetHeight - 8)}px`;
  }
  function untip() {
    $('tip').hidden = true;
    if (lit) lit.classList.remove('on');
    lit = null;
  }
  window.addEventListener('scroll', untip, { passive: true });

  // ---------- wiring ----------
  $('refresh').addEventListener('click', load);
  $('retry').addEventListener('click', load);
  let resizeTimer;
  window.addEventListener('resize', () => {
    clearTimeout(resizeTimer);
    resizeTimer = setTimeout(() => { if (data && data.first) { drawMacs(); drawDownloads(); } }, 120);
  });
  document.addEventListener('visibilitychange', () => { if (document.visibilityState === 'visible' && data) load(); });

  load();
})();
