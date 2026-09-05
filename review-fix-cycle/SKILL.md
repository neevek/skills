---
name: review-fix-cycle
description: Review and fix a code change through bounded independent review, evidence-based corrections, scoped validation, and focused delta verification. Use for an iterative correctness and spec-conformance review, not an ordinary one-shot review.
---

# review-fix-cycle

Load [review-cycle-core](../review-cycle-core/SKILL.md) and follow its Run sheet. Core owns the budget, scheduling, threshold, finding states, independent verification, and completion rules. This skill supplies code-specific scope and validation.

## Capture the change

Before assigning reviewers, record a compact map:

- **Intent:** acceptance goals and the issue/spec if supplied. Missing formal spec means review against user intent; never invent requirements.
- **Subject:** the requested commit, branch delta, or unfinished work. Inspect `git status --short --untracked-files=all` and select the appropriate base/head. For unfinished work, reconcile staged and unstaged changes (`git diff --cached`, `git diff`) plus relevant untracked file contents. A single Git diff does not include untracked files. Include deletions/renames; review generators and validate required generated/package outputs. Exclude unrelated work and vendored bulk.
- **Version:** capture the diff and relevant new files once, with base/head IDs and hashes of relevant working-file contents. Give reviewers those bytes or a stable artifact, not a moving `HEAD` command. Record directly inspected boundary dependencies as review inputs. Verify those inputs still match before closing coverage; user/concurrent edits invalidate only affected results. Do not stage or commit user work just to create a review snapshot.
- **Boundaries:** direct producers/consumers, contracts, persistence, ownership, and required packaged outputs. For asynchronous/event-driven work, include idle/empty/paused/disconnected/backpressured states, wake-up/retry behavior, and the event proving completion. Extend this map when inspection reveals an omitted direct boundary.
- **Validation:** cheapest faithful command/target per touched seam, required project checks, and any justified broad final check. Group seams sharing a command.
- **Performance, when touched:** changed per-request/frame/item/startup work or a scaling boundary; workload, relevant metric/budget, baseline and measurement command if available. Otherwise say what is unknown. Use `n/a` only when no such changed mechanism is involved.

Read-only boundary inspection may cross repositories. Editing a new surface follows core's authorization rule; do not turn every necessary internal correction into a scope-expansion question.

## Review axes and prompt

Keep **Correctness** and **Spec** findings distinct. Lightweight uses one independent reviewer for both; Standard normally separates them; Full groups correctness risks under a few owners and assigns spec separately. Later assignments cover affected axes only. If neither intent nor spec can be established, ask for the missing objective; do not claim spec coverage.

Supply the core report contract, captured change, applicable instructions, relevant ledger entries, and selected checks below. Reviewers may inspect direct dependencies/callers to verify contracts; they do not edit or run validation.

- **Correctness:** behavior on all affected paths/platforms, error handling, input/encoding/overflow, changed APIs/serialization/defaults, security and trust boundaries, concurrency/ownership/cancellation, packaging, and test seams. For event-driven work, examine quiescence, backpressure, wake-ups, and circular waits. For native/media work, include lifetimes, FFI/ABI, buffer ownership, and frame/device lifecycle. For UI, include stale async state, loading/error/disabled states, navigation and accessibility. Inject only touched areas. Simplification needs a concrete cost and minimal behavior-preserving remedy, per core.
- **Spec:** missing/partial requirements, wrong implementations, and unrequested behavior. Quote the relevant user/spec requirement and cite the affected code. Preserve required old behavior even when it is not restated in the feature request. Keep code-quality findings under Correctness.
- **Performance:** require a concrete mechanism, material call frequency/input-size relationship, appropriate metric, and decisive verification. Unknown hotness is uncertainty, not a demonstrated regression. Omit cold-path micro-optimizations.

## Prove and batch corrections

A wrong-behavior finding needs evidence at the seam where the symptom occurs. Prefer an existing check or a small regression test/CLI reproduction that fails on the **actual pre-fix behavior** and passes after the fix. Match the failure to the reported symptom; a compile/setup failure is not the expected red. Contract and packaging defects use an appropriate consumer, symbol, schema, or artifact check. Pure wording/style edits need no new tests.

