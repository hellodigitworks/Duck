-- Duck's numbers. Three small tables, nothing that names a person or a Mac.

-- One row per Mac per day, written when that Mac's copy of Duck looks for an update.
-- `mac` is a hash of the network address and the app's user agent, mixed with a salt
-- that only exists for that one day. Once the day's salt is deleted, nobody can work
-- back from the hash to the address, or tell that two days' rows were the same Mac.
CREATE TABLE IF NOT EXISTS checks (
  day     TEXT NOT NULL,   -- YYYY-MM-DD, India time
  mac     TEXT NOT NULL,
  version TEXT NOT NULL,   -- the Duck version doing the looking
  country TEXT NOT NULL,   -- two letters from Cloudflare, or XX when unknown
  PRIMARY KEY (day, mac)
);

-- Today's salt only. Yesterday's is deleted the first time today's is made.
CREATE TABLE IF NOT EXISTS salts (
  day  TEXT PRIMARY KEY,
  salt TEXT NOT NULL
);

-- GitHub's all-time download totals, saved once a day. The difference between two
-- days is that day's downloads. `dmg` is the site's download button, the only way to
-- get Duck. `zip` is Duck updating itself.
CREATE TABLE IF NOT EXISTS downloads (
  day      TEXT PRIMARY KEY,
  dmg      INTEGER,
  zip      INTEGER,
  tried_at INTEGER NOT NULL   -- when GitHub was last asked, in ms, so a failure retries hourly, not every hit
);
