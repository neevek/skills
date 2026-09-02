---
name: review-fix-cycle
description: Iterative review-fix loop. Spawn fresh-context read-only reviewers in parallel, triage findings, fix only in the main session, validate with related tests only, and repeat until findings drop below a severity threshold or a pass cap is hit. Use this when you want convergence over multiple passes, not a one-shot review — checking code correctness, evidence-backed performance risks, simplicity, and spec compliance (missing or partial requirements, scope creep). Works across native (C/C++/Rust), UI/web (TS/JS), and mobile/desktop (Swift/Kotlin/Java) projects.
---

# review-fix-cycle

Review-fix passes over a code **diff** until findings fall below the stop threshold. Sibling `review-plan-cycle` does this for a plan before any code exists.

**REQUIRED SUB-SKILL:** load `review-cycle-core` and run its Run sheet. It owns the loop — effort tiers, the four standing limits, parallel spawning, the one-shot report contract, triage, the ledger, anti-oscillation, the stop rule, the simplicity bar, and comment/ADR/glossary discipline. This skill adds only the diff specifics: what to map, what to check, what to run, and when the fix is done.

## Change map (core step 1)

A few lines before pass 1, injected into every reviewer prompt. Write **"n/a"** rather than inventing content: an imagined hot path or contract sends a reviewer hunting something that isn't there, and you pay for the hunt.

- intent / acceptance goals.
- diff-scope command — `git show HEAD` (or `<ref>`), `git diff --merge-base origin/main`, `git diff` / `--staged`. Exclude generated and vendored files; review the source that produces them. Paste the diff itself into the prompts when it fits; otherwise every reviewer re-runs the same discovery.
- changed contracts — boundaries outside the diff that depend on it, so a break is silent: exported APIs, RPC/API shapes, UI props/events/tokens, cross-language or cross-process seams, wire/on-disk formats, persisted or cached state, config/flags, packaged or generated output.
- **boundary behavior** when the change is event-driven, asynchronous, cached, streamed, or cross-component — identify the actual producer and consumer; what happens while idle/quiescent, empty, paused, disconnected, or backpressured; what wakes or retries the path; and which event proves completion. Read only the directly involved boundary code before pass 1 instead of paying later passes to discover its contract.
- **validation targets** — the narrowest command per touched stack, named here so no pass has to guess. Say whether anything is cross-cutting enough to justify one broad run at the end; default is no.
- performance context **when touched** — hot path or scaling boundary, representative workload, metric or budget, known baseline, reproducible measurement command. No budget or baseline ⇒ say so, don't invent one. An added or changed inner loop, or changed code on a per-frame, per-request, per-item, or startup path, counts as touched even with no stated budget; write "n/a" only when no changed code sits on such a path.
- spec source — the issue/PRD the diff implements; absent one, the Spec axis runs against the intent above. Skip that axis only when neither exists.

## Scope-expansion gate

Inspect direct dependencies and adjacent repositories read-only when needed to map a changed boundary. If an accepted fix would require mutating a repository, service, public API, generated artifact pipeline, platform, or deliverable the user did not already place in scope, stop before editing it: report the dependency, why the in-scope change cannot satisfy the acceptance goal alone, and the smallest expansion needed. After authorization, re-tier whenever the expansion adds a core floor. Never let review silently broaden the assignment.

## Two axes per pass, always concurrent

Separate agents, separate reports, kept apart in triage so neither masks the other: code can satisfy every standard and still implement the wrong thing.

- **Correctness** — the diff: bugs, contracts, lifecycle, evidence-backed performance, security, simplicity.
- **Spec** — does it implement what was asked?

At Full, fan out Correctness by scope in the same message — native (memory, ownership, `unsafe`, FFI, threading, feature flags), media (buffer ownership, frame timing, GPU/decoder lifecycle), mobile/desktop (lifecycle, persistence, permissions, packaged libs), web/UI (types, async state, routing, API contracts, a11y, bundle), packaging/contracts (artifacts, bindings, schemas, migrations, platform filters), performance (only when the change map names a path).

## Triage states

**accept / reject / needs-verification**, recording why rejected — reviewers guess wrong on `unsafe`, lifetimes, FFI, threading, and on whether a Spec "miss" was deliberately out of scope. Core's confirming-reviewer and anti-oscillation rules apply; two reviewers pulling the same lines in opposite directions is a frozen trade-off for the user, not a third fix.

## Fixing a correctness finding (red-capable)

A finding asserting **wrong behavior** needs a check that goes red on that symptom and green once fixed — a test at the right seam, a curl script, a CLI run diffed against known-good — **red first**: a fix you can't watch turn red-to-green is unverified, and may be fixing something nearby. The red check is evidence the fix landed, never the target: fix the mechanism on every affected path, not just the case the check exercises. Style, contract, and packaging findings need only the Validation commands.

**Cheapest red check on a fix already written: invert the fix, not the bug.** Disable the new mechanism in place (`if false, …`, revert the default, comment the guard), watch the new test fail, restore, watch it pass — one build, no harness, and it proves the test binds to *this* mechanism. Never leave the inverted state behind.