Obtain red evidence before editing when feasible. Batch independent reproductions sharing a target, then batch fixes and run green. If the fix is already written, use a captured pre-fix state in an isolated temporary workspace or an exact, safely reversible patch that restores the old behavior. Disabling the new mechanism is mutation sensitivity, not proof of the original bug. If no faithful pre-fix state or seam is available, record missing evidence; do not manufacture a red.

Prefer isolation when temporary reversion would touch unrelated work. For a safe in-place check, save the exact patch/state, arrange restoration on error/interruption, and verify restoration before further work. Never reset a whole checkout, copy a branch snapshot over it, or rebuild under a running test process.

**Build once per distinct source/configuration state**, reusing incremental caches and outputs within that state. Compiled pre-fix and fixed states require corresponding builds; source inversion cannot change an existing binary. Share each build across compatible targeted runs (`build-for-testing` / `test-without-building`, or `cargo test --no-run` where appropriate).

Fix the mechanism on every affected in-scope path, not just the reproduced input. If a fix introduces another defect, core permits correcting it while preserving the earlier requirement. Batch corrections before another build; do not alternate one finding, one full review.

## Performance evidence

Use the cheapest evidence that settles the actual claim. Exact output/bundle sizes, allocation or operation counts, and a defensible complexity bound can establish deterministic changes without a timing benchmark. Such evidence proves only its metric/bound, not an unmeasured latency or SLO claim.

For timing/resource variability, compare representative workloads in equivalent builds, configuration, and environments; warm up and sample enough to assess noise. Use percentiles when tail latency matters, not for every metric. Avoid concurrent local work that competes for the measured resources; baseline/comparison runs are parallelizable only when suitably isolated. Preserve a usable existing baseline instead of recreating it each pass.

Measure before optimizing a claim needing empirical evidence. Unknown hotness or workload remains `needs-verification`; a plausible blocking claim cannot be cleared by missing tools or by a speculative optimization. If required, unwaived evidence is unavailable, report **blocked** with the missing workload/tool. Record confidence and use a stable guard only when meaningful; do not add flaky performance tests. Core's severity/threshold applies according to demonstrated impact.

## Scoped validation and readiness

Run the cheapest faithful checks, reusing known-green results. Required project checks still apply. Select the narrowest reliable target; the smallest package or entire suite is legitimate when it is the smallest faithful or required check. Broaden for an identified cross-cutting impact or unresolved failure, with a reason. Expensive device/browser/e2e journeys normally run once after cheaper issues are resolved; run one earlier if it is the only faithful reproduction seam.

Keep `target → source/dependency/build/runtime inputs and external assumptions → tested state → result → clean/dirty`. Trust build-system dependency tracking where available. Unknown or changed relevant inputs make the target dirty; do not invent a complete dependency list to justify skipping a check. Reuse a green artifact only for matching inputs. A final report must distinguish passed, failed, skipped, and unavailable checks.

Order dependent checks by cost. Independent cheap checks may run concurrently when they cannot invalidate or interfere with one another. After a failure, fix or attribute it before running more expensive dependent checks. A reviewer and validation may run together on the same fixed source state; avoid formatter/autofix/codegen mutations while that state is being reviewed.

**An intermittent failure is unresolved evidence.** A fail/pass pair on unchanged code can indicate a new race. Inspect the failure mechanism and use a focused deterministic reproduction or matched base/candidate comparison where useful; avoid blind retries. The same relevant failure demonstrably present on the base can be recorded as pre-existing without unrelated repairs, but does not establish that the candidate cannot worsen it. An unresolved failure at a required acceptance seam leaves validation incomplete; only explicit user acceptance can waive that residual risk.

Before completion, verify:

- Accepted fixes are applied; material deltas have independent coverage on their final state, per core. Local simplicity checks supplement that coverage.
- Wrong-behavior corrections have faithful pre-fix/fixed evidence; performance corrections have evidence appropriate to the claim. Missing evidence remains an explicit readiness gap or user-accepted risk.
- Required scoped targets passed on matching inputs; no unresolved relevant failure is hidden as environment noise.
- Spec coverage and the finding/coverage/validation ledgers are current. Core's completion table decides the outcome at every tier.

Report fixes, rejection evidence, commands/targets and results, remaining coverage gaps, relevant performance evidence, and concrete spec misses or scope creep. Include core's cost counters; omit empty domain sections.
