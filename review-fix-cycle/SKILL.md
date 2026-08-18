---
name: review-fix-cycle
description: Iterative review-fix loop. Spawn fresh-context read-only reviewers in parallel, triage findings, fix only in the main session, validate with related tests only, and repeat until findings drop below a severity threshold or a pass cap is hit. Use this when you want convergence over multiple passes, not a one-shot review — checking code correctness, evidence-backed performance risks, and spec compliance (missing or partial requirements, scope creep). Works across native (C/C++/Rust), UI/web (TS/JS), and mobile/desktop (Swift/Kotlin/Java) projects.
---

# review-fix-cycle

Review-fix passes over a code **diff** until findings fall below the stop threshold. Sibling `review-plan-cycle` does this for a plan before any code exists.

**REQUIRED SUB-SKILL:** load `review-cycle-core` for the loop — effort tiers, parallel spawning, the one-shot report contract, triage, the ledger, the anti-oscillation protocol, the stop rule, comment and ADR/glossary discipline. This skill adds only the diff specifics.

**The core's three standing limits bind here:** spawn both axes (at Full, every scope) concurrently in one message alongside validation; validate with the narrowest targets covering the touched seams; review *this diff* against the stated intent and nothing wider — a finding that would grow it goes to the user, not into the code.

## Change map (core step 1)

A few lines before pass 1. Write **"n/a"** rather than inventing content: an imagined hot path or contract sends a reviewer hunting something that isn't there, and you pay for the hunt.

- intent / acceptance goals.
- diff-scope command — `git show HEAD` (or `<ref>`), `git diff --merge-base origin/main`, `git diff` / `--staged`. Exclude generated and vendored files; review the source that produces them.
- changed contracts — boundaries outside the diff that depend on it, so a break is silent: exported APIs, RPC/API shapes, UI props/events/tokens, cross-language or cross-process seams, wire/on-disk formats, persisted or cached state, config/flags, packaged or generated output.
- **validation targets** — the narrowest command per touched stack, named here so no pass has to guess. Say whether anything is cross-cutting enough to justify one broad run at the end; default is no.
- performance context **when touched** — hot path or scaling boundary, representative workload, metric or budget, known baseline, reproducible measurement command. No budget or baseline ⇒ say so, don't invent one.
- spec source — the issue/PRD the diff implements; absent one, the Spec axis runs against the intent above. Skip that axis only when neither exists.

## Two axes per pass, always concurrent

Separate agents, separate reports, kept apart in triage so neither masks the other: code can satisfy every standard and still implement the wrong thing.

- **Correctness** — the diff: bugs, contracts, lifecycle, evidence-backed performance, security, simplicity.
- **Spec** — does it implement what was asked?

At Full, fan out Correctness by scope in the same message — native (memory, ownership, `unsafe`, FFI, threading, feature flags), media (buffer ownership, frame timing, GPU/decoder lifecycle), mobile/desktop (lifecycle, persistence, permissions, packaged libs), web/UI (types, async state, routing, API contracts, a11y, bundle), packaging/contracts (artifacts, bindings, schemas, migrations, platform filters), performance (only when the change map names a path).

## Triage states

**accept / reject / needs-verification**, recording why rejected — reviewers guess wrong on `unsafe`, lifetimes, FFI, threading, and on whether a Spec "miss" was deliberately out of scope. The core's confirming-reviewer and anti-oscillation rules apply; two reviewers pulling the same lines in opposite directions is a frozen trade-off for the user, not a third fix.

## Fixing a correctness finding (red-capable)

A finding asserting **wrong behavior** needs a check that goes red on that symptom and green once fixed — a test at the right seam, a curl script, a CLI run diffed against known-good — **red first**: a fix you can't watch turn red-to-green is unverified, and may be fixing something nearby. Style, contract, and packaging findings need only the Validation commands.

**Cheapest red check on a fix already written: invert the fix, not the bug.** Disable the new mechanism in place (`if false, …`, revert the default, comment the guard), watch the new test fail, restore, watch it pass — one build, no harness, and it proves the test binds to *this* mechanism. Never leave the inverted state behind.

## Performance (conditional, evidence-gated)

**If the change map's performance context is "n/a", skip this section and leave performance out of the prompts.** Most diffs aren't performance-sensitive; asking anyway buys speculation you then have to triage.

A static reviewer may raise a *risk*, and may call it a regression only when the change map supplies applicable measurements. Every performance finding states **mechanism** (added work, waiting, contention, copying, I/O, rendering, worse scaling), **hotness** (call site, frequency, input-size relation, real-time path, or budget making it material), **metric** (p95 latency, frame time, allocations/frame, peak RSS, wakeups, bundle bytes), and **verification** (the benchmark or profile comparison that would settle it). Plausible mechanism with unknown hotness ⇒ `needs-verification`; a cold-path micro-optimization ⇒ omit. Severity: **High** only for a demonstrated budget/SLO breach, missed deadline, hang, or OOM; **Medium** for a credible material regression or unbounded scaling on a hot path; **Low** for a measured minor one.

`needs-verification` is not terminal at/above threshold: run the measurement during this pass — start it in the spawn message when it doesn't depend on the reports — and convert it to accept or reject. If no representative measurement can be built, stop as **verification blocked**, naming the missing workload or tool.

Measure before optimizing: release-equivalent build, same workload, config, and machine on both sides; warm up, take enough samples to expose noise, report median plus p95/p99, never one wall-clock run; compare against baseline or budget, making a breached budget red-to-green. Add a guard only where it can be stable — otherwise record the command and the residual risk. Performance stays in the Correctness ledger; it is never a third axis.

## Validation

**Related tests only — run the cheapest thing that can fail.** Deriving targets from the change map is part of the job; "run the suite" is the loop's most expensive habit and it re-validates code the next pass will change.

