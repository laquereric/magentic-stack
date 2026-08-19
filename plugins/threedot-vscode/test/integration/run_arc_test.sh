#!/usr/bin/env bash
# Boot the mind-pod rails-cpcp BACK, run the 3dot->Rails CPCP arc test (mmg-browser/headless
# Chrome) against it, tear down. mmg-browser is a substrate gem, so the test runs inside its
# bundle. Usage: bash run_arc_test.sh [PORT]
set -uo pipefail
export PATH="$HOME/.rbenv/shims:$PATH"; export LANG=en_US.UTF-8
PORT="${1:-3025}"
APP=/Users/ericlaquer/NoIcloud/magentic-stack/runtimes/mind-pod/app
MMG=/Users/ericlaquer/NoIcloud/magentic-market-ai/gems/mmg-browser
TEST=/Users/ericlaquer/NoIcloud/magentic-stack/plugins/threedot-vscode/test/integration/threedot_cpcp_arc_test.rb
cd "$APP"; bash bin/prepare >/dev/null 2>&1
lsof -ti tcp:$PORT -sTCP:LISTEN | xargs kill 2>/dev/null
rm -f db/arc.sqlite3*
DB_PATH=db/arc.sqlite3 RAILS_ENV=development bin/rails db:prepare >/tmp/arc_mig.log 2>&1
nohup env ROLE=back PORT=$PORT DB_PATH=db/arc.sqlite3 RAILS_ENV=development bundle exec rails server -b 127.0.0.1 -p $PORT >/tmp/arc_back.log 2>&1 &
BK=$!
for i in $(seq 1 30); do curl -sf http://127.0.0.1:$PORT/_cpcp/up >/dev/null 2>&1 && break; sleep 1; done
echo "BACK up on :$PORT (pid $BK)"
cd "$MMG" && BACK_URL=http://127.0.0.1:$PORT bundle exec ruby "$TEST"; rc=$?
kill $BK 2>/dev/null; rm -f "$APP/db/arc.sqlite3"*
exit $rc
