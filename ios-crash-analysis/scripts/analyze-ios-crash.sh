#!/usr/bin/env bash
#
# analyze-ios-crash.sh — pull crash artifacts + the unified log from a connected
# iPhone and surface *why* a given process stopped: hard crash vs OOM/Jetsam
# kill vs force-kill vs clean / user-initiated stop.
#
# Lessons baked in (the things that bite when doing this by hand):
#   * Always call /usr/bin/log explicitly — zsh aliases `log`.
#   * NEVER use `log show --start/--end` against a device archive: those flags
#     are interpreted in the *Mac's* timezone, not the device's, so a phone in
#     +0800 read from a Mac in -0700 silently matches nothing. We filter on the
#     embedded (device-local) timestamps with grep instead, and scope the
#     collection with the relative `--last Nh`, which is correct on-device.
#   * Only default/error/fault levels persist to a collected archive; info/debug
#     usually won't be there even with --info --debug. Rely on system daemons.
#   * `log collect` from an attached device requires root.
#   * No crash .ips + no JetsamEvent for the process == it did NOT hard-crash
#     and was NOT OOM-killed. That absence is itself a finding.
#
# Usage:
#   analyze-ios-crash.sh --process NAME [--bundle ID] [--subsystem SUBSYS]
#                        [--hours N] [--udid UDID] [--out DIR]
#                        [--password-file FILE] [--skip-logarchive]
#
#   --process NAME       (required) process/executable name as it appears in
#                        crash reports + logs, e.g. "MyApp" or "MyAppExtension".
#   --bundle ID          bundle identifier, improves log matching (optional).
#   --subsystem SUBSYS   the app's os_log subsystem, to surface its own
#                        error/fault lines (optional).
#   --hours N            unified-log window, default 3.
#   --udid UDID          device UDID (auto-detected if omitted).
#   --out DIR            output dir (default /tmp/ios-crash-<timestamp>).
#   --password-file FILE file containing the sudo password (for `log collect`).
#   --skip-logarchive    crash reports only; skip the root-requiring log collect.

set -uo pipefail

PROCESS=""
BUNDLE=""
SUBSYSTEM=""
HOURS=3
UDID=""
OUT=""
PW_FILE=""
SKIP_LOGARCHIVE=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --process)       PROCESS="$2"; shift 2 ;;
    --bundle)        BUNDLE="$2"; shift 2 ;;
    --subsystem)     SUBSYSTEM="$2"; shift 2 ;;
    --hours)         HOURS="$2"; shift 2 ;;
    --udid)          UDID="$2"; shift 2 ;;
    --out)           OUT="$2"; shift 2 ;;
    --password-file) PW_FILE="$2"; shift 2 ;;
    --skip-logarchive) SKIP_LOGARCHIVE=1; shift ;;
    -h|--help)       grep '^#' "$0" | sed -E 's/^# ?//'; exit 0 ;;
    *) echo "unknown arg: $1" >&2; exit 2 ;;
  esac
done

if [[ -z "$PROCESS" ]]; then
  echo "error: --process NAME is required (the process/executable name as it" >&2
  echo "       appears in crash reports and logs). See --help." >&2
  exit 2
fi

# Match patterns: prefer the bundle id when given, always include the process.
BUNDLE_PAT="${BUNDLE:-$PROCESS}"

STAMP="$(date +%Y%m%d-%H%M%S)"
OUT="${OUT:-/tmp/ios-crash-$STAMP}"
mkdir -p "$OUT/crashreports"
LOG="/usr/bin/log"

section() { printf '\n========== %s ==========\n' "$1"; }
have()    { command -v "$1" >/dev/null 2>&1; }
# Print captured grep output, or a fallback when it's empty. Use this instead of
# `grep ... | tail | || echo "(none)"`: a trailing `|| echo` after a pipe never
# fires, because `tail`/`head` exit 0 even on empty input.
emit()    { [[ -n "$1" ]] && printf '%s\n' "$1" || echo "${2:-(none)}"; }

# ---------------------------------------------------------------------------
section "DEVICE"
if [[ -z "$UDID" ]] && have idevice_id; then UDID="$(idevice_id -l 2>/dev/null | head -1)"; fi
if [[ -z "$UDID" ]]; then
  echo "No device UDID. Plug in + unlock the iPhone, trust this Mac, and retry."
  have xcrun && xcrun devicectl list devices 2>/dev/null
fi
echo "UDID: ${UDID:-<none>}"
if have ideviceinfo; then
  echo "Device TZ: $(ideviceinfo -k TimeZone 2>/dev/null || echo '?')"
  echo "OS: $(ideviceinfo -k ProductVersion 2>/dev/null || echo '?')  Model: $(ideviceinfo -k ProductType 2>/dev/null || echo '?')"
