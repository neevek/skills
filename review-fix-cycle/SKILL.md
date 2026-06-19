---
name: review-fix-cycle
description: Iterative review-fix loop. Spawn fresh-context read-only reviewers, triage findings, fix only in the main session, validate, and repeat until findings drop below a severity threshold or a pass cap is hit. Use this when you want convergence over multiple passes, not a one-shot review — checking both code correctness and spec compliance (missing or partial requirements, scope creep). Works across native (C/C++/Rust), UI/web (TS/JS), and mobile/desktop (Swift/Kotlin/Java) projects.
---

# review-fix-cycle

Run review-fix passes until remaining findings fall below the stop threshold. This skill runs the shared review loop over a code **diff** — the subject is the diff. Its sibling `review-plan-cycle` does the same for an implementation plan before any code is written.

**REQUIRED SUB-SKILL:** load `review-cycle-core` for the loop mechanics — spawning fresh reviewers, triage discipline, the ledger, the stop rule, and the ADR / ubiquitous-language discipline. This skill supplies only the diff-specific specializations below.

## Change map (core step 1, specialized)

A few lines, captured once before pass 1:

- intent / acceptance goals.
- diff scope (the exact command, see Diff scope).
- changed contracts — any boundary that code or data *outside* this diff depends on, so a break is silent. List the ones this change actually touches; typical kinds: exported/public interfaces, API/RPC shapes (REST/GraphQL/protobuf) and UI component props/events/tokens, cross-language or cross-process boundaries, on-disk/wire formats, persisted or cached state, config/flags, packaged or generated outputs.
- validation commands for the stacks the diff touches (see Validation).
- **spec source** — the originating issue/PRD/spec the diff is supposed to implement (path or contents). If none exists, note it; the Spec axis will skip.

## Two review axes

Each pass spawns reviewers along two **separate** axes. Keep their findings separate so one never masks the other — code that follows every standard but implements the wrong thing fails Spec while passing Correctness, and vice versa.

- **Correctness** — the diff itself: bugs, contracts, lifecycle, native/perf, security, simplicity (the Review checklist). Uses the Reviewer prompt.
- **Spec** — does the diff implement what was asked? Fed the spec source, it reports: **(a)** requirements the spec asked for that are missing or partial; **(b)** behavior in the diff that wasn't asked for (scope creep); **(c)** requirements that look implemented but are wrong — quoting the spec line for each. Uses the Spec reviewer prompt; skips with "no spec available" if the change map names none.

Triage and ledger both axes; do not rerank across axes.

## Diff scope

Pick one scope and put the exact command in the change map:
- a specific commit (most common — the last commit of the current branch): `git show HEAD`, or `git show <ref>` for another commit.
- a whole branch vs its base: `git diff --merge-base origin/main`.
- uncommitted work: `git diff` (working tree) or `git diff --staged`.

Exclude generated/vendored files (build outputs, generated bindings/headers, lockfiles, vendored deps, snapshots). If one changed, review the **source** that produces it, not the artifact.

## Triage states (core triage, specialized)

Mark each finding **accept / reject / needs-verification**, and record why rejected — fresh reviewers guess wrong on `unsafe`, lifetimes, FFI, threading, and on whether a Spec "miss" was intentionally out of scope. For high-impact findings (memory safety, ABI break, data loss, security), spawn at most one more read-only reviewer per pass to confirm before editing.

## Fixing correctness findings (red-capable loop)

Before fixing any finding that asserts **wrong behavior** (a bug, not a style/contract nit), build a **red-capable** check that goes *red* on that specific symptom and *green* once fixed — a failing test at the right seam, a curl/HTTP script, a CLI invocation diffed against known-good, or a throwaway harness. Run it red **first**: a fix you can't watch turn a red check green is unverified, and you risk fixing a nearby thing that isn't the reported finding. For pure contract/packaging/style findings where no behavior is wrong, the Validation commands are enough.

## Comment discipline (when applying fixes)

Applies to every edit the fixer makes in the main session:

- **Default to no comment.** Code should read on its own — clearer names, smaller functions, and removed dead branches beat a comment that explains them.
- A comment is justified **only** when it records something the code cannot show: a non-obvious invariant, a why-not-the-obvious-way, a known hazard or workaround with its cause, or a contract a caller must honor.
- When a comment is warranted, make it **precise** — state the fact, not a narration. No restating what the line does, no "fixed X", no referencing the review/finding, no commented-out code.
- Match the surrounding file's existing comment density and idiom; do not introduce a heavier commenting style than the code already uses.
- A finding that says "add a comment to explain this" is usually a signal to **simplify the code** instead; prefer that, and reject the comment if the simplification removes the confusion.

