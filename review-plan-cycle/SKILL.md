---
name: review-plan-cycle
description: Iterative plan-review loop for Codex or Claude Code. Spawn fresh-context read-only reviewers in parallel on an implementation plan (no edits), triage findings, refine the plan in the main session, and repeat until design/plan findings drop below a severity threshold or a pass cap is hit. Use this to harden a plan before any code is written.
---

# review-plan-cycle

Plan-review passes over an implementation **plan** until findings fall below the stop threshold. Planning only — **no code edits, no refactors, no steps executed**; the output is an execution-ready plan with its technical and design concerns surfaced early. Sibling `review-fix-cycle` does this for code diffs.

**REQUIRED SUB-SKILL:** load `review-cycle-core` and run its Run sheet. It owns the loop — effort tiers, the four standing limits, parallel spawning, the one-shot report contract, triage, the ledger, anti-oscillation, the stop rule, the simplicity bar and design vocabulary, and comment/ADR/glossary discipline. This skill adds only the plan specifics.

**How the limits read for a plan:** a plan is cheap to read, so spawn every risk class at once — breadth costs a pass no wall time, sequencing does. And a plan that gains scope during review is a plan the user must re-approve: extra phases, abstractions, or adjacent work the intent never named are a `scope note` routed to the user, never a silent new step.

## Plan scope (core step 1)

A few lines before pass 1, injected into every reviewer prompt:

- intent / acceptance criteria (what "done" means).
- the plan under review (link or inline, in the Plan format below).
- boundaries it touches — exported/public interfaces, API/RPC or data-model shapes, cross-process or cross-language seams, wire/on-disk formats, persisted state, config/flags, migrations. A reviewer can't flag a contract break the plan never named; these populate the plan's **Contracts/migrations touched** field.
- the risk classes below that apply, each `n/a`'d with a reason if not.
- thresholds and cap only if overriding the core's defaults.

## Risk classes (they are the reviewer scopes)

Classify before pass 1 and make pass 1 adversarial on what applies rather than broad. For each relevant class the plan must either address it or name it as a risk with an owner — an unaddressed relevant class is a plan gap.

- **Architecture / concurrency / lifecycle** — boundaries, coupling, sequencing, blast radius; async tasks, actors, locks, cancellation, retries, timeouts, stale completions, shutdown, queues, backpressure, ownership of mutations.
- **State / data / API contracts** — schemas, persisted state, cache freshness, derived data; public functions, CLI flags, RPCs, wire formats, cross-process or cross-language contracts, versioning, migrations, compatibility with existing records.
- **Security / privacy / permissions** — auth, authorization, secrets, trust boundaries, untrusted input, data exposure.
- **UX / operations / rollout** — flows, user-facing behavior, error/empty/loading states, accessibility, degraded modes, observability, flags, staged rollout, rollback.
- **Validation / testability** — deterministic harnesses, *scoped* acceptance tests, failure injection, regression coverage, monitoring signals.

## Two axes per pass, always concurrent

Every pass spawns at least two reviewers in one message, and their reports stay separate in triage: a plan can be sound on every risk class and still not achieve what the user asked for.

- **Risk** — one reviewer per relevant risk class above (all of them, together).
- **Objective** — does the plan, executed as written, satisfy the stated intent and acceptance criteria? Missing or partial requirements, steps the objective never asked for, acceptance criteria that aren't testable.

## Triage states

**accept / reject / defer**, recording why. *Reject* taste disagreements you have considered and settled — a reviewer's architectural preference is not automatically correct. *Defer* what is genuinely an implementation-time decision rather than a plan blocker. A reviewer's `needs-verification` is not a fourth state: a technical doubt gets at most one more read-only reviewer, launched with the next pass; a product or scope call only the user can make means **stop and ask the user**. Two reviewers pushing a step in opposite directions is a frozen trade-off for the user (core: no reversals), not a third rewrite.

## Refine & record

Refine the plan from accepted findings — main session only — recording `key → finding → accept/reject/defer (why) → plan change`, plus:

- any **new invariant** the refined plan now depends on.
- for an accepted **High** that changes architecture, lifecycle, state ownership, public contracts, or rollout, the next pass reviews *that change's consequences* before returning to general review.
- when a pass ran **Design It Twice**, the chosen design and its rationale, so the next reviewer can validate the direction.

Then run the Execution-readiness gate before declaring the loop done.

## Simplicity on a plan

Core owns the bar and the vocabulary. On a plan it lands as: a step introducing a seam nothing yet varies across; a module the **deletion test** says is a pass-through; an interface whose invariants and error modes the plan never states; a phase that exists only to enable a later phase nobody asked for. **Simpler plan** is the default counter-proposal; **Design It Twice** is for the case below.

## Design It Twice (only for an accepted High about module/interface/seam shape)

Don't settle it by guessing — explore in parallel, in one message:

1. Spawn **three fresh read-only sub-agents concurrently** (a fourth only for a genuinely distinct axis), each designing the interface a *radically different* way, drawn from: minimal interface (1–3 entry points, max leverage); maximum flexibility; optimized for the commonest caller; ports & adapters around a cross-seam dependency.
2. Each returns the interface (types, methods, params, invariants, ordering, error modes), a usage example, what stays hidden behind the seam, the dependency/adapter strategy, and trade-offs.
3. Compare on **depth**, **locality**, and **seam placement**; fold the winner in, graft the best of the runners-up, record the choice with its rationale. Be opinionated — the choice is settled once and a later pass does not reopen it (core: two strikes).

## Implementation conventions the plan must carry

The implementer will not infer conventions — state them once in the plan's **Implementation conventions** field, carrying core's **Comment discipline** verbatim in substance (default no comments; only a fact the code cannot show; ~1–2 lines; decided on the first write). A step that is only understandable with a comment is a step to simplify.

## Execution-readiness gate

A plan can't be compiled, so before declaring the loop done confirm it is ready to hand over:

- every step concrete and verifiable — no "figure out X later" hiding a real unknown; acceptance criteria stated and testable.
- contracts and migration touchpoints from the plan scope addressed.
- lifecycle, ownership, cancellation, timeout, retry, and backpressure specified for every touched async/task/actor boundary, or marked `n/a`.
- state-mutation authority specified: which component may mutate which state, under what token/version/lock/transaction, and how stale or partial results are discarded.
- rollout/rollback considered (or "n/a, why").
- a deterministic validation approach named for every High-risk behavior; "test manually" only where no automated hook is feasible and the plan says why.
- validation **scoped**: each step names the narrowest command covering its seams, and any full-suite, device, simulator, or e2e run appears once, as a final check, with a reason.
- the objective still matches the user's stated intent — no step added during review widened it.
- open questions resolved or deferred with an owner; implementation conventions stated.

A gap means the plan is not execution-ready regardless of finding count: close it within the cap, else stop as **not converged**, naming the gap.

## Reviewer prompts

Specialize with the plan scope and the reviewer's risk class; inject the severity rubric, one-shot contract, design vocabulary, and factual ledger. Paste the plan in — never make a reviewer go find it.

**Risk:**

"Read-only planning review — do not edit files. Review the implementation plan only. You may read existing code **only** for the files and modules the plan scope names, and only to sanity-check feasibility — do not survey the wider codebase. Use the project's glossary terms exactly and respect ADRs in the touched area (to reopen one, say so and why).

Judge the plan against the objective it states — not against a larger plan you would have written. Do not propose additional phases, surfaces, abstractions, or adjacent work the objective does not call for; if you believe the objective itself is too narrow, say so in one line labelled `scope note`, which routes to the user, who owns scope. Flag any Validation strategy that reaches for a full suite where a scoped target would do, and any step naming no narrow command for its own seams.

Report findings per the injected contract, each referencing the plan step or section, covering your assigned risk class and nothing else.

Judge design with the injected design vocabulary: prefer **deep** modules; flag **shallow** ones (apply the **deletion test**), leaky seams, and **speculative** seams (one adapter is hypothetical, two is real). Simpler is better only while the plan stays correct and efficient — never propose dropping a case, a bound, or a guard to shrink a step.

Verify claimed existing behavior against the scoped code or docs: if the plan says a command, API, or state machine already behaves a certain way, cite where that is true or flag the claim as unverified.

Think adversarially about the failure timelines your class covers: stale async completion after reconnect or invalidation, cancellation after a partial side effect, task drop or leak, queue growth, cache staleness, retry storm, version compatibility, rollback after partial rollout, permission bypass, degraded dependencies, observability blind spots. Flag any vague or unverifiable step, missing lifecycle/timeout/retry/backpressure semantics, unclear state-mutation authority, and any contract, migration, rollback, or test-harness gap. Mark anything you are unsure of `needs-verification`. If the plan is over-complex, offer a **Simpler plan**; for a High about module/interface/seam shape, recommend **Design It Twice** rather than guessing one redesign."

**Objective:** "Read-only plan review — do not edit files. Read the plan and the stated intent/acceptance criteria at `<path or contents>`. Report **only** objective-conformance findings: **(a)** an acceptance criterion no step delivers, or delivers partially; **(b)** a step the objective never asked for (scope creep); **(c)** a step that would deliver a requirement wrongly; **(d)** an acceptance criterion stated so it cannot be tested. Quote the intent line for each and reference the plan step, using glossary terms exactly. No design or risk findings — that is the other axis. Run no builds or tests."

## Plan format

Objective · Acceptance criteria · Assumptions · Ordered steps · File/module targets · Contracts/migrations touched · Risk classes · Implementation conventions · Validation strategy (narrowest command per step) · Rollout / rollback · Risks · Design concerns (in the design vocabulary's terms) · Open questions

## Final output (core skeleton, plus)

- The final plan, and the ledger including rejected, deferred, and frozen findings.
- Objective axis: unmet or partial acceptance criteria, scope creep, untestable criteria — or "objective fully covered".
- Execution-readiness gate result; risk-class coverage and any class marked `n/a`.
- The chosen design where complexity findings existed (Simpler plan, or the Design It Twice outcome).
