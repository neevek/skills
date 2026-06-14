---
name: review-plan-cycle
description: Iterative plan-review loop for Codex or Claude Code. Spawn fresh-context read-only reviewers on an implementation plan (no edits), triage findings, refine the plan in the main session, and repeat until design/plan findings drop below a severity threshold or a pass cap is hit. Use this to harden a plan before any code is written.
---

# review-plan-cycle

Run plan-review passes until remaining findings fall below the stop threshold. Each pass uses a **fresh-context, read-only** reviewer so the session that wrote the plan never reviews its own reasoning. The sibling skill `review-fix-cycle` does this for code diffs; this one does it for the plan that precedes them.

## What this skill does

Planning only — **no code edits, no refactors, no implementation steps executed.** The output is an execution-ready plan with technical and design concerns surfaced early.

## Loop

1. **Plan scope** (main session, once before pass 1) — a few lines capturing:
   - intent / acceptance criteria (what "done" means).
   - the plan under review (link or inline; keep it in the Plan format below).
   - boundaries the plan touches — exported/public interfaces, API/RPC or data-model shapes, cross-process/cross-language boundaries, on-disk/wire formats, persisted state, config/flags, migrations. A reviewer can't flag a contract break the plan never named. These populate the plan's **Contracts/migrations touched** field (see Plan format) — name them once, there.
   - a **Plan risk model** (see Risk model) naming every relevant risk class. If a class is not relevant, mark it `n/a` with a short reason. Do not leave this implicit.
   - thresholds and cap if overriding the defaults (see Stop rule).

2. **Spawn a fresh reviewer** (read-only, cannot edit). Pass it the plan scope and the Reviewer prompt. For a large or cross-stack plan, fan out several reviewers with disjoint scopes (see Scopes).
   - **Claude Code**: the Agent/Task subagent tool (not the to-do `TaskCreate`) with `subagent_type: "Explore"`. Fan out by putting multiple tool calls in one message. The subagent's return value is its findings — triage them in the main session.
   - **Codex**: spawn an `explorer` with `fork_context: false` and a self-contained prompt containing the plan scope, Reviewer prompt, and assigned scope. Fan out by spawning one reviewer per disjoint scope; collect their final messages and triage them in the main session. Fresh means a separate agent, not the current session reviewing its own plan.

