#!/bin/zsh
# Creates the Cloudflare database behind duck.hellodigitworks.com/stats, once.
#
#   zsh scripts/make-stats-db.sh
#
# Makes a free D1 database called duck-stats, writes its id into site/wrangler.toml and
# sets up its tables. Running it again is safe: an existing database is reused and the
# tables are only made if missing. Needs `wrangler login` done first.
set -euo pipefail
cd "$(dirname "$0")/../site"

NAME="duck-stats"

find_id() {
  npx wrangler d1 list --json | python3 -c "
import json, sys
print(next((db['uuid'] for db in json.load(sys.stdin) if db['name'] == '$NAME'), ''))
"
}

ID=$(find_id)
if [[ -z "$ID" ]]; then
  npx wrangler d1 create "$NAME"
  ID=$(find_id)
fi

sed -i '' -E "s/^database_id = \".*\"/database_id = \"$ID\"/" wrangler.toml
npx wrangler d1 migrations apply "$NAME" --remote

echo "duck-stats is ready: $ID"
echo "The counting starts once site/ is deployed."
