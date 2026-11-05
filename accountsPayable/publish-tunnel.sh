#!/bin/zsh
# Starts the Accounts Payable site and its Cloudflare quick tunnel, then sends the
# tunnel's current address to GitHub (api.json) so the GitHub Pages and Amplify
# copies of the pages can reach Cassandra on this Mac.
# Run it after every Mac or Docker restart:  ./publish-tunnel.sh
set -e
cd "$(dirname "$0")"
REPO=Korgano011/accounts-payable-test

docker compose -f accts.yaml up -d

echo "Waiting for the tunnel address..."
URL=""
for i in {1..30}; do
  URL=$(docker logs acct_payable_tunnel 2>&1 | grep -o 'https://[a-z0-9-]*\.trycloudflare\.com' | tail -1)
  [ -n "$URL" ] && break
  sleep 2
done
if [ -z "$URL" ]; then
  echo "No tunnel address found. Check: docker logs acct_payable_tunnel"
  exit 1
fi
echo "Tunnel: $URL"

JSON="{\"api\": \"$URL/accounts_payable\"}"
CURRENT=$(gh api "repos/$REPO/contents/api.json" -q .content 2>/dev/null | base64 -d 2>/dev/null || true)
if [ "$CURRENT" = "$JSON" ]; then
  echo "GitHub already has this address. Nothing to update."
  exit 0
fi

SHA=$(gh api "repos/$REPO/contents/api.json" -q .sha 2>/dev/null || true)
args=(-X PUT "repos/$REPO/contents/api.json" -f message="Update tunnel address" -f content="$(printf '%s' "$JSON" | base64)")
[ -n "$SHA" ] && args+=(-f sha="$SHA")
gh api "${args[@]}" --silent
echo "Sent to GitHub. The GitHub Pages site picks it up in about a minute."
echo "Pages: https://korgano011.github.io/"