- Narrow to the touched seams: `-only-testing:` / `--filter` / `-run` / one package or target. Can't name a narrow target ⇒ say so and pick the smallest package containing the seam; never fall back to everything.
- Split build from run (`build-for-testing` + `test-without-building`, `cargo test --no-run`) and reuse that build for the whole pass.
- Order by cost, stop at the first red: typecheck/compile → lint → unit → integration → UI/simulator/e2e.
- Start validation in the pass's spawn message, concurrent with the reviewers.
- A broad, device, simulator, browser, or e2e run happens **only** if the change map flagged something cross-cutting — then once, in the final pass, plus any target whose code changed since it last passed.
- Never rebuild under a running test process, and never re-run a target for files untouched since it was green.

Per stack: **Rust** — `cargo build`, `cargo test`, `cargo clippy -- -D warnings`, plus `extern "C"`/`#[no_mangle]` symbols and regenerated headers matching callers. **C/C++** — build + tests, exported symbols (`nm`), ABI drift (`abidiff`), release/debug parity. **TS/JS** — `tsc --noEmit`, lint, unit, build for changed deployables. **Swift/Kotlin/Java** — platform build + tests, regenerated bindings, packaged native libs, manifests, permissions. **Cross-cutting** — exported symbols, generated files, schema migrations, snapshot output.

## Fix-readiness gate

**At Lightweight, four items and nothing else:** every accepted finding fixed; one red-to-green check on the behavior the loop was called about; the scoped validation target run; ledger recorded.

At Standard and Full, for **every accepted finding**: a fix applied in the main session; for a non-performance correctness finding, a regression test at a correct seam, passing now and red before — or the absence of a correct seam recorded as residual risk (a too-shallow seam is false confidence, so say so instead of claiming coverage); for a performance finding, before/after measurements, a red-to-green budget check if a contract was breached, and a guard only where stable; scoped validation run for the touched stacks with output captured; a ledger entry reading `key → finding → accept/reject (why) → fix → validation → residual risk`. A gap means the loop is not done regardless of finding count: close it within the cap, else stop as **not converged**, naming the gap.

## Review checklist (inject into the Correctness prompt; only areas the diff touches)

- **Behavior parity** — every mode, path, and platform affected, including old behavior that must stay.
- **Contracts** — signatures, public APIs, FFI/ABI, bindings, serialization, migrations, config defaults, CLI compatibility; external callers left un-updated.
- **Build/packaging** — libs, platform slices, assets, plugins, manifests, release/debug divergence.
- **Lifecycle/concurrency** — init/shutdown, pause/resume, cancellation, threading, ownership, cleanup, lock ordering, races.
- **Native/media safety** — memory safety, lifetimes, `unsafe`, error ownership; GPU/decoder/audio buffer lifetime and frame timing.
- **Performance** (only per the gate above) — repeated copying/allocation, N+1 I/O, blocking in async or UI paths, contention, excess renders, unbounded queues, backpressure, startup/bundle/CPU/memory/battery regressions. No generic "could be faster".
- **Data/input** — parsing, escaping, Unicode, paths, malformed or missing input, old saved state, precision/overflow.
- **Security/privacy** — auth, secrets, certs, permissions, sandboxing, untrusted input, dependency loading.
- **UI** — navigation, state persistence, disabled/loading/error states, accessibility, responsive layout, overflow, stale controls.
- **Tests** — missing coverage for changed contracts, edge cases, target platforms; a proposed test must name the narrowest target that runs it.
- **Simplicity** — over-complex logic, needless abstraction, avoidable branching or state.
- **Comments** — narration, restating the change, or referencing this review (Low; prefer deleting the comment or simplifying the code).

## Reviewer prompts

Specialize with the change map, diff-scope command, and scope; inject the checklist, severity rubric, and one-shot contract.

**Correctness:** "Read-only review — do not edit files. Run `<diff-scope command>` to read the change; you may read the rest of the tree to see how changed contracts are used, but run no build, test, lint, benchmark, or profiler commands — measurement belongs to the main session. Judge the change against the stated intent and changed contracts, using the project's glossary terms exactly and respecting ADRs in the touched area (to reopen one, say so and why). Audit only the areas the diff touches, per the injected checklist; skip what the formatter or linter handles; mark anything you are unsure of `needs-verification`. Two things are out of bounds: restating what the change does, and reporting behavior the stated intent never asked for — judge the diff against that intent, not against the feature you would have built. If you believe the intent is too narrow, say so in one line labelled `scope note`, which routes to the user, who owns scope. Any check you ask for must name the narrowest target that would run it; never ask for the full suite. For a performance finding, give mechanism, hotness evidence, expected metric, and verification method. For a complexity finding, optionally give a **minimal fix**, and a **structural refactor** only if warranted, with its trade-offs."

**Spec:** "Read-only spec review — do not edit files. Run `<diff-scope command>`, and read the spec at `<path or contents>` (absent one, the stated intent/acceptance goals). Report **every** spec-conformance finding and only those: **(a)** requirements missing or partial; **(b)** behavior the spec never asked for (scope creep); **(c)** requirements implemented wrongly. Quote the spec or intent line for each, with file + line where relevant, using glossary terms exactly. No code-quality findings — that is the other axis. Neither spec nor intent given ⇒ reply 'no spec available'. Run no builds or tests."

## Final output (core skeleton, plus)

- Fix summary and the ledger, rejected and frozen findings included.
- Validation commands run, scoped targets and results; fix-readiness gate result.
- Performance dispositions with before/after and confidence — or "not performance-sensitive".
- Spec axis: missing or partial requirements, scope creep, wrong implementations — or "no spec available".
- Simplicity changes made, or why none; minimal versus structural where complexity findings existed.