3. **Triage** in the main session — never blind-apply. Design feedback is subjective; a reviewer's architectural preference is not automatically correct. Mark each finding **accept / reject / defer**, and record why. *Reject* taste disagreements you've considered and settled. *Defer* anything that's genuinely an implementation-time decision, not a plan blocker.
   - A finding the reviewer marked `needs-discussion` (it wasn't sure the concern is real) isn't a fourth state — resolve it into one of the three: if it's a feasibility/technical doubt, spawn at most one more read-only reviewer this pass to confirm before acting; if it's a product/scope decision only the user can make (priorities, intent, acceptable tradeoffs), **stop and ask the user** rather than letting reviewers churn on an undecidable point.

4. **Refine** the plan from accepted findings — main session only.

5. **Record** in the ledger: `finding → accept/reject/defer (why) → plan change`. When a pass chose between a **Simpler plan** and a **Hardcore plan** (see Reviewer prompt), record that choice and its rationale here too, so the next reviewer can validate the direction.
   - For every accepted finding, also record any **new invariant** the refined plan now depends on.
   - For every accepted **High** finding that changes architecture, lifecycle, state ownership, public contracts, or rollout strategy, the next pass must explicitly review the consequences of that accepted change before returning to general review.

6. **Repeat** with a new fresh reviewer, passing the ledger so it checks prior decisions and hunts *new* issues instead of re-raising settled ones. Before declaring the loop done, the main session runs the Execution-readiness gate. Stop per the Stop rule.

## Risk model

Before pass 1, classify the plan against these generic risk classes. Use the
classification to choose reviewer scopes and to make the first pass adversarial
rather than merely broad.

- **Concurrency / lifecycle** — async tasks, actors, locks, cancellation, retries, timeouts, stale completions, drop/shutdown behavior, queues, backpressure.
- **State / data / migrations** — schemas, persisted state, cache freshness, derived data, migrations, compatibility with existing records.
- **API / contract boundaries** — public functions, CLI flags, RPCs, wire formats, cross-process or cross-language contracts, versioning, backward compatibility.
- **Security / privacy / permissions** — auth, authorization, secrets, permissions, trust boundaries, untrusted input, data exposure.
- **UX / operations / rollout** — user-facing behavior, errors, degraded modes, observability, rollout, rollback, feature flags, operational safety.
- **Validation / testability** — deterministic harnesses, acceptance tests, failure injection, regression coverage, monitoring signals.

For any relevant risk class, the plan must either address it directly or name it
as a risk with an explicit owner/decision. A reviewer should treat an unaddressed
relevant risk class as a plan gap.

## Stop rule

Stop when **either** the reviewer reports nothing at/above the threshold (default: no **High** design/plan concerns; open questions are either resolved or explicitly deferred; remaining nits are listed, not fixed) **or** the pass cap is hit (default **4**). Thresholds and cap are overridable in the plan scope.

A *new* finding (even another High) is normal — keep going within the cap. Only true oscillation — the same concern ping-ponging back after it was settled — should stop the loop early. Treat a concern as the *same* (oscillation) when it targets a plan decision or section you already **settled** (accepted or rejected) in the ledger, regardless of how it's reworded; treat it as new when it raises a different decision or a consequence you hadn't recorded. A *deferred* finding that resurfaces is not oscillation — it was never decided. If passes oscillate or the cap is hit with open High items, stop and report **not converged** with the open list. If a reviewer can't run (quota/tool failure), report **review blocked**, not complete. Do not chase literal "zero findings" — design reviews regenerate taste-based nits indefinitely.

## Execution-readiness gate (the plan-loop's validation)

A plan can't be compiled, but the main session checks this gate before declaring the loop done (Loop step 6), confirming the plan is ready to hand to an implementer:

- Every step is concrete and verifiable — no "figure out X later" hiding a real unknown.
- Acceptance criteria are stated and testable.
- Contracts/migration touchpoints from the plan scope are addressed.
- Lifecycle, ownership, cancellation, timeout, retry, and backpressure behavior are specified for every touched async/task/actor/control-flow boundary, or explicitly marked `n/a`.
- State mutation authority is specified: which component may mutate which state, under what token/version/lock/transaction, and how stale or partial results are discarded.
- Rollout/rollback (or "n/a, why") is considered.
- A deterministic validation approach is named for every High-risk behavior; "test manually" is not enough for correctness-critical behavior unless no automated hook is feasible and the plan explains why.
- Open questions are resolved or explicitly deferred with an owner.

If any of these is missing, the plan is not execution-ready regardless of finding count. If the gate fails when the Stop rule would otherwise end the loop (threshold met or cap hit), do not silently finish: fix the gap in another pass if the cap allows, otherwise stop and report **not converged** with the specific gate gap listed.

## Scopes (for multi-reviewer fan-out)

Split a large plan by concern; fold the relevant ones into a single prompt for a small plan:

- **Architecture / state / lifecycle** — module/service boundaries, coupling, sequencing, blast radius, async/task lifecycle, cancellation safety, stale completions, queue bounds, backpressure, ownership of state mutations.
- **Data model & API shape** — schema/contract changes, compatibility, versioning, migrations, public interfaces, cross-process/cross-language boundaries.
- **Security/privacy** — auth/secrets, untrusted input, permissions, trust boundaries, data exposure introduced by the design.
- **UX/interaction** (when the plan includes user-facing flows or interaction design) — flows, states, error/empty/loading, accessibility implications.
- **Testability/rollout/observability** — how the plan will be validated, failure injection, feature flags, staged rollout, rollback, monitoring and diagnostics.

For plans with more than one relevant risk class, prefer fan-out by risk class
over one generic reviewer. For small plans, one reviewer may cover multiple
scopes, but the prompt must still list the relevant risk classes.

## Reviewer prompt (base)

Specialize with the plan scope and scope focus:

"Read-only planning review — do not edit files. Review the implementation plan only. You may read existing code **only** for the files/modules named in the plan scope, and only to sanity-check feasibility — do not survey the wider codebase.

List actionable findings first, ordered by severity (High/Medium/Low), each referencing the plan step/section and with a one-line justification. Include design concerns for your assigned risk scope: architecture/state/lifecycle, API/data-model shape, UX/interaction implications when relevant, security/privacy, validation/rollout/observability, and maintainability/readability of the planned approach.

Verify claimed existing behavior against the scoped code/docs when feasible. If the plan says an existing command/API/state machine already behaves a certain way, either cite where that is true or flag the claim as unverified/incorrect.

Think adversarially. Include any applicable failure timelines: stale async completion after reconnect/invalidation, cancellation after partial side effect, actor/task drop or leak, queue growth or backpressure, cache staleness, retry storm, old/new version compatibility, rollback after partial rollout, permission/auth bypass, degraded dependencies, and observability blind spots.

Flag any step that is vague, unverifiable, or hides an unresolved unknown; any missing lifecycle/drop/timeout/retry/backpressure semantics; any unclear state-mutation authority; and any contract/migration/rollback/test-harness gap. If unsure a finding is real, mark it `needs-discussion` rather than asserting it. If the plan is over-complex, offer a **Simpler plan** (minimal change) and, only if warranted, a **Hardcore plan** (deeper redesign, with tradeoffs). If nothing is at/above Medium, say so. Do not edit files."

## Plan format

- Objective
- Acceptance criteria
- Assumptions
- Ordered steps
- File/module targets
- Contracts/migrations touched
- Plan risk model
- Validation strategy
- Rollout / rollback
- Risks
- Design concerns
- Open questions

## Final output

- Passes run and why the loop stopped (threshold met / cap hit / not converged / review blocked).
- Final plan.
- Finding ledger (including rejected and deferred findings and why).
- Execution-readiness gate result.
- Risk model coverage and any classes marked `n/a`.
- Chosen path (Simpler plan vs Hardcore plan) when complexity findings existed.
- Open findings below threshold, listed not fixed; open questions routed to the user.
