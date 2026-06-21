#!/bin/bash
set -u

DO_REPAIR=false
DRY_RUN=false
ASSUME_YES=false
LAUNCH_APPS=false
OUTPUT_DIR=""
FAILURES=0
ACTIONS=0

usage() {
  cat <<'EOF'
Usage: mail_calendar_contacts_repair.sh [--repair] [--dry-run] [--yes] [--launch-apps] [--output DIR]

Default mode verifies Mail, Calendar, Contacts and account sync services.
--repair       Restart the related applications and background sync services.
--dry-run      Show each repair action without changing the Mac.
--yes          Skip the confirmation prompt.
--launch-apps  Relaunch Mail, Calendar and Contacts after the repair.
--output DIR   Save logs and verification output in DIR.
EOF
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --repair) DO_REPAIR=true; shift ;;
    --dry-run) DRY_RUN=true; shift ;;
    --yes) ASSUME_YES=true; shift ;;
    --launch-apps) LAUNCH_APPS=true; shift ;;
    --output) OUTPUT_DIR="${2:-}"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown argument: $1" >&2; usage; exit 2 ;;
  esac
done

[ "$(uname -s)" = "Darwin" ] || { echo "This tool must run on macOS." >&2; exit 1; }

STAMP="$(date +%Y%m%d_%H%M%S)"
OUTPUT_DIR="${OUTPUT_DIR:-./mail-calendar-contacts-repair-$STAMP}"
mkdir -p "$OUTPUT_DIR"
LOG="$OUTPUT_DIR/repair.log"
VERIFY="$OUTPUT_DIR/verification.txt"
: > "$LOG"

log() {
  printf '%s %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*" | tee -a "$LOG"
}

confirm() {
  $ASSUME_YES && return 0
  printf '%s [y/N]: ' "$1"
  read -r answer
  case "$answer" in y|Y|yes|YES) return 0 ;; *) return 1 ;; esac
}

run_action() {
  description="$1"
  shift
  ACTIONS=$((ACTIONS + 1))
  log "$description"
  if $DRY_RUN; then
    printf 'DRY-RUN:' >> "$LOG"
    for arg in "$@"; do printf ' %q' "$arg" >> "$LOG"; done
    printf '\n' >> "$LOG"
    return 0
  fi
  if "$@" >> "$LOG" 2>&1; then
    log "SUCCESS: $description"
    return 0
  fi
  FAILURES=$((FAILURES + 1))
  log "WARNING: $description failed"
  return 1
}

quit_app() {
  app_name="$1"
  if pgrep -x "$app_name" >/dev/null 2>&1; then
    run_action "Quitting $app_name" /usr/bin/osascript -e "tell application \"$app_name\" to quit" || true
  fi
}

restart_process() {
  process_name="$1"
  if pgrep -x "$process_name" >/dev/null 2>&1; then
    run_action "Restarting $process_name" /usr/bin/killall "$process_name" || true
  else
    log "INFO: $process_name is not running; macOS will start it on demand."
  fi
}

verify() {
  {
    echo "Collected: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
    echo "Host: $(hostname)"
    echo
    echo "Application and sync processes:"
    ps -Ao pid,user,etime,comm,args | grep -Ei 'Mail|Calendar|Contacts|accountsd|calaccessd|CalendarAgent|contactsd' | grep -v grep || true
    echo
    echo "Data folders:"
    for path in "$HOME/Library/Mail" "$HOME/Library/Calendars" "$HOME/Library/Application Support/AddressBook"; do
      if [ -d "$path" ]; then
        ls -ld "$path"
      else
        echo "Not found: $path"
      fi
    done
  } > "$VERIFY" 2>&1
}

verify

if ! $DO_REPAIR; then
  log "Verification-only mode completed. Use --repair to restart the affected services."
  exit 0
fi

if ! confirm "Restart Mail, Calendar, Contacts and their sync services?"; then
  log "Repair cancelled by user."
  exit 0
fi

quit_app "Mail"
quit_app "Calendar"
quit_app "Contacts"
if ! $DRY_RUN; then sleep 3; fi

restart_process "accountsd"
restart_process "calaccessd"
restart_process "CalendarAgent"
restart_process "contactsd"
restart_process "Mail"

if $LAUNCH_APPS; then
  run_action "Launching Mail" /usr/bin/open -a Mail || true
  run_action "Launching Calendar" /usr/bin/open -a Calendar || true
  run_action "Launching Contacts" /usr/bin/open -a Contacts || true
fi

if ! $DRY_RUN; then sleep 5; fi
verify

if [ "$FAILURES" -gt 0 ]; then
  log "Repair completed with $FAILURES warning(s). Review $LOG and $VERIFY."
  exit 1
fi

log "Repair completed successfully. Actions performed: $ACTIONS"
exit 0