When several accepted findings share a build target, batch independent regression checks: add all tests, invert each new mechanism in one temporary patch, run the individually named tests together so every expected failure stays attributable, restore the mechanisms together, then compile and run green once. Split the batch only when inversions interact or obscure which contract failed.

## Simplicity (core's simplicity bar, applied to a diff)

Core owns the bar and the vocabulary. On a diff it lands as: a branch or state field no path can reach; a wrapper that only forwards (**deletion test**); a seam with one adapter; a flag threaded through callers to reach one decision; a special case the general path already handles. "Add a comment here" almost always means "simplify this" — do that and reject the comment.

Every complexity finding carries its **minimal fix**; a **structural refactor** only when the minimal fix leaves the shape wrong, with its trade-offs, since restructuring is scope growth the user owns (core limit 3).

## Performance (conditional, evidence-gated)

**If the change map's performance context is "n/a", skip this section and leave performance out of the prompts.** Most diffs aren't performance-sensitive; asking anyway buys speculation you then have to triage.

A static reviewer may raise a *risk*, and may call it a regression only when the change map supplies applicable measurements. Every performance finding states **mechanism** (added work, waiting, contention, copying, I/O, rendering, worse scaling), **hotness** (call site, frequency, input-size relation, real-time path, or budget making it material), **metric** (p95 latency, frame time, allocations/frame, peak RSS, wakeups, bundle bytes), and **verification** (the benchmark or profile comparison that would settle it). Plausible mechanism with unknown hotness ⇒ `needs-verification`; a cold-path micro-optimization ⇒ omit. Severity: **High** only for a demonstrated budget/SLO breach, missed deadline, hang, or OOM; **Medium** for a credible material regression or unbounded scaling on a hot path; **Low** for a measured minor one.

`needs-verification` is not terminal at/above threshold: run the measurement during this pass — the baseline can start with the spawn message when the change map names the path; the comparison runs after the batched fix — and convert it to accept or reject. If no representative measurement can be built, stop as **verification blocked**, naming the missing workload or tool.

Measure before optimizing: release-equivalent build, same workload, config, and machine on both sides; warm up, take enough samples to expose noise, report median plus p95/p99, never one wall-clock run; compare against baseline or budget, making a breached budget red-to-green. Add a guard only where it can be stable — otherwise record the command and the residual risk. Performance stays in the Correctness ledger; it is never a third axis.

## Validation

**Related tests only — run the cheapest thing that can fail.** Deriving targets from the change map is part of the job; "run the suite" is the loop's most expensive habit and it re-validates code the next pass will change.

- Narrow to the touched seams: `-only-testing:` / `--filter` / `-run` / one package or target. Can't name a narrow target ⇒ say so and pick the smallest package containing the seam; never fall back to everything.
- **Keep a validation ledger** — target → relevant source/dependency paths + build/runtime inputs + external-state assumptions → last green revision/state → clean/dirty. A target whose declared inputs and relevant external state are all unchanged since green is not re-run; anything else is dirty. Configuration, generated artifacts, schemas, services, devices, browsers, simulators, toolchains, and environment dirty a target without a source edit.
- **Batch, then build once.** Apply every accepted production fix and test edit for the pass before compiling; split build from run (`build-for-testing` + `test-without-building`, `cargo test --no-run`) and reuse that build for every run in the pass. Never rebuild under a running test process.
- Order by cost, stop at the first red: typecheck/compile → lint → unit → integration → UI/simulator/e2e.
- A red also present on the base revision, or non-deterministic across two runs with no edit between, is not this diff's failure: record it as residual environment risk and move on — never fix out-of-scope code to green it.
- Only *stable* validation joins the pass's spawn message (core limit 1). A target covering code the reviewers are likely to change waits for triage and the batched fix; an unchanged dependency check or a baseline measurement runs concurrently.
- Defer expensive integration, device, simulator, browser, and UI journeys until no accepted cheaper-seam finding remains — run one earlier only when it is itself the narrowest red/green seam for an accepted finding. A broad or device/simulator/browser/e2e run happens only per core limit 2: change map flagged something cross-cutting, once, in the final pass, plus any target whose code changed since it last passed.

Per stack: **Rust** — `cargo build`, `cargo test`, `cargo clippy -- -D warnings`, plus `extern "C"`/`#[no_mangle]` symbols and regenerated headers matching callers. **C/C++** — build + tests, exported symbols (`nm`), ABI drift (`abidiff`), release/debug parity. **TS/JS** — `tsc --noEmit`, lint, unit, build for changed deployables. **Swift/Kotlin/Java** — platform build + tests, regenerated bindings, packaged native libs, manifests, permissions. **Cross-cutting** — exported symbols, generated files, schema migrations, snapshot output.

## Fix-readiness gate

For **every accepted finding**, before declaring the loop done:

