---
name: review-plan-cycle
description: Iterative plan-review loop for Codex or Claude Code. Spawn fresh-context read-only reviewers on an implementation plan (no edits), triage findings, refine the plan in the main session, and repeat until design/plan findings drop below a severity threshold or a pass cap is hit. Use this to harden a plan before any code is written.
---

# review-plan-cycle

Run plan-review passes until remaining findings fall below the stop threshold. This skill runs the shared review loop over an implementation **plan** — the subject is the plan, not a diff. Its sibling `review-fix-cycle` does the same for code diffs.

**REQUIRED SUB-SKILL:** load `review-cycle-core` for the loop mechanics — spawning fresh reviewers, triage discipline, the ledger, the stop rule, and the ADR / ubiquitous-language discipline. This skill supplies only the plan-specific specializations below.

## What this skill does

Planning only — **no code edits, no refactors, no implementation steps executed.** The output is an execution-ready plan with technical and design concerns surfaced early.

## Plan scope (core step 1, specialized)

A few lines, captured once before pass 1:

- intent / acceptance criteria (what "done" means).
- the plan under review (link or inline; keep it in the Plan format below).
- boundaries the plan touches — exported/public interfaces, API/RPC or data-model shapes, cross-process/cross-language boundaries, on-disk/wire formats, persisted state, config/flags, migrations. A reviewer can't flag a contract break the plan never named. These populate the plan's **Contracts/migrations touched** field — name them once, there.
- a **Plan risk model** (see Risk model) naming every relevant risk class. If a class is not relevant, mark it `n/a` with a short reason. Do not leave this implicit.
- thresholds and cap if overriding the defaults (the Stop rule lives in `review-cycle-core`).

## Triage states (core triage, specialized)

Mark each finding **accept / reject / defer**, and record why. *Reject* taste disagreements you've considered and settled — a reviewer's architectural preference is not automatically correct. *Defer* anything that's genuinely an implementation-time decision, not a plan blocker.

A finding the reviewer marked `needs-discussion` (unsure the concern is real) is not a fourth state — resolve it: a feasibility/technical doubt gets at most one more read-only reviewer this pass; a product/scope decision only the user can make (priorities, intent, acceptable trade-offs) means **stop and ask the user** rather than letting reviewers churn on an undecidable point.

## Refine & record (core step 5, specialized)

Refine the plan from accepted findings — main session only — then record in the ledger: `finding → accept/reject/defer (why) → plan change`.

- For every accepted finding, record any **new invariant** the refined plan now depends on.
- For every accepted **High** finding that changes architecture, lifecycle, state ownership, public contracts, or rollout strategy, the next pass must explicitly review the consequences of that change before returning to general review.
- When a pass ran **Design It Twice** for a complexity/architecture finding, record the chosen design and its rationale so the next reviewer can validate the direction.

Before declaring the loop done, run the **Execution-readiness gate**.

## Risk model

Before pass 1, classify the plan against these generic risk classes. Use the classification to choose reviewer scopes and to make the first pass adversarial rather than merely broad.

- **Concurrency / lifecycle** — async tasks, actors, locks, cancellation, retries, timeouts, stale completions, drop/shutdown behavior, queues, backpressure.
- **State / data / migrations** — schemas, persisted state, cache freshness, derived data, migrations, compatibility with existing records.
- **API / contract boundaries** — public functions, CLI flags, RPCs, wire formats, cross-process or cross-language contracts, versioning, backward compatibility.
- **Security / privacy / permissions** — auth, authorization, secrets, permissions, trust boundaries, untrusted input, data exposure.
- **UX / operations / rollout** — user-facing behavior, errors, degraded modes, observability, rollout, rollback, feature flags, operational safety.
- **Validation / testability** — deterministic harnesses, acceptance tests, failure injection, regression coverage, monitoring signals.

For any relevant risk class, the plan must either address it directly or name it as a risk with an explicit owner/decision. A reviewer should treat an unaddressed relevant risk class as a plan gap.

## Design vocabulary (use these terms exactly)

Borrowed from deep-module design so complexity findings are reproducible, not taste. Use the terms in the reviewer prompt, the Design concerns section, and the ledger.

- **Deep vs shallow module** — deep = small interface, lots of behavior behind it; shallow = interface nearly as complex as the implementation (a pass-through). Prefer deep.
- **Interface** — everything a caller must know to use a module correctly: signature *plus* invariants, ordering, error modes, required config, performance characteristics. **Seam** — the place where that interface lives (its own design decision). **Adapter** — a concrete thing satisfying an interface at a seam.
- **Leverage** — what callers gain from depth (more behavior per unit of interface learned). **Locality** — what maintainers gain (change, bugs, knowledge, verification concentrate in one place).
- **Deletion test** — imagine deleting the module: if complexity vanishes it was a pass-through; if it reappears across N callers it earned its keep.
- **One adapter = a hypothetical seam; two = a real one** — don't plan a seam or abstraction unless something actually varies across it.

## Design It Twice (resolving a High architecture/complexity finding)

When a pass accepts a **High** finding about module/interface/seam shape, don't settle it by guessing — explore in parallel:

1. Spawn **3+ fresh read-only sub-agents**, each designing the interface a *radically different* way: minimize the interface (1–3 entry points, max leverage each); maximize flexibility/extension; optimize the most common caller (trivial default case); ports & adapters around a cross-seam dependency.
2. Each returns: the interface (types, methods, params, plus invariants/ordering/error modes); a usage example; what the implementation hides behind the seam; the dependency/adapter strategy; trade-offs (where leverage is high, where thin).
3. Compare on **depth**, **locality**, and **seam placement**. Fold the winner into the plan and graft the best ideas from runners-up. Be opinionated. Record the choice and rationale in the ledger.

## Execution-readiness gate (the plan-loop's validation)

A plan can't be compiled, but the main session checks this gate before declaring the loop done, confirming the plan is ready to hand to an implementer:

- Every step is concrete and verifiable — no "figure out X later" hiding a real unknown.
- Acceptance criteria are stated and testable.
- Contracts/migration touchpoints from the plan scope are addressed.
- Lifecycle, ownership, cancellation, timeout, retry, and backpressure behavior are specified for every touched async/task/actor/control-flow boundary, or explicitly marked `n/a`.
- State mutation authority is specified: which component may mutate which state, under what token/version/lock/transaction, and how stale or partial results are discarded.
- Rollout/rollback (or "n/a, why") is considered.
- A deterministic validation approach is named for every High-risk behavior; "test manually" is not enough for correctness-critical behavior unless no automated hook is feasible and the plan explains why.
- Open questions are resolved or explicitly deferred with an owner.

If any of these is missing, the plan is not execution-ready regardless of finding count. If the gate fails when the Stop rule would otherwise end the loop, do not silently finish: fix the gap in another pass if the cap allows, otherwise stop and report **not converged** with the specific gate gap listed.

## Scopes (for multi-reviewer fan-out)

Split a large plan by concern; fold the relevant ones into a single prompt for a small plan:

- **Architecture / state / lifecycle** — module/service boundaries, coupling, sequencing, blast radius, async/task lifecycle, cancellation safety, stale completions, queue bounds, backpressure, ownership of state mutations.
- **Data model & API shape** — schema/contract changes, compatibility, versioning, migrations, public interfaces, cross-process/cross-language boundaries.
- **Security/privacy** — auth/secrets, untrusted input, permissions, trust boundaries, data exposure introduced by the design.
- **UX/interaction** (when the plan includes user-facing flows or interaction design) — flows, states, error/empty/loading, accessibility implications.
- **Testability/rollout/observability** — how the plan will be validated, failure injection, feature flags, staged rollout, rollback, monitoring and diagnostics.

For plans with more than one relevant risk class, prefer fan-out by risk class over one generic reviewer. For small plans, one reviewer may cover multiple scopes, but the prompt must still list the relevant risk classes.

## Reviewer prompt (base)

Specialize with the plan scope and scope focus:

"Read-only planning review — do not edit files. Review the implementation plan only. You may read existing code **only** for the files/modules named in the plan scope, and only to sanity-check feasibility — do not survey the wider codebase. Use the project's domain glossary terms exactly, and respect ADRs in the touched area — do not re-litigate a decision an ADR already settled; if you think one should be reopened, say so explicitly and why.

List actionable findings first, ordered by severity (High/Medium/Low), each referencing the plan step/section and with a one-line justification. Include design concerns for your assigned risk scope: architecture/state/lifecycle, API/data-model shape, UX/interaction implications when relevant, security/privacy, validation/rollout/observability, and maintainability of the planned approach.

Judge design with the Design vocabulary: prefer **deep** modules (small interface, lots of behavior); flag **shallow** modules (pass-throughs — apply the **deletion test**), leaky seams, and **speculative** seams (one adapter is a hypothetical seam, two is a real one).

Verify claimed existing behavior against the scoped code/docs when feasible. If the plan says an existing command/API/state machine already behaves a certain way, either cite where that is true or flag the claim as unverified/incorrect.

Think adversarially. Include any applicable failure timelines: stale async completion after reconnect/invalidation, cancellation after partial side effect, actor/task drop or leak, queue growth or backpressure, cache staleness, retry storm, old/new version compatibility, rollback after partial rollout, permission/auth bypass, degraded dependencies, and observability blind spots.

Flag any step that is vague, unverifiable, or hides an unresolved unknown; any missing lifecycle/drop/timeout/retry/backpressure semantics; any unclear state-mutation authority; and any contract/migration/rollback/test-harness gap. If unsure a finding is real, mark it `needs-discussion` rather than asserting it. If the plan is over-complex, offer a **Simpler plan** (minimal change); for a High finding about module/interface/seam shape, recommend running **Design It Twice** rather than guessing a single redesign. If nothing is at/above Medium, say so. Do not edit files."

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
- Design concerns (in Design vocabulary terms)
- Open questions

## Final output (core skeleton, specialized)

- Passes run and why the loop stopped (threshold met / cap hit / not converged / review blocked).
- Final plan.
- Finding ledger (including rejected and deferred findings and why).
- Execution-readiness gate result.
- Risk model coverage and any classes marked `n/a`.
- Chosen design when complexity findings existed (Simpler plan, or the Design It Twice outcome).
- Open findings below threshold, listed not fixed; open questions routed to the user.
