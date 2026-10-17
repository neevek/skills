---
name: review-fix-cycle
description: Review and fix a code change through bounded independent review, evidence-based corrections, scoped validation, and focused delta verification. Use for an iterative correctness and spec-conformance review, not an ordinary one-shot review.
---

# review-fix-cycle

Load [review-cycle-core](../review-cycle-core/SKILL.md) and follow its Run sheet. Core owns budgets, scheduling, threshold, finding states, independent verification, and completion; this skill supplies code-specific scope and validation.

## Capture the change

Before assigning reviewers, record a compact map:

- **Intent:** acceptance goals and the issue/spec if supplied. Missing formal spec means review against user intent; never invent requirements.
- **Subject:** the requested commit, branch delta, or unfinished work. Inspect `git status --short --untracked-files=all` and select the base/head; unfinished work spans staged, unstaged, and untracked files, which a single Git diff misses and the snapshot captures. Include deletions/renames; review generators and validate required generated/package outputs. Exclude unrelated work and vendored bulk.
- **Version:** run core's snapshot against the base, with a pathspec when unrelated work is present. For unfinished work its tree ID is the version; for a committed subject the head commit is, and reviewers get `git diff BASE HEAD_ID` as a file. Either way the tree ID identifies the worktree that inputs and validation were observed on. Record directly inspected boundary dependencies as review inputs and confirm by tree ID that they still match before closing coverage; user/concurrent edits invalidate only affected results. Never stage or commit user work for a snapshot.
- **Boundaries:** direct producers/consumers, contracts, persistence, ownership, and required packaged outputs. For asynchronous/event-driven work, include idle/empty/paused/disconnected/backpressured states, wake-up/retry behavior, and the event proving completion. Extend the map when inspection reveals an omitted direct boundary; read-only inspection may cross repositories.
- **Validation:** cheapest faithful command/target per touched seam, required project checks, and any justified broad final check. Group seams sharing a command.
- **Performance, when touched:** changed per-request/frame/item/startup work or a scaling boundary; workload, relevant metric/budget, baseline and measurement command if available. Otherwise say what is unknown; use `n/a` only when no such mechanism changed.

## Review axes

Keep **Correctness** and **Spec** findings distinct. Lightweight uses one reviewer for both; Standard normally separates them; Full groups correctness risks under a few owners and assigns spec separately. Later assignments cover affected axes only. If neither intent nor spec can be established, ask for the missing objective; do not claim spec coverage.

- **Correctness:** behavior on all affected paths/platforms, error handling, input/encoding/overflow, changed APIs/serialization/defaults, security and trust boundaries, concurrency/ownership/cancellation, packaging, and test seams. Event-driven work: quiescence, backpressure, wake-ups, and circular waits. Native/media work: lifetimes, FFI/ABI, buffer ownership, and frame/device lifecycle. UI: stale async state, loading/error/disabled states, navigation, and accessibility. Bug fixes: the root cause rather than only the reported symptom, and other paths that reach the same cause. Inject only touched areas.
- **Spec:** missing/partial requirements, wrong implementations, and unrequested behavior. Quote the user/spec requirement and cite the code. Preserve required old behavior even when the feature request does not restate it. Code-quality findings belong under Correctness.
- **Performance:** require a concrete mechanism, a material call-frequency/input-size relationship, an appropriate metric, and decisive verification. Unknown hotness is uncertainty, not a demonstrated regression. Omit cold-path micro-optimizations.

## Prove and batch corrections

A wrong-behavior finding needs evidence at the seam where the symptom occurs; prefer an existing check or a small regression test/CLI reproduction that fails on the **actual pre-fix behavior** and passes after the fix. The failure must match the reported symptom; a compile/setup failure is not the expected red. Contract and packaging defects use a consumer, symbol, schema, or artifact check. Pure wording/style edits need no new tests.