## Validation

Run the checks for the stacks the diff touches, plus project-specific ones from the change map:

- **Rust** — `cargo build`, `cargo test`, `cargo clippy -- -D warnings`; for FFI confirm `extern "C"`/`#[no_mangle]` symbols and regenerated headers match callers.
- **C/C++** — project build + tests; for shared libs check exported symbols (`nm -D` on Linux, `nm -gU` on macOS) and ABI drift (`abidiff` if available); release/debug parity.
- **TS/JS** — typecheck (`tsc --noEmit`), lint, unit tests, build/bundle for changed deployables.
- **Swift/Kotlin/Java** — platform build + tests; regenerate bindings; verify packaged native libs, manifests, permissions.
- **Cross-cutting** — targeted contract checks: exported symbols, generated files, schema migrations, snapshot output.

## Fix-readiness gate (the fix-loop's completion check)

Symmetric to the plan loop's execution-readiness gate. Before the Stop rule may end the loop, confirm for **every accepted finding**:

- it has a fix applied in the main session;
- a correctness finding has a **regression test at a correct seam** that now passes and was red before the fix — **or** the absence of a correct seam is recorded as residual risk. A too-shallow seam (a unit test that can't reproduce the real call pattern) gives false confidence; say so rather than asserting coverage.
- Validation ran for the touched stacks, with output captured;
- the ledger entry records: `finding → accept/reject (why) → fix → validation → residual risk`.

If any is missing, the loop is not done regardless of finding count: fix the gap in another pass within the cap, otherwise stop and report **not converged** with the gap listed.

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

## Reviewer prompt (base) — Correctness axis

Specialize with the change map, diff-scope command, and scope:

"Read-only review — do not edit files. Run the `<diff-scope command>` to read the change, and you may read the rest of the tree to check how changed contracts are used (e.g. grep for callers of a changed signature) — but run no build/test/lint commands. Review the change against the stated intent and changed contracts. Use the project's domain glossary terms exactly, and respect ADRs in the touched area — don't re-litigate a settled decision; if you think one should be reopened, say so and why.

List actionable findings first, ordered by severity (High/Medium/Low), each with file + line and a one-line justification. Skip style the formatter/linter handles. If unsure a finding is real, mark it `needs-verification` rather than asserting it.

Audit only the areas the diff touches: behavior/mode/path parity; contract mismatches (APIs, FFI/ABI, generated files, serialization, migrations, config defaults, CLI/API compat) — including external callers of a changed contract that weren't updated; packaging (missing/stale artifacts, architecture slices, assets, release/debug divergence); lifecycle/concurrency/resource bugs; native/media risks (memory & resource lifetime, thread ownership, buffering, timing/sync); malformed input, escaping, paths, old saved state, precision/overflow; UI state/navigation/accessibility/responsive when UI changed; missing tests; and simplicity/maintainability.

For a complexity finding, optionally suggest a **minimal fix** (low-risk) and, only if warranted, a **structural refactor** (deeper redesign, with tradeoffs). If nothing is at/above Medium, say so. Do not edit files."

## Spec reviewer prompt (base) — Spec axis

Specialize with the change map, diff-scope command, and spec source:

"Read-only spec review — do not edit files. Run the `<diff-scope command>` to see the change, and read the spec at `<path or contents>`. Report **only** spec-conformance findings, ordered by severity: **(a)** requirements the spec asked for that are missing or partial; **(b)** behavior in the diff that wasn't asked for (scope creep); **(c)** requirements that look implemented but appear wrong. Quote the spec line for each finding, with the file + line in the diff where relevant. Use the project's domain glossary terms exactly. Do not report code-quality issues — that is the other axis. If no spec was provided, reply 'no spec available'. Do not edit files."

## Final output (core skeleton, specialized)

- Passes run and why the loop stopped (threshold met / cap hit / not converged / verification blocked).
- Fix summary + finding ledger (including rejected findings and why).
- Validation commands run and results; fix-readiness gate result.
- Spec-axis result: missing/partial requirements, scope creep, and wrong implementations — or "no spec available".
- Simplicity improvements made, or why none; chosen path (minimal vs structural) when complexity findings existed.
- Open findings below threshold, listed not fixed.