fi
echo "Mac time : $(date '+%Y-%m-%d %H:%M:%S %z')"
echo "Window   : last ${HOURS}h"
echo "Target   : process='$PROCESS' bundle='${BUNDLE:-<none>}' subsystem='${SUBSYSTEM:-<none>}'"
echo "Output   : $OUT"

# ---------------------------------------------------------------------------
section "CRASH REPORTS (.ips)"
# -e extracts (incl. Retired/DiagnosticLogs), -k keeps the device copies.
if have idevicecrashreport; then
  idevicecrashreport -e -k "$OUT/crashreports" >/dev/null 2>&1
  echo "Pulled into $OUT/crashreports"
else
  echo "idevicecrashreport not found (brew install libimobiledevice). Skipping."
fi

TODAY="$(date +%Y-%m-%d)"
echo
echo "-- crash reports naming the process (any date) --"
grep -ril -- "$PROCESS" "$OUT/crashreports" 2>/dev/null | sed "s#$OUT/crashreports/##" || true
echo
echo "-- process-specific crash .ips dated TODAY ($TODAY) --"
HARD_CRASH="$(find "$OUT/crashreports" -name "*${PROCESS}*${TODAY}*.ips" \
  -not -name 'JetsamEvent*' -not -name '*cpu_resource*' \
  -not -name '*diskwrites*' -not -name '*wakeups*' 2>/dev/null || true)"
if [[ -n "$HARD_CRASH" ]]; then echo "$HARD_CRASH"; else echo "(none — no signal/exception crash report for the process today)"; fi

# JetsamEvent victim analysis (was the process OOM-killed, or just a survivor?)
echo
echo "-- JetsamEvent reports: was '$PROCESS' the KILLED process? --"
OOM_TODAY=0; FOUND_JETSAM=0
while IFS= read -r jf; do
  [[ -z "$jf" ]] && continue
  FOUND_JETSAM=1
  je="$(python3 - "$jf" "$PROCESS" "$TODAY" <<'PY'
import json, sys, os
f, proc, today = sys.argv[1], sys.argv[2], sys.argv[3]
raw = open(f, errors="replace").read()
try:
    body = json.loads(raw[raw.index("\n")+1:])
except Exception:
    print(f"  {os.path.basename(f)}: (unparseable)"); sys.exit(0)
date = body.get("date","")
procs = body.get("processes") or []
victims = [p for p in procs if p.get("reason") or p.get("killDelta")]
ours = [p for p in procs if proc in (p.get("name") or "")]
ps = body.get("pageSize", 16384)
def mb(p):
    return f"rss~{(p.get('rpages') or 0)*ps//(1024*1024)}MB peak~{(p.get('lifetimeMax') or 0)*ps//(1024*1024)}MB"
killed_names = {p.get("name") for p in victims}
flag = "  <-- TODAY" if date.startswith(today) else ""
print(f"  {os.path.basename(f)} (largestProcess={body.get('largestProcess')}){flag}")
for p in ours:
    status = "KILLED" if p in victims else "survived"
    print(f"      {proc}: {status} ({mb(p)}) states={p.get('states')} reason={p.get('reason','-')}")
if proc in killed_names and date.startswith(today):
    print("      >>> OOM/JETSAM-KILLED TODAY <<<")
PY
)"
  printf '%s\n' "$je"
  [[ "$je" == *">>> OOM"* ]] && OOM_TODAY=1
done < <(find "$OUT/crashreports" -name "JetsamEvent*.ips" 2>/dev/null)
[[ "$FOUND_JETSAM" -eq 0 ]] && echo "  (no JetsamEvent reports pulled)"

# ---------------------------------------------------------------------------
ARCHIVE="$OUT/device.logarchive"
if [[ "$SKIP_LOGARCHIVE" -eq 1 ]]; then
  section "UNIFIED LOG"; echo "Skipped (--skip-logarchive)."
elif [[ -z "$UDID" ]]; then
  section "UNIFIED LOG"; echo "No UDID — cannot collect log archive."
else
  section "UNIFIED LOG COLLECT (needs root)"
  if [[ -n "$PW_FILE" && -s "$PW_FILE" ]]; then
    sudo -S -p '' "$LOG" collect --device-udid "$UDID" --last "${HOURS}h" --output "$ARCHIVE" < "$PW_FILE" 2>&1 | tail -3
  else
    echo "(running 'sudo log collect' — enter your Mac password if prompted; or pass --password-file)"
    sudo "$LOG" collect --device-udid "$UDID" --last "${HOURS}h" --output "$ARCHIVE" 2>&1 | tail -3
  fi
fi

