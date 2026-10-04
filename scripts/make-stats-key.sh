#!/bin/zsh
# Makes the key that lets admin/stats.html read Duck's numbers from the live site.
#
#   zsh scripts/make-stats-key.sh
#
# Writes a new random key into admin/key.local.js (gitignored, never deployed) and gives
# the same key to the Cloudflare Pages project as the STATS_KEY secret. Running it again
# swaps both for a new key. The key is never printed. The site picks up the secret on
# its next deploy. Needs `wrangler login` done first.
set -euo pipefail
cd "$(dirname "$0")/.."

KEY=$(openssl rand -hex 32)

print -r -- "$KEY" | npx wrangler pages secret put STATS_KEY --project-name tuck

cat > admin/key.local.js <<JS
// The key for admin/stats.html. Made by scripts/make-stats-key.sh. Never commit,
// deploy or share this file. Lose it and run the script again for a new one.
window.DUCK_STATS_KEY = '$KEY';
JS

echo "Key made. admin/key.local.js is written and the site has STATS_KEY."
