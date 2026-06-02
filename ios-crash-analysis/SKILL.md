---
name: ios-crash-analysis
description: >-
  Analyze why a process (an app or an app extension) stopped, crashed, was
  killed, or disconnected on a USB-connected iPhone. Pulls crash reports and the
  unified log archive from the device and distinguishes a hard crash from an
  OOM/Jetsam kill, an OS force-kill, or a clean / user-initiated stop. Use when
  the user says something "crashed", "died", "got killed", "froze", or
  "disconnected" on a connected iPhone, or asks to investigate device-side
  stability or termination.
---

# iOS crash / termination analysis

Diagnose why a **named process on a connected iPhone** ended. Always work from a
specific process/executable name (the user provides it, or infer it from the
project — e.g. an app target or an extension target). Classify the event into
exactly one of:

| Class | Signature |
|---|---|
| **Hard crash** (SIGSEGV/SIGABRT/EXC_*) | a `<Process>-<date>.ips` crash report exists |
| **OOM / Jetsam kill** | a `JetsamEvent-<date>.ips` lists the process as the *killed* one |
| **Force-kill** (watchdog / OS / force-quit) | RunningBoard `received Termination … isUserKill:1` |
| **Clean / user-initiated stop** | no crash report, no Jetsam, `isUserKill:0`, an orderly exit / session disconnect |

> The **absence** of a crash report or Jetsam report is itself diagnostic — it
> rules out a hard crash / OOM. Don't conclude "crash" just because the process
> disappeared.

## Prerequisites

- iPhone connected via USB, **unlocked**, trusting this Mac.
- `libimobiledevice` (`brew install libimobiledevice`) for `idevice_id`,
  `ideviceinfo`, `idevicecrashreport`. Xcode CLT for `/usr/bin/log` and
  `xcrun devicectl`.
- **Root** is required to collect the unified log archive from a device
  (`sudo log collect`). The script prompts, or accepts `--password-file`.

## How to run

`--process` is required. Add `--bundle` and `--subsystem` when known — they
sharpen log matching and surface the app's own error/fault lines.

```bash
SKILL=.claude/skills/ios-crash-analysis/scripts/analyze-ios-crash.sh

# An app
"$SKILL" --process MyApp --bundle com.example.MyApp --hours 6

# An app extension, with its os_log subsystem
"$SKILL" --process MyExtension --bundle com.example.MyApp.ext --subsystem com.example.log

# Crash reports only — no sudo / no log archive
"$SKILL" --process MyApp --skip-logarchive
```

The script prints sectioned output and a **HEURISTIC VERDICT**, and leaves all
artifacts under `/tmp/ios-crash-<timestamp>/` (`device.logarchive`,
`app-events.txt`, `crashreports/`) for re-querying.

When invoked as a skill: run the script, **read every section**, then state the
classification, the exact timestamp and the authoritative log line that proves
it, and — only if it was a genuine fault — the likely cause and fix. Treat the
heuristic verdict as a starting point, not gospel; confirm it against the raw
lines. If no process name is given, ask for it (or infer the target from the
project's app/extension targets) before running.

## Gotchas (encoded in the script — respect them in any manual follow-up)

1. **`log` is aliased in zsh** → always call `/usr/bin/log`.
2. **Never use `log show --start/--end` on a device archive.** Those flags use
   the *Mac's* timezone, not the phone's. A phone in `+0800` read from a Mac in
   `-0700` is offset ~15h and silently matches nothing. Scope collection with
   the relative `--last Nh` (correct on-device) and filter on the embedded
   device-local timestamps with `grep`.
3. **Only default/error/fault levels persist** to a collected archive. `info`/
   `debug` (e.g. an `os_log .info("starting")`) usually aren't there even with
   `--info --debug`. Lean on system daemons (`runningboardd`, `launchd`,
   `kernel`, and any session manager) for ground truth.
4. **`idevicecrashreport -e -k`**: `-e` also pulls `Retired/` + `DiagnosticLogs/`;
   `-k` keeps the device copies (omit `-k` to move/clear them).
5. Crash `.ips` files are JSON: a header line + a body line. Parse the body line.

## Authoritative log lines to look for

- `runningboardd` / observers: `RBS … received Termination … pid:N … isUserKill:0|1`
  — `0` = clean exit, `1` = force SIGKILL.
- `launchd`: `service inactive: <bundle>` (process gone); repeated lookups that
  find no running instance afterward mean nothing restarted it.
- `kernel … memorystatus` / `JetsamEvent` for memory-pressure kills;
  `EXC_RESOURCE` / `*_resource` reports for CPU/wakeups/disk limits.
- `kernel … sandbox.reporting:violation … deny(…)` — denied syscalls. Native
  libraries ported from desktop often trigger benign denials (`process-fork`,
  `/sbin/route`, `/etc/resolv.conf`, `/etc/localtime`); these return `EPERM`
  and are usually background noise, **not** a termination cause.
- **App extensions only:** the host/session manager logs an exit/disconnect
  reason (e.g. a `disconnected with reason …` line). A "plugin/provider
  initiated" reason with `isUserKill:0` and no crash report means the extension
  exited on its own (often the app's own stop path, including a user action).

## Going deeper

Re-query the collected archive directly (note: process-level `info`/`debug` may
be absent — system daemons are the reliable source):

```bash
/usr/bin/log show /tmp/ios-crash-*/device.logarchive \
  --predicate 'process == "MyProcess"' --info --debug --style compact
```

Tips for a thorough pass: build the timeline backward from the last activity
(when did the process last do real work?), confirm whether anything *restarted*
it afterward, and check whether the app has an auto-recovery path that simply
wasn't triggered (e.g. recovery gated on a network transition that never fired).