Obtain red evidence before editing when feasible; batch independent reproductions sharing a target, then batch fixes and run green. If the fix is already written, use a captured pre-fix state in an isolated temporary workspace or an exact, safely reversible patch that restores the old behavior. Disabling the new mechanism is mutation sensitivity, not proof of the original bug. Without a faithful pre-fix state or seam, record the missing evidence; do not manufacture a red.

Prefer isolation when temporary reversion would touch unrelated work. For a safe in-place check, save the exact patch/state, arrange restoration on error/interruption, and verify restoration before further work. Never reset a whole checkout, copy a branch snapshot over it, or rebuild under a running test process.

**Build once per distinct source/configuration state**, reusing incremental caches and outputs within it. Compiled pre-fix and fixed states need their own builds; source inversion cannot change an existing binary. Share each build across compatible targeted runs (`build-for-testing` / `test-without-building`, or `cargo test --no-run`).

Fix the mechanism on every affected in-scope path, not just the reproduced input. Batch corrections before another build; do not alternate one finding, one full review.

## Performance evidence

Use the cheapest evidence that settles the actual claim. Exact output/bundle sizes, allocation or operation counts, and a defensible complexity bound can establish deterministic changes without a timing benchmark, but prove only that metric or bound, not an unmeasured latency or SLO claim.

For timing/resource variability, compare representative workloads in equivalent builds, configuration, and environments, with warm-up and enough samples to assess noise; use percentiles when tail latency matters, not for every metric. Avoid concurrent local work that competes for measured resources; baseline/comparison runs may run in parallel only when suitably isolated. Preserve a usable existing baseline instead of recreating it each pass.

Measure before optimizing a claim that needs empirical evidence. Unknown hotness or workload stays `needs-verification`; missing tools or a speculative optimization cannot clear a plausible blocking claim. If required, unwaived evidence is unavailable, report **blocked** with the missing workload/tool. Record confidence, and add a stable guard only when meaningful, never a flaky performance test.

## Scoped validation and readiness

Run the cheapest faithful checks, reusing known-green results; required project checks still apply. Select the narrowest reliable target; the smallest package or the entire suite is legitimate when it is the smallest faithful or required check. Broaden for an identified cross-cutting impact or unresolved failure, with a reason. Expensive device/browser/e2e journeys normally run once after cheaper issues are resolved, or earlier when they are the only faithful reproduction seam.

Keep `target → source/dependency/build/runtime inputs and external assumptions → tested tree ID → result → clean/dirty`. Trust build-system dependency tracking where available. Unknown or changed relevant inputs make the target dirty; do not invent a complete dependency list to justify skipping a check. Reuse a green artifact only for matching inputs. Report passed, failed, skipped, and unavailable checks distinctly.

Order dependent checks by cost; independent cheap checks may run concurrently when they cannot invalidate or interfere with one another. After a failure, fix or attribute it before running more expensive dependent checks. A reviewer and validation may run together on the same fixed state; avoid formatter/autofix/codegen mutations while it is under review.

**An intermittent failure is unresolved evidence.** A fail/pass pair on unchanged code can indicate a new race: inspect the mechanism and use a focused deterministic reproduction or matched base/candidate comparison where useful, not blind retries. The same relevant failure demonstrably present on the base can be recorded as pre-existing without unrelated repairs, but that does not show the candidate cannot worsen it. An unresolved failure at a required acceptance seam leaves validation incomplete unless the user explicitly accepts that risk.

Before completion, verify:

- Accepted fixes are applied, and material deltas have independent coverage on their final state; local simplicity checks only supplement it.
- Wrong-behavior corrections have faithful pre-fix/fixed evidence; performance corrections have evidence appropriate to the claim. Missing evidence stays an explicit readiness gap or user-accepted risk.
- Required scoped targets passed on matching inputs; no unresolved relevant failure is hidden as environment noise.
- Spec coverage and the finding/coverage/validation ledgers are current. Core's completion table decides the outcome at every tier.

Report fixes, rejection evidence, commands/targets and results, remaining coverage gaps, relevant performance evidence, concrete spec misses or scope creep, and how to revert when the change touches persisted data, migrations, or rollout, with core's cost counters; omit empty domain sections.
