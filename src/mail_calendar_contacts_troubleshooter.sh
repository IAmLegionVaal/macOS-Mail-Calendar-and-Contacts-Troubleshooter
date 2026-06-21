#!/bin/bash
set -u

HOURS=24
IMAP_HOST=""
SMTP_HOST=""
OUTPUT_DIR=""

usage() {
  echo "Usage: mail_calendar_contacts_troubleshooter.sh [--hours N] [--imap-host HOST] [--smtp-host HOST] [--output DIR]"
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --hours) HOURS="${2:-24}"; shift 2 ;;
    --imap-host) IMAP_HOST="${2:-}"; shift 2 ;;
    --smtp-host) SMTP_HOST="${2:-}"; shift 2 ;;
    --output) OUTPUT_DIR="${2:-}"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown argument: $1" >&2; usage; exit 2 ;;
  esac
done

case "$HOURS" in ''|*[!0-9]*) echo "--hours must be numeric" >&2; exit 2 ;; esac
[ "$(uname -s)" = "Darwin" ] || { echo "This tool must run on macOS." >&2; exit 1; }

STAMP="$(date +%Y%m%d_%H%M%S)"
OUTPUT_DIR="${OUTPUT_DIR:-./mail-calendar-contacts-$STAMP}"
mkdir -p "$OUTPUT_DIR"
REPORT="$OUTPUT_DIR/troubleshooting-report.txt"
CSV="$OUTPUT_DIR/components.csv"
JSON="$OUTPUT_DIR/summary.json"
ERRORS="$OUTPUT_DIR/command-errors.log"
: > "$REPORT"
: > "$ERRORS"
echo 'component,state,detail' > "$CSV"

section() {
  title="$1"
  shift
  { printf '\n===== %s =====\n' "$title"; "$@"; } >> "$REPORT" 2>> "$ERRORS" || true
}

redact() {
  sed -E 's/[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}/REDACTED_EMAIL/g'
}

record() {
  detail=$(printf '%s' "$3" | sed 's/"/""/g')
  printf '"%s","%s","%s"\n' "$1" "$2" "$detail" >> "$CSV"
}

section "Collection metadata" /bin/bash -c 'date -u +%Y-%m-%dT%H:%M:%SZ; hostname; sw_vers; id'
section "Application and sync processes" /bin/bash -c 'ps -Ao pid,user,etime,comm,args | grep -Ei "Mail|Calendar|Contacts|accountsd|calaccessd|contactsd|IMAP|SMTP" | grep -v grep || true'
section "Application data sizes" /bin/bash -c 'du -sh "$HOME/Library/Mail" "$HOME/Library/Calendars" "$HOME/Library/Application Support/AddressBook" 2>/dev/null || true'
section "Mail database metadata" /bin/bash -c 'find "$HOME/Library/Mail" -maxdepth 4 -type f \( -name "Envelope Index*" -o -name "*.sqlite*" \) -print -exec ls -lh {} \; 2>/dev/null | head -n 1000 || true'
section "Calendar database metadata" /bin/bash -c 'find "$HOME/Library/Calendars" -maxdepth 3 -type f -name "*.sqlite*" -print -exec ls -lh {} \; 2>/dev/null | head -n 500 || true'
section "Contacts database metadata" /bin/bash -c 'find "$HOME/Library/Application Support/AddressBook" -maxdepth 3 -type f -name "*.abcddb*" -print -exec ls -lh {} \; 2>/dev/null | head -n 500 || true'

{
  printf '\n===== Internet account indicators =====\n'
  defaults read MobileMeAccounts 2>/dev/null | redact || true
} >> "$REPORT" 2>> "$ERRORS"

{
  printf '\n===== Recent Mail, Calendar and Contacts events =====\n'
  /usr/bin/log show --last "${HOURS}h" --style compact --predicate '(process == "Mail") OR (process == "accountsd") OR (process == "calaccessd") OR (process == "contactsd") OR (eventMessage CONTAINS[c] "IMAP") OR (eventMessage CONTAINS[c] "SMTP") OR (eventMessage CONTAINS[c] "Calendar") OR (eventMessage CONTAINS[c] "Contacts")' 2>/dev/null | tail -n 4000 | redact
} >> "$REPORT" 2>> "$ERRORS"

MAIL_DATA_PRESENT=false
[ -d "$HOME/Library/Mail" ] && MAIL_DATA_PRESENT=true
CALENDAR_DATA_PRESENT=false
[ -d "$HOME/Library/Calendars" ] && CALENDAR_DATA_PRESENT=true
CONTACTS_DATA_PRESENT=false
[ -d "$HOME/Library/Application Support/AddressBook" ] && CONTACTS_DATA_PRESENT=true
ACCOUNTSD_RUNNING=false
pgrep -x accountsd >/dev/null 2>&1 && ACCOUNTSD_RUNNING=true
IMAP_OK=false
SMTP_OK=false

if [ -n "$IMAP_HOST" ] && command -v nc >/dev/null 2>&1; then
  section "IMAP connectivity" nc -vz -w 5 "$IMAP_HOST" 993
  nc -z -w 5 "$IMAP_HOST" 993 >/dev/null 2>&1 && IMAP_OK=true
fi

if [ -n "$SMTP_HOST" ] && command -v nc >/dev/null 2>&1; then
  section "SMTP connectivity" nc -vz -w 5 "$SMTP_HOST" 587
  nc -z -w 5 "$SMTP_HOST" 587 >/dev/null 2>&1 && SMTP_OK=true
fi

record "Mail data" "$MAIL_DATA_PRESENT" "$HOME/Library/Mail"
record "Calendar data" "$CALENDAR_DATA_PRESENT" "$HOME/Library/Calendars"
record "Contacts data" "$CONTACTS_DATA_PRESENT" "$HOME/Library/Application Support/AddressBook"
record "accountsd" "$ACCOUNTSD_RUNNING" "Apple account service"
record "IMAP test" "$IMAP_OK" "$IMAP_HOST"
record "SMTP test" "$SMTP_OK" "$SMTP_HOST"

OVERALL="Healthy"
if ! $ACCOUNTSD_RUNNING; then OVERALL="Attention required"; fi

cat > "$JSON" <<EOF
{
  "collected_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "hostname": "$(hostname)",
  "mail_data_present": $MAIL_DATA_PRESENT,
  "calendar_data_present": $CALENDAR_DATA_PRESENT,
  "contacts_data_present": $CONTACTS_DATA_PRESENT,
  "accountsd_running": $ACCOUNTSD_RUNNING,
  "imap_host": "$IMAP_HOST",
  "imap_reachable": $IMAP_OK,
  "smtp_host": "$SMTP_HOST",
  "smtp_reachable": $SMTP_OK,
  "overall_status": "$OVERALL"
}
EOF

printf '\nMail, Calendar and Contacts diagnostics completed: %s\n' "$OUTPUT_DIR" | tee -a "$REPORT"
