---
name: review-fix-cycle
description: Iterative review-fix loop. Spawn fresh-context read-only reviewers, triage findings, fix only in the main session, validate, and repeat until findings drop below a severity threshold or a pass cap is hit. Use this when you want convergence over multiple passes, not a one-shot review — checking code correctness, evidence-backed performance risks, and spec compliance (missing or partial requirements, scope creep). Works across native (C/C++/Rust), UI/web (TS/JS), and mobile/desktop (Swift/Kotlin/Java) projects.
---

# review-fix-cycle

Run review-fix passes over a code **diff** until remaining findings fall below the stop threshold. Sibling `review-plan-cycle` does the same for an implementation plan before any code is written.

**REQUIRED SUB-SKILL:** load `review-cycle-core` for the loop mechanics — spawning, the one-shot report contract, triage discipline, the ledger, the stop rule, comment discipline, and ADR / ubiquitous-language discipline. This skill supplies only the diff-specific specializations below.

## Change map (core step 1, specialized)

A few lines, captured once before pass 1:

- intent / acceptance goals.
- diff scope (the exact command, see Diff scope).
- changed contracts — any boundary that code or data *outside* this diff depends on, so a break is silent; list the ones actually touched. Typical kinds: exported/public interfaces, API/RPC shapes (REST/GraphQL/protobuf), UI component props/events/tokens, cross-language or cross-process boundaries, on-disk/wire formats, persisted or cached state, config/flags, packaged or generated outputs.
- validation commands for the stacks the diff touches (see Validation).
- **performance context, when touched** — the affected hot path or scaling boundary; representative workload; relevant metric or budget (latency/throughput/frame time, CPU, allocations/memory, I/O, battery, bundle/binary size); known baseline and a reproducible measurement command. If no budget or baseline exists, say so instead of inventing one.
- **spec source** — the originating issue/PRD/spec the diff implements (path or contents). If none is written, the Spec axis runs against the intent/acceptance goals above instead; skip that axis only when neither exists.

## Two review axes

Each pass spawns reviewers along two **separate** axes; keep their findings separate so one never masks the other — code that follows every standard but implements the wrong thing fails Spec while passing Correctness, and vice versa. Triage and ledger both axes; do not rerank across them.

- **Correctness** — the diff itself: bugs, contracts, lifecycle, evidence-backed performance risks, security, simplicity. Performance stays on this axis so a specialist cannot mask ordinary correctness findings. Uses the Reviewer prompt with the injected Review checklist.
- **Spec** — does the diff implement what was asked? Uses the Spec reviewer prompt, fed the spec source (or the intent fallback).

## Diff scope

Pick one scope and put the exact command in the change map:

- a specific commit (most common — the current branch's last commit): `git show HEAD`, or `git show <ref>`.
- a whole branch vs its base: `git diff --merge-base origin/main`.
- uncommitted work: `git diff` (working tree) or `git diff --staged`.

Exclude generated/vendored files (build outputs, generated bindings/headers, lockfiles, vendored deps, snapshots); if one changed, review the **source** that produces it, not the artifact.

## Triage states (core triage, specialized)

Mark each finding **accept / reject / needs-verification**, recording why rejected — fresh reviewers guess wrong on `unsafe`, lifetimes, FFI, threading, and on whether a Spec "miss" was intentionally out of scope. High-impact findings (memory safety, ABI break, data loss, security) get the core's one confirming reviewer before editing.

## Fixing correctness findings (red-capable loop)

Before fixing any finding that asserts **wrong behavior** (a bug, not a style/contract nit), build a **red-capable** check that goes *red* on that specific symptom and *green* once fixed — a failing test at the right seam, a curl/HTTP script, a CLI invocation diffed against known-good, or a throwaway harness — and run it red **first**: a fix you can't watch turn red-to-green is unverified, and you risk fixing a nearby thing that isn't the reported finding. For pure contract/packaging/style findings where no behavior is wrong, the Validation commands are enough.

## Performance findings (conditional, evidence-gated)

Performance review is useful only where the diff can plausibly affect a hot path, a scaling boundary, or an explicit resource budget. Do not force a performance finding on every diff and do not trade clarity for hypothetical micro-optimizations.

A static reviewer may identify a **performance risk**, but may call it a confirmed regression only when the change map already supplies directly applicable measurements. Every performance finding must state:

- **mechanism** — the changed operation and why it adds work, waiting, contention, copying/allocation, I/O, rendering, or worse scaling;
- **hotness evidence** — the call site, frequency, input-size relationship, real-time path, or stated budget that makes the mechanism material;
- **expected symptom and metric** — what should move (for example p95 latency, frame time, allocations/frame, peak RSS, requests, wakeups, or bundle bytes);
- **verification** — a representative benchmark/profile/trace and the comparison needed to accept or reject it.

If the mechanism is plausible but hotness or material impact is unknown, mark it `needs-verification`; if it is merely a possible micro-optimization on a cold or unknown path, omit it. Map severity onto the core rubric consistently: **High** only when evidence shows wrong behavior such as an SLO/budget breach, missed real-time deadline, hang, or OOM; **Medium** for a credible material regression or unbounded scaling hazard on a demonstrated hot path; **Low** for measured minor regressions that do not threaten a contract. Speculation is not raised as a finding.

`needs-verification` is not a terminal disposition for an at/above-threshold performance finding. During the current pass's main-session triage, run the proposed measurement and convert it to **accept** or **reject** before the ledger update. If a representative measurement cannot be run or constructed, stop as **verification blocked / not converged** with the missing workload, environment, or tool recorded; do not carry an unresolved material risk through later passes or call the cycle complete.

The main session verifies an accepted performance risk before optimizing it:

1. Use a release-equivalent build and the same representative workload, data, configuration, and machine/runtime conditions before and after the fix.
2. Warm up where relevant and take enough repeated samples to expose noise; report the statistic appropriate to the contract (commonly median plus p95/p99 or a range), not a single wall-clock run.
3. Compare against the pre-change baseline or explicit budget. If a performance contract is breached, make that check red on the reviewed change and green after the fix. Otherwise record the before/after measurement and confidence without inventing a pass/fail threshold.
4. Add an automated performance guard only when the workload and environment are stable enough to avoid a flaky test. Otherwise preserve a reproducible benchmark/profile command and record the residual regression risk.

Performance remains part of the Correctness ledger; do not create a permanent third review axis. For Full-tier changes, a specialist triggered by the change map joins the initial fan-out. If the general reviewer first surfaces a credible mechanism, finish that pass atomically — triage, act, and update the ledger — then schedule the specialist in the next pass.

## Comment discipline

Every edit the fixer makes follows the core skill's shared **Comment discipline** — default no comment; only a fact the code cannot show; precise, ~1–2 lines, decided on the first write.

## Validation

Run the checks for the stacks the diff touches, plus project-specific ones from the change map:

- **Rust** — `cargo build`, `cargo test`, `cargo clippy -- -D warnings`; for FFI confirm `extern "C"`/`#[no_mangle]` symbols and regenerated headers match callers.
- **C/C++** — project build + tests; for shared libs check exported symbols (`nm -D` on Linux, `nm -gU` on macOS) and ABI drift (`abidiff` if available); release/debug parity.
- **TS/JS** — typecheck (`tsc --noEmit`), lint, unit tests, build/bundle for changed deployables.
- **Swift/Kotlin/Java** — platform build + tests; regenerate bindings; verify packaged native libs, manifests, permissions.
- **Cross-cutting** — targeted contract checks: exported symbols, generated files, schema migrations, snapshot output.
- **Performance, when a risk was accepted** — run the measurement from the performance context, capture before/after results and noise, and profile/trace the claimed mechanism when feasible. Build/test success alone does not validate a performance fix.

## Fix-readiness gate (the fix-loop's completion check)

Symmetric to the plan loop's execution-readiness gate. Before the Stop rule may end the loop, confirm for **every accepted finding**:

- it has a fix applied in the main session;
- a non-performance correctness finding has a **regression test at a correct seam** that now passes and was red before the fix — **or** the absence of a correct seam is recorded as residual risk. A too-shallow seam (a unit test that can't reproduce the real call pattern) gives false confidence; say so rather than asserting coverage.
- an accepted performance finding has representative before/after measurements; a breached performance contract has a red-to-green budget check; and an automated guard exists only when it can be stable — otherwise the reproducible measurement method and residual risk are recorded.
- Validation ran for the touched stacks, with output captured;
- the ledger entry records: `finding → accept/reject (why) → fix → validation → residual risk`.

If any is missing, the loop is not done regardless of finding count: fix the gap in another pass within the cap, otherwise stop and report **not converged** with the gap listed.

## Review checklist (single source — inject into the Correctness prompt)

Check only the areas the diff touches:

- **Behavior parity** — every mode/path/platform affected, including old behavior that must stay.
- **Contracts** — signatures, public APIs, FFI/ABI, generated bindings, serialization, migrations, config defaults, CLI/API compatibility — including external callers of a changed contract that weren't updated.
- **Build/packaging** — compiled libs, architecture/platform slices, bundled assets, plugins, manifests, release/debug divergence.
- **Lifecycle/concurrency** — init/shutdown, pause/resume, cancellation, threading/async, ownership, resource cleanup, lock ordering, races.
- **Native/media safety** (C/C++/Rust/media) — memory safety, lifetimes, `unsafe`, error ownership; GPU/decoder/audio/video resource lifetime and frame timing/sync.
- **Performance, when touched** — accidental complexity growth; repeated copying/allocation/serialization; N+1 or redundant network/disk/database work; blocking or serialized work in async/UI paths; lock contention; excessive renders/layout; ineffective cache use; unbounded queues/buffers; backpressure; startup, bundle/binary, CPU, memory, battery, throughput, or latency regressions. Apply the Performance findings evidence gate; do not report generic “could be faster” advice.
- **Data/input** — parsing, escaping, Unicode, paths, missing/malformed input, old saved state, precision/overflow.
- **Security/privacy** — auth/secrets, certs, permissions, sandboxing, untrusted input, dependency/plugin loading.
- **UI** (when changed) — navigation, state persistence, disabled/loading/error states, accessibility, responsive layout, text overflow, stale controls.
- **Tests** — missing coverage for changed contracts, edge cases, target platforms.
- **Simplicity** — over-complex logic, needless abstraction, avoidable branching/state, readability even when correct.
- **Comments** — comments that narrate what the code already states, restate the change, or reference this review/task (Low — prefer deleting the comment or simplifying the code over rewording it).

## Scopes (for multi-reviewer fan-out)

- **Native (C/C++/Rust)** — memory safety, ownership/lifetimes, `unsafe`, FFI/ABI, threading, error handling, feature flags, build outputs.
- **Media/graphics** — decode/render/audio pipelines, buffer ownership, frame timing/sync, GPU/decoder resource lifecycle, backend differences.
- **Mobile/desktop** — Swift/Kotlin/Java lifecycle, persistence, permissions, platform services/viewmodels/controllers, packaged native libs.
- **Web/UI** — TS/JS types, async state, routing, API contracts, forms, accessibility, responsive behavior, build output.
- **Packaging/contracts** — artifacts, generated bindings, schemas, migrations, platform filters, compatibility.
- **Performance (conditional)** — the performance mechanisms relevant to any stack, plus whether the supplied workload, metric/budget, and validation method can confirm material impact. Use only for a performance-sensitive diff or a credible risk surfaced during the pass.

With one reviewer, fold the relevant scopes into one prompt.

## Reviewer prompt (base) — Correctness axis

Specialize with the change map, diff-scope command, and scope; inject the Review checklist, severity rubric, and one-shot report contract:

"Read-only review — do not edit files. Run `<diff-scope command>` to read the change; you may read the rest of the tree to check how changed contracts are used (e.g. grep for callers of a changed signature), but run no build/test/lint commands. Review the change against the stated intent and changed contracts. Use the project's domain glossary terms exactly, and respect ADRs in the touched area — don't re-litigate a settled decision; if you think one should be reopened, say so and why.

List all actionable findings first — the injected one-shot report contract applies — ordered by severity per the injected rubric (High/Medium/Low), each with file + line and a one-line justification. Audit only the areas the diff touches, per the injected Review checklist. Skip style the formatter/linter handles; if unsure a finding is real, mark it `needs-verification` rather than asserting it.

For a performance finding, include the mechanism, hotness evidence, expected metric, and verification method in the evidence field. Call it a confirmed regression only when supplied measurements support that claim; otherwise use `needs-verification`. Omit cold-path micro-optimizations and generic advice. Do not run builds, benchmarks, profilers, tests, or linters — measurement belongs to main-session validation.

For a complexity finding, optionally suggest a **minimal fix** (low-risk) and, only if warranted, a **structural refactor** (deeper redesign, with tradeoffs). If nothing is at/above Medium, say so. Do not edit files."

## Spec reviewer prompt (base) — Spec axis

Specialize with the change map, diff-scope command, and spec source:

"Read-only spec review — do not edit files. Run `<diff-scope command>` to see the change, and read the spec at `<path or contents>` (or, if no written spec exists, the stated intent/acceptance goals given above). Report **every** spec-conformance finding and only those (the injected one-shot report contract applies), ordered by severity: **(a)** requirements the spec asked for that are missing or partial; **(b)** behavior the spec didn't ask for (scope creep); **(c)** requirements that look implemented but appear wrong. Quote the spec (or intent) line for each finding, with the file + line in the diff where relevant. Use the project's domain glossary terms exactly. Do not report code-quality issues — that is the other axis. If neither a spec nor stated intent was provided, reply 'no spec available'. Do not run builds, benchmarks, profilers, tests, or linters; validation belongs to the main session. Do not edit files."

## Final output (core skeleton, specialized — in the user's language, per core)

- Passes run and why the loop stopped (threshold met / cap hit / not converged / verification blocked).
- Fix summary + finding ledger (including rejected findings and why).
- Validation commands run and results; fix-readiness gate result.
- Performance risks: accepted/rejected/needs-verification dispositions, baseline versus fixed measurements and confidence, or “not performance-sensitive”.
- Spec-axis result: missing/partial requirements, scope creep, and wrong implementations — or "no spec available".
- Simplicity improvements made, or why none; chosen path (minimal vs structural) when complexity findings existed.
- Open findings below threshold, listed not fixed.
