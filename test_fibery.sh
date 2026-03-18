#!/bin/bash
# test_fibery.sh — Tests the Fibery integration with dummy data.
# Run on any machine with curl and python3. No macOS required.
#
# Usage:
#   chmod +x test_fibery.sh
#   FIBERY_TOKEN=your_token_here ./test_fibery.sh
#
# Or enter the token interactively when prompted.

set -euo pipefail

# ---------------------------------------------------------------------------
# Config — mirrors the main script
# ---------------------------------------------------------------------------
FIBERY_HOST="sound-disposition.fibery.io"
FIBERY_SPACE="Tickets"
FIBERY_TYPE="Tickets/Tickets"
FIBERY_LOGS_FIELD="Tickets/Logs"

# Token: use env var or prompt
if [ -z "${FIBERY_TOKEN:-}" ]; then
    read -rsp "Fibery API token: " FIBERY_TOKEN
    echo
fi

if [ -z "$FIBERY_TOKEN" ]; then
    echo "ERROR: No token provided." >&2
    exit 1
fi

# ---------------------------------------------------------------------------
# Dummy data
# ---------------------------------------------------------------------------
TMPDIR_TEST=$(mktemp -d)
trap 'rm -rf "$TMPDIR_TEST"' EXIT

DUMMY_REPORT_DIR="$TMPDIR_TEST/ProToolsReport_TEST"
mkdir -p "$DUMMY_REPORT_DIR/crash_logs" "$DUMMY_REPORT_DIR/avid_logs"

SUMMARY="$DUMMY_REPORT_DIR/00_summary.txt"
cat > "$SUMMARY" <<'EOF'
========================================
 Pro Tools Crash Report
 Generated: TEST RUN — not a real report
 Coverage:  Crash logs: last 2h | App logs: today
========================================

macOS Version : 14.4.1 (23E224)  [DUMMY]
Hostname      : Studio-Mac-TEST
User          : testuser
Uptime        :  9:41  up 3 days, 17:22, 2 users

Pro Tools Version:
  24.3.0

--- CRASH LOGS (last 2h) ---
  Copied: Pro Tools_2026-03-11-143201_Studio-Mac.crash  [DUMMY]
  Total crash files copied: 1

--- PRO TOOLS APP LOGS (today) ---
  Copied: Pro_Tools_Log.txt  [DUMMY]
  Copied: Pro_Tools_Video_Log.txt  [DUMMY]

--- SYSTEM LOG (last 2h, Pro Tools / Avid) ---
  Done.

--- SYSTEM PROFILER ---
  Done.

========================================
 Collection complete: TEST RUN
 Report folder: /Users/testuser/Desktop/ProToolsReport_TEST
========================================
EOF

# Dummy crash log
echo "Dummy crash log content — Pro Tools crashed at 14:32:01" \
    > "$DUMMY_REPORT_DIR/crash_logs/Pro_Tools_2026-03-11.crash"

# Dummy avid log
echo "Dummy Avid log content" \
    > "$DUMMY_REPORT_DIR/avid_logs/Pro_Tools_Log.txt"

# Zip the dummy report
ZIP="$TMPDIR_TEST/ProToolsReport_TEST.zip"
(cd "$TMPDIR_TEST" && zip -qr "ProToolsReport_TEST.zip" "ProToolsReport_TEST/")

echo
echo "=== Dummy data created ==="
echo "  Summary:  $SUMMARY"
echo "  Zip:      $ZIP"
echo

# ---------------------------------------------------------------------------
# Fibery functions (copied verbatim from the main script)
# ---------------------------------------------------------------------------

fibery_upload_file() {
    local FILE_PATH="$1"
    curl -sf -X POST \
        "https://${FIBERY_HOST}/api/files" \
        -H "Authorization: Token ${FIBERY_TOKEN}" \
        -F "file=@${FILE_PATH}" \
    | python3 -c "import sys,json; print(json.load(sys.stdin).get('fibery/id',''))"
}

fibery_create_ticket() {
    local TICKET_NAME="$1"
    local MACHINE="$2"
    local TS_ISO="$3"

    local BODY
    BODY=$(python3 - "$TICKET_NAME" "$MACHINE" "$TS_ISO" <<'PYEOF'
import sys, json
name, machine, ts = sys.argv[1], sys.argv[2], sys.argv[3]
mutation = (
    "mutation { tickets { create("
    "title: " + json.dumps(name) + " "
    "timeStamp: " + json.dumps(ts) + " "
    "machine: " + json.dumps(machine) +
    ") { message entities { id } } } }"
)
print(json.dumps({"query": mutation}))
PYEOF
)

    curl -sf -X POST \
        "https://${FIBERY_HOST}/api/graphql/space/${FIBERY_SPACE}" \
        -H "Authorization: Token ${FIBERY_TOKEN}" \
        -H "Content-Type: application/json" \
        -d "$BODY" \
    | python3 -c "
import sys, json
d = json.load(sys.stdin)
print('  Raw response:', json.dumps(d), file=sys.stderr)
try:
    print(d['data']['tickets']['create']['entities'][0]['id'])
except (KeyError, TypeError, IndexError):
    print('')
"
}

