// The counting, shared by the update feed and the stats page. Never touches the screen.

const REPO = 'hellodigitworks/Duck';
const HOUR = 60 * 60 * 1000;

// Days run on India time, so "today" on the stats page is Swayam's today. Fixed offset,
// India has no daylight saving.
export function dayOf(ms) {
  return new Date(ms + 5.5 * HOUR).toISOString().slice(0, 10);
}

// Sparkle introduces itself as "Duck/1.1.1 Sparkle/2.6.4". Anything else asking for the
// feed (a browser, a crawler) is not a running copy of Duck and is not counted.
export function duckVersion(userAgent) {
  const match = /^Duck\/([0-9][0-9A-Za-z.\-]*)\s.*Sparkle\//.exec(userAgent || '');
  return match ? match[1].slice(0, 20) : null;
}

async function sha256(text) {
  const bytes = await crypto.subtle.digest('SHA-256', new TextEncoder().encode(text));
  return [...new Uint8Array(bytes)].map((b) => b.toString(16).padStart(2, '0')).join('');
}

// Today's salt, made the first time it is needed. Every older salt goes at the same
// moment, which is what makes yesterday's hashes impossible to reverse or link.
async function saltFor(db, day) {
  const made = crypto.randomUUID() + crypto.randomUUID();
  await db.batch([
    db.prepare('DELETE FROM salts WHERE day <> ?').bind(day),
    db.prepare('INSERT OR IGNORE INTO salts (day, salt) VALUES (?, ?)').bind(day, made),
  ]);
  const row = await db.prepare('SELECT salt FROM salts WHERE day = ?').bind(day).first();
  return row.salt;
}

// One update check from one Mac. The address is used for the hash and then dropped.
export async function recordCheck(db, request, now = Date.now()) {
  const userAgent = request.headers.get('user-agent') || '';
  const version = duckVersion(userAgent);
  if (!version) return;
  const address = request.headers.get('cf-connecting-ip') || '';
  const country = (request.cf && /^[A-Z]{2}$/.test(request.cf.country) && request.cf.country) || 'XX';
  const day = dayOf(now);
  const mac = (await sha256(`${await saltFor(db, day)}|${address}|${userAgent}`)).slice(0, 32);
  await db
    .prepare(
      `INSERT INTO checks (day, mac, version, country) VALUES (?, ?, ?, ?)
       ON CONFLICT (day, mac) DO UPDATE SET version = excluded.version, country = excluded.country`
    )
    .bind(day, mac, version, country)
    .run();
}

// GitHub's totals across every release, by file name.
async function githubTotals(token) {
  const headers = { 'user-agent': 'duck-stats', accept: 'application/vnd.github+json' };
  if (token) headers.authorization = `Bearer ${token}`;
  const response = await fetch(`https://api.github.com/repos/${REPO}/releases?per_page=100`, { headers });
  if (!response.ok) throw new Error(`GitHub said ${response.status}`);
  const totals = { dmg: 0, zip: 0 };
  for (const release of await response.json()) {
    for (const asset of release.assets || []) {
      if (asset.name === 'Duck.dmg') totals.dmg += asset.download_count;
      if (asset.name === 'Duck.zip') totals.zip += asset.download_count;
    }
  }
  return totals;
}

// Saves today's totals once. A failed try waits an hour before the next, so a GitHub
// outage never turns every update check into a GitHub request.
export async function snapshotDownloads(db, token, now = Date.now()) {
  const day = dayOf(now);
  const row = await db.prepare('SELECT dmg, tried_at FROM downloads WHERE day = ?').bind(day).first();
  if (row && (row.dmg !== null || now - row.tried_at < HOUR)) return;
  const claimed = await db
    .prepare(
      `INSERT INTO downloads (day, dmg, zip, tried_at) VALUES (?, NULL, NULL, ?)
       ON CONFLICT (day) DO UPDATE SET tried_at = excluded.tried_at
       WHERE downloads.dmg IS NULL AND ? - downloads.tried_at >= ?`
    )
    .bind(day, now, now, HOUR)
    .run();
  if (!claimed.meta.changes) return; // another request got there first
  const totals = await githubTotals(token);
  await db.prepare('UPDATE downloads SET dmg = ?, zip = ? WHERE day = ?').bind(totals.dmg, totals.zip, day).run();
}

// Everything the stats page draws, in one answer.
export async function readStats(db, now = Date.now()) {
  const today = dayOf(now);
  const daysAgo = (n) => dayOf(now - n * 24 * HOUR);
  const from30 = daysAgo(29);
  const from7 = daysAgo(6);

  const [active, versions, countries, downloads, latestTotals] = await db.batch([
    db.prepare('SELECT day, COUNT(*) AS macs FROM checks WHERE day >= ? GROUP BY day').bind(from30),
    db.prepare('SELECT version, COUNT(*) AS n FROM checks WHERE day >= ? GROUP BY version').bind(from7),
    db.prepare('SELECT country, COUNT(*) AS n FROM checks WHERE day >= ? GROUP BY country').bind(from30),
    // One day further back than the window, so the first day has something to subtract from.
    db.prepare('SELECT day, dmg, zip FROM downloads WHERE day >= ? AND dmg IS NOT NULL ORDER BY day').bind(daysAgo(30)),
    db.prepare('SELECT day, dmg, zip FROM downloads WHERE dmg IS NOT NULL ORDER BY day DESC LIMIT 1'),
  ]);

  const macsByDay = Object.fromEntries(active.results.map((r) => [r.day, r.macs]));
  const totalsByDay = Object.fromEntries(downloads.results.map((r) => [r.day, r]));

  const days = [];
  for (let n = 29; n >= 0; n--) {
    const day = daysAgo(n);
    const here = totalsByDay[day];
    const before = totalsByDay[daysAgo(n + 1)];
    days.push({
      day,
      macs: macsByDay[day] || 0,
      // Only known when both days were saved. A gap stays a gap, never a guessed zero.
      dmg: here && before ? Math.max(0, here.dmg - before.dmg) : null,
      zip: here && before ? Math.max(0, here.zip - before.zip) : null,
    });
  }

  const sortDown = (rows, key) => rows.map((r) => ({ name: r[key], n: r.n })).sort((a, b) => b.n - a.n);
  const totals = latestTotals.results[0] || null;

  return {
    today,
    updatedAt: now,
    days,
    first: (await db.prepare('SELECT MIN(day) AS day FROM checks').first()).day,
    versions: sortDown(versions.results, 'version'),
    countries: sortDown(countries.results, 'country'),
    totals: totals && { day: totals.day, dmg: totals.dmg, zip: totals.zip },
  };
}