if [[ -d "$ARCHIVE" ]]; then
  # One broad pull of everything touching the app, reused by all filters below.
  ALL="$OUT/app-events.txt"
  PRED="(process CONTAINS \"$PROCESS\") OR (eventMessage CONTAINS \"$BUNDLE_PAT\") OR (eventMessage CONTAINS \"$PROCESS\")"
  [[ -n "$SUBSYSTEM" ]] && PRED="$PRED OR (eventMessage CONTAINS \"$SUBSYSTEM\")"
  "$LOG" show "$ARCHIVE" --predicate "$PRED" --style compact --info --debug 2>/dev/null > "$ALL"
  echo "App-related log events: $(wc -l < "$ALL") (saved to $ALL)"

  section "PROCESS TERMINATION / EXIT (RunningBoard)"
  # isUserKill:1 => force SIGKILL (OOM/watchdog/force-quit). isUserKill:0 => clean exit.
  emit "$(grep -iE "received Termination|AppMonitor notification.*Terminated|isUserKill|setApplicationRunningState.* exited" "$ALL" \
    | grep -iv "Received state update" | tail -20)"

  section "EXIT / LAUNCH DAEMONS (launchd / runningboardd)"
  emit "$(grep -iE "launchd.*(service (in)?active|exited|spawn)|runningboardd.*(terminat|kill|exit)" "$ALL" | tail -15)"

  section "APP-EXTENSION / XPC SESSION (if the process is an extension)"
  # e.g. a Network Extension logs its disconnect reason here; harmless if empty.
  emit "$(grep -iE "disconnected with reason|did detach from IPC|StateStopping|StateDisconnect|extension.*(invalidat|terminat)|XPC.*interrupt" "$ALL" | tail -20)" \
    "(none — not an extension, or no session events)"

  section "JETSAM / MEMORYSTATUS / RESOURCE referencing the process"
  emit "$(grep -iE "jetsam|memorystatus|EXC_RESOURCE|highwater|per-process-limit|wakeups|cpu_resource" "$ALL" \
    | grep -i "$PROCESS" | tail -20)" "(none referencing $PROCESS — i.e. not memory/CPU-limit killed)"

  if [[ -n "$SUBSYSTEM" ]]; then
    section "PROCESS OWN ERROR/FAULT LOGS (subsystem $SUBSYSTEM)"
    "$LOG" show "$ARCHIVE" --predicate "subsystem == \"$SUBSYSTEM\"" --style compact 2>/dev/null \
      | grep -v "^$" | tail -25
    echo "(empty here == no error/fault from app code before it stopped; orderly shutdown)"
  fi

  section "SANDBOX VIOLATIONS by the process (denied syscalls — usually harmless EPERM)"
  emit "$(grep -E "sandbox.*$PROCESS|$PROCESS.* deny\(" "$ALL" \
    | sed -E 's/^([0-9-]+ [0-9:]{8}).*deny\(([0-9])\) ([^ ]+ ?[^ ]*).*/\1  deny \3/' \
    | sort | uniq -c | sort -rn | head -20)"

  section "LAST APP-RELATED ACTIVITY before the end of the window"
  grep -vE "Received state update" "$ALL" | tail -15
else
  [[ "$SKIP_LOGARCHIVE" -eq 0 ]] && echo "No archive collected; log-based sections skipped."
fi

# ---------------------------------------------------------------------------
section "HEURISTIC VERDICT"
verdict="INCONCLUSIVE — inspect the sections above."
if [[ -n "$HARD_CRASH" ]]; then
  verdict="HARD CRASH (signal/exception). Symbolicate the .ips: $HARD_CRASH"
elif [[ -d "$ARCHIVE" ]]; then
  reason_line="$(grep -iE "disconnected with reason" "$ALL" 2>/dev/null | tail -1)"
  grep -qiE "isUserKill.?:.?1" "$ALL" 2>/dev/null && force_killed=1 || force_killed=0
  shopt -s nocasematch
  if [[ "$OOM_TODAY" -eq 1 ]]; then
    verdict="OOM / JETSAM KILL — see the JETSAM section."
  elif [[ "$force_killed" -eq 1 ]]; then
    verdict="FORCE-KILLED (isUserKill:1) — OS SIGKILL: likely memory/CPU watchdog or user force-quit. Cross-check the JETSAM section."
  elif [[ "$reason_line" == *user* ]]; then
    verdict="USER-INITIATED STOP — $reason_line"
  elif [[ "$reason_line" == *initiated* ]]; then
    verdict="CLEAN STOP (initiator-side disconnect) — the process asked to stop and exited normally (no crash, no OOM): $reason_line"
  elif [[ "$reason_line" == *network* ]]; then
    verdict="NETWORK-DRIVEN DISCONNECT — $reason_line"
  elif [[ -n "$reason_line" ]]; then
    verdict="SESSION DISCONNECT — $reason_line"
  else
    verdict="No crash report, no Jetsam kill, no force-kill found. Most likely a clean exit/stop. Re-read the TERMINATION + DAEMON sections."
  fi
  shopt -u nocasematch
fi
echo "$verdict"
echo
echo "Artifacts in: $OUT"
echo "Re-query the archive freely, e.g.:"
echo "  /usr/bin/log show \"$ARCHIVE\" --predicate 'process == \"$PROCESS\"' --info --debug --style compact"