fibery_set_description() {
    local ENTITY_ID="$1"
    local DESCRIPTION="$2"

    local BODY
    BODY=$(python3 - "$ENTITY_ID" "$DESCRIPTION" <<'PYEOF'
import sys, json
entity_id, description = sys.argv[1], sys.argv[2]
mutation = (
    "mutation { tickets(id: {is: " + json.dumps(entity_id) + "}) { "
    "overwriteDescription(value: " + json.dumps(description) + ") { message } } }"
)
print(json.dumps({"query": mutation}))
PYEOF
)

    curl -sf -X POST \
        "https://${FIBERY_HOST}/api/graphql/space/${FIBERY_SPACE}" \
        -H "Authorization: Token ${FIBERY_TOKEN}" \
        -H "Content-Type: application/json" \
        -d "$BODY" \
    | python3 -c "
import sys, json
d = json.load(sys.stdin)
print('  Raw response:', json.dumps(d), file=sys.stderr)
"
}

fibery_attach_file() {
    local ENTITY_ID="$1"
    local FILE_ID="$2"

    local BODY
    BODY=$(python3 - "$ENTITY_ID" "$FILE_ID" "$FIBERY_TYPE" "$FIBERY_LOGS_FIELD" <<'PYEOF'
import sys, json
entity_id, file_id, ftype, ffield = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4]
cmd = [{
    "command": "fibery.entity/add-collection-items",
    "args": {
        "type":   ftype,
        "field":  ffield,
        "entity": {"fibery/id": entity_id},
        "items":  [{"fibery/id": file_id}]
    }
}]
print(json.dumps(cmd))
PYEOF
)

    curl -sf -X POST \
        "https://${FIBERY_HOST}/api/commands" \
        -H "Authorization: Token ${FIBERY_TOKEN}" \
        -H "Content-Type: application/json" \
        -d "$BODY" \
    | python3 -c "import sys,json; print('  Raw response:', json.dumps(json.load(sys.stdin)), file=sys.stderr)"
}

# ---------------------------------------------------------------------------
# Introspection helper
# ---------------------------------------------------------------------------
fibery_introspect_create() {
    curl -sf -X POST \
        "https://${FIBERY_HOST}/api/graphql/space/${FIBERY_SPACE}" \
        -H "Authorization: Token ${FIBERY_TOKEN}" \
        -H "Content-Type: application/json" \
        -d '{"query":"{ __type(name: \"TicketsTicketsOperations\") { fields { name args { name type { name kind ofType { name kind } } } } } }"}' \
    | python3 -c "
import sys, json
d = json.load(sys.stdin)
try:
    fields = d['data']['__type']['fields']
    for f in fields:
        if f['name'] in ('create', 'overwriteDescription', 'overwriteDescriptionBatch'):
            print(f'{f[\"name\"]}() accepts these arguments:')
            for a in f['args']:
                t = a['type']
                type_name = t.get('name') or (t.get('ofType') or {}).get('name','')
                print(f'  {a[\"name\"]}: {type_name} (kind: {t[\"kind\"]})')
except (KeyError, TypeError) as e:
    print('Could not parse introspection response:', e)
    print('Raw:', json.dumps(d))
"
}

# ---------------------------------------------------------------------------
# Run the test
# ---------------------------------------------------------------------------
echo "--- Step 0: Introspect create() arguments ---"
fibery_introspect_create
echo

echo "--- Step 1: Upload zip ---"
FILE_ID=$(fibery_upload_file "$ZIP")
if [ -z "$FILE_ID" ]; then
    echo "FAILED: no file ID returned" >&2
    exit 1
fi
echo "  File ID: $FILE_ID"
echo

echo "--- Step 2: Create ticket ---"
MACHINE="Studio-Mac-TEST"
TS=$(date -u '+%Y-%m-%dT%H:%M:%S.000Z')
TICKET_NAME="[TEST] Pro Tools Crash — $(date '+%Y-%m-%d %H:%M') — ${MACHINE}"
ENTITY_ID=$(fibery_create_ticket "$TICKET_NAME" "$MACHINE" "$TS")
if [ -z "$ENTITY_ID" ]; then
    echo "FAILED: no entity ID returned (check raw response above for field name errors)" >&2
    exit 1
fi
echo "  Entity ID: $ENTITY_ID"
echo

echo "--- Step 3: Set description ---"
DESCRIPTION=$(cat "$SUMMARY")
fibery_set_description "$ENTITY_ID" "$DESCRIPTION"
echo "  Done."
echo

echo "--- Step 4: Attach zip ---"
fibery_attach_file "$ENTITY_ID" "$FILE_ID"
echo "  Done."
echo

echo "=== All steps passed ==="
echo "  Check Fibery for ticket: $TICKET_NAME"
echo "  https://${FIBERY_HOST}/Tickets/Tickets"
