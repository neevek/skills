---
name: review-fix-cycle
description: Iterative review-fix loop. Spawn fresh-context read-only reviewers, triage findings, fix only in the main session, validate, and repeat until findings drop below a severity threshold or a pass cap is hit. Use this when you want convergence over multiple passes, not a one-shot review. Works across native (C/C++/Rust), UI/web (TS/JS), and mobile/desktop (Swift/Kotlin/Java) projects.
---

# review-fix-cycle

Run review-fix passes until remaining findings fall below the stop threshold. Each pass uses a **fresh-context, read-only** reviewer so the session that wrote the code never reviews its own reasoning.

## Loop

1. **Change map** (main session, once before pass 1) — a few lines capturing:
   - intent / acceptance goals.
   - diff scope (the exact command, see below).
   - changed contracts — any boundary that code or data *outside* this diff depends on, so a break is silent. List the ones this change actually touches; typical kinds: exported/public interfaces, API/RPC shapes (REST/GraphQL/protobuf) and UI component props/events/tokens, cross-language or cross-process boundaries, on-disk/wire formats, persisted or cached state, config/flags, packaged or generated outputs.
   - validation commands for the stacks the diff touches (see Validation).

2. **Spawn a fresh reviewer** (read-only, cannot edit). Pass it the change map, the diff-scope command, and the Reviewer prompt. The reviewer runs the diff command itself — don't paste large diffs inline. For cross-stack diffs, spawn several reviewers with disjoint scopes (see Scopes).
   - **Claude Code**: the Agent/Task subagent tool (not the to-do `TaskCreate`) with `subagent_type: "Explore"`. Fan out by putting multiple tool calls in one message. The subagent's return value is its findings — triage them in the main session.
   - **Codex**: spawn an `explorer` with `fork_context: false` and a self-contained prompt containing the change map, diff-scope command, Reviewer prompt, and assigned scope. Fan out by spawning one reviewer per disjoint scope; collect their final messages and triage them in the main session. Fresh means a separate agent, not the current session reviewing its own diff.

3. **Triage** in the main session — never blind-apply. Mark each finding accept / reject / needs-verification, and record why rejected (fresh reviewers guess wrong on `unsafe`, lifetimes, FFI, threading). For high-impact findings (memory safety, ABI break, data loss, security), spawn at most one more read-only reviewer per pass to confirm before editing.

4. **Fix** accepted findings — main session only.

5. **Validate** (see Validation), then append to the ledger: `finding → accept/reject (why) → fix → validation → residual risk`.

6. **Repeat** with a new fresh reviewer, passing the ledger so it checks prior fixes and hunts new issues. Stop per the Stop rule.

## Diff scope

Pick one scope and put the exact command in the change map:
- a specific commit (most common — the last commit of the current branch): `git show HEAD`, or `git show <ref>` for another commit.
- a whole branch vs its base: `git diff --merge-base origin/main`.
- uncommitted work: `git diff` (working tree) or `git diff --staged`.

Exclude generated/vendored files (build outputs, generated bindings/headers, lockfiles, vendored deps, snapshots). If one changed, review the **source** that produces it, not the artifact.

## Stop rule

Stop when **either** the reviewer reports nothing at/above the threshold (default: no **High**; remaining nits are listed, not fixed) **or** the pass cap is hit (default **4**). Thresholds and cap are overridable in the change map. A *new* finding (even another High) is normal — keep going within the cap. Only true oscillation — the same issue ping-ponging back after its fix — should stop the loop early. If passes oscillate or the cap is hit with open High items, stop and report **not converged** with the open list. If a reviewer can't run (quota/tool failure), report **verification blocked**, not complete.

## Review checklist (single source)

Check only the areas the diff touches:

- **Behavior parity** — every mode/path/platform affected, including old behavior that must stay.
- **Contracts** — signatures, public APIs, FFI/ABI, generated bindings, serialization, migrations, config defaults, CLI/API compatibility.
- **Build/packaging** — compiled libs, architecture/platform slices, bundled assets, plugins, manifests, release/debug divergence.
- **Lifecycle/concurrency** — init/shutdown, pause/resume, cancellation, threading/async, ownership, resource cleanup, lock ordering, races.
- **Native/perf-sensitive** (C/C++/Rust/media) — memory safety, lifetimes, `unsafe`, error ownership; GPU/decoder/audio/video resource lifetime, frame timing/sync, backpressure, buffering, latency.
- **Data/input** — parsing, escaping, Unicode, paths, missing/malformed input, old saved state, precision/overflow.
- **Security/privacy** — auth/secrets, certs, permissions, sandboxing, untrusted input, dependency/plugin loading.
- **UI** (when changed) — navigation, state persistence, disabled/loading/error states, accessibility, responsive layout, text overflow, stale controls.
- **Tests** — missing coverage for changed contracts, edge cases, target platforms.
- **Simplicity** — over-complex logic, needless abstraction, avoidable branching/state, readability even when correct.

## Scopes (for multi-reviewer fan-out)

- **Native (C/C++/Rust)** — memory safety, ownership/lifetimes, `unsafe`, FFI/ABI, threading, error handling, feature flags, build outputs.
- **Media/graphics** — decode/render/audio pipelines, buffer ownership, frame timing/sync, GPU/decoder resource lifecycle, backend differences.
- **Mobile/desktop** — Swift/Kotlin/Java lifecycle, persistence, permissions, platform services/viewmodels/controllers, packaged native libs.
- **Web/UI** — TS/JS types, async state, routing, API contracts, forms, accessibility, responsive behavior, build output.
- **Packaging/contracts** — artifacts, generated bindings, schemas, migrations, platform filters, compatibility.

With one reviewer, fold the relevant scopes into one prompt.

## Validation

Run the checks for the stacks the diff touches, plus project-specific ones from the change map:

- **Rust** — `cargo build`, `cargo test`, `cargo clippy -- -D warnings`; for FFI confirm `extern "C"`/`#[no_mangle]` symbols and regenerated headers match callers.
- **C/C++** — project build + tests; for shared libs check exported symbols (`nm -D` on Linux, `nm -gU` on macOS) and ABI drift (`abidiff` if available); release/debug parity.
- **TS/JS** — typecheck (`tsc --noEmit`), lint, unit tests, build/bundle for changed deployables.
- **Swift/Kotlin/Java** — platform build + tests; regenerate bindings; verify packaged native libs, manifests, permissions.
- **Cross-cutting** — targeted contract checks: exported symbols, generated files, schema migrations, snapshot output.

## Reviewer prompt (base)

Specialize with the change map, diff-scope command, and scope:

"Read-only review — do not edit files, and run only the `<diff-scope command>` to read the change (no build/test/lint commands). Run `<diff-scope command>` to see the change. Review it against the stated intent and changed contracts. List actionable findings first, ordered by severity (High/Medium/Low), each with file + line and a one-line justification. Skip style the formatter/linter handles. If unsure a finding is real, mark it `needs-verification` rather than asserting it.

Audit only the areas the diff touches: behavior/mode/path parity; contract mismatches (APIs, FFI/ABI, generated files, serialization, migrations, config defaults, CLI/API compat); packaging (missing/stale artifacts, architecture slices, assets, release/debug divergence); lifecycle/concurrency/resource bugs; native/media risks (memory & resource lifetime, thread ownership, buffering, timing/sync); malformed input, escaping, paths, old saved state, precision/overflow; UI state/navigation/accessibility/responsive when UI changed; missing tests; and simplicity/maintainability.

For a complexity finding, optionally suggest a **minimal fix** (low-risk) and, only if warranted, a **structural refactor** (deeper redesign, with tradeoffs). If nothing is at/above Medium, say so. Do not edit files."

## Final output

- Passes run and why the loop stopped (threshold met / cap hit / not converged / verification blocked).
- Fix summary + finding ledger (including rejected findings and why).
- Validation commands run and results.
- Simplicity improvements made, or why none; chosen path (minimal vs structural) when complexity findings existed.
- Open findings below threshold, listed not fixed.