- the fix applied in the main session;
- the final pass's fixes re-read once against the Simplicity section's diff shapes — they are the one set of edits no reviewer sees;
- for a non-performance correctness finding, a regression test at a correct seam, passing now and red before — or the absence of a correct seam recorded as residual risk (a too-shallow seam is false confidence, so say so instead of claiming coverage);
- for a performance finding, before/after measurements, a red-to-green budget check if a contract was breached, and a guard only where stable;
- the scoped validation targets for the touched stacks run, with output captured;
- a ledger entry reading `key → finding → accept/reject (why) → fix → validation → residual risk`.

**At Lightweight the gate is five items and nothing else:** every accepted finding fixed; the fixes re-read once against the Simplicity section's diff shapes; one red-to-green check per accepted wrong-behavior finding (the Performance section's before/after evidence when it is a performance one); the scoped validation target run; ledger recorded — the first three vanish when nothing was accepted. The performance-evidence item applies at every tier.

A gap means the loop is not done regardless of finding count: close it within the cap, else stop as **not converged**, naming the gap.

## Review checklist (inject into the Correctness prompt; only areas the diff touches)

- **Behavior parity** — every mode, path, and platform affected, including old behavior that must stay.
- **Contracts** — signatures, public APIs, FFI/ABI, bindings, serialization, migrations, config defaults, CLI compatibility; external callers left un-updated.
- **Build/packaging** — libs, platform slices, assets, plugins, manifests, release/debug divergence.
- **Lifecycle/concurrency** — init/shutdown, pause/resume, cancellation, threading, ownership, cleanup, lock ordering, races; event sources that go quiet while idle/static/paused, the wake-up path, and circular waits where progress requires an event the blocked side can no longer produce.
- **Native/media safety** — memory safety, lifetimes, `unsafe`, error ownership; GPU/decoder/audio buffer lifetime and frame timing.
- **Performance** (only per the gate above) — repeated copying/allocation, N+1 I/O, blocking in async or UI paths, contention, excess renders, unbounded queues, backpressure, startup/bundle/CPU/memory/battery regressions. No generic "could be faster".
- **Data/input** — parsing, escaping, Unicode, paths, malformed or missing input, old saved state, precision/overflow.
- **Security/privacy** — auth, secrets, certs, permissions, sandboxing, untrusted input, dependency loading.
- **UI** — navigation, state persistence, disabled/loading/error states, accessibility, responsive layout, overflow, stale controls.
- **Tests** — missing coverage for changed contracts, edge cases, target platforms; a proposed test must name the narrowest target that runs it.
- **Simplicity** — per the Simplicity section: unreachable branches or state, forwarding wrappers, single-adapter seams, flags threaded to one decision, special cases the general path covers. Minimal fix first.
- **Comments** — narration, restating the change, or referencing this review (Low; prefer deleting the comment or simplifying the code).

## Reviewer prompts

Specialize with the change map and scope; inject the checklist, severity rubric, one-shot contract, and the factual ledger. Paste the diff when it fits, so no reviewer spends its pass rediscovering it.

**Correctness:** "Read-only review — do not edit files. The change is below (or run `<diff-scope command>` to read it); you may read the rest of the tree to see how changed contracts are used, but run no build, test, lint, benchmark, or profiler commands — measurement belongs to the main session. Judge the change against the stated intent and changed contracts, using the project's glossary terms exactly and respecting ADRs in the touched area (to reopen one, say so and why). Audit only the areas the diff touches, per the injected checklist; skip what the formatter or linter handles; mark anything you are unsure of `needs-verification`. Two things are out of bounds: restating what the change does, and reporting behavior the stated intent never asked for — judge the diff against that intent, not against the feature you would have built. If you believe the intent is too narrow, say so in one line labelled `scope note`, which routes to the user, who owns scope. Any check you ask for must name the narrowest target that would run it; never ask for the full suite. For a performance finding, give mechanism, hotness evidence, expected metric, and verification method. For a complexity finding, give the **minimal fix**, and a **structural refactor** only if the minimal fix leaves the shape wrong, with its trade-offs — never propose one that changes behavior on any path or slows a hot path."

**Spec:** "Read-only spec review — do not edit files. Read the change (below, or via `<diff-scope command>`) and the spec at `<path or contents>` (absent one, the stated intent/acceptance goals). Report **every** spec-conformance finding and only those: **(a)** requirements missing or partial; **(b)** behavior the spec never asked for (scope creep); **(c)** requirements implemented wrongly. Quote the spec or intent line for each, with file + line where relevant, using glossary terms exactly. No code-quality findings — that is the other axis. Neither spec nor intent given ⇒ reply 'no spec available'. Run no builds or tests."

## Final output (core skeleton, plus)

- Fix summary and the ledger, rejected and frozen findings included.
- Validation commands run, scoped targets and results; fix-readiness gate result.
- Performance dispositions with before/after and confidence — or "not performance-sensitive".
- Spec axis: missing or partial requirements, scope creep, wrong implementations — or "no spec available".
- Simplicity: what was simplified, or why nothing was; minimal versus structural where complexity findings existed.
