---
name: review-plan-cycle
description: Refine an implementation plan through bounded independent risk and objective review, evidence-based decisions, and focused verification of material refinements. Use before implementation when iterative plan review is requested.
---

# review-plan-cycle

Load [review-cycle-core](../review-cycle-core/SKILL.md) and follow its Run sheet. Planning only: refine the plan, never execute its implementation steps or edit production code. Core owns scheduling, budgets, severity, triage, verification, and completion.

## Capture the plan

Record the user's objective/acceptance criteria, the exact plan text/version, target modules, directly affected boundaries, applicable risks, and grouped validation targets. Supply the captured plan and original intent to reviewers; do not make them rediscover either. Record relevant code/docs consulted as feasibility evidence. Changes to those inputs invalidate affected conclusions.

The scope map is a starting hypothesis. Reviewers may inspect direct callers, consumers, dependencies, persisted formats, and boundary contracts beyond the named files to test feasibility or identify an omitted requirement. Update the map from that evidence; avoid unrelated repository surveys. Lockstep deployment does not remove old-data, migration, or rollback requirements.

## Coverage and assignments

Keep two logical axes: **Risk** (is the plan feasible and sound?) and **Objective** (does it deliver the user's request?). Use core's tier budget: one reviewer covers both for Lightweight; separate them for Standard; group related risks among a small number of reviewers for Full. Risk classes are checklist coverage, not mandatory agent counts. Reuse unaffected coverage after refinements.

Assign only relevant checks:

- Architecture, concurrency, and lifecycle: boundaries, ownership, ordering, cancellation, retries/timeouts, stale completions, shutdown, queues/backpressure, and wake-up/progress conditions.
- State, data, and contracts: mutation authority, tokens/versions/transactions, persistence/cache freshness, APIs, compatibility, migration, partial failure, and rollback.
- Security/privacy: trust boundaries, authorization, secrets, permissions, and exposure.
- UX/operations: required flows, empty/error/loading/degraded states, accessibility, observability, and rollout where applicable.
- Validation/testability: deterministic acceptance evidence, faithful seams, required project checks, and grouped narrow commands. Flag a missing harness only when a required behavior cannot otherwise be verified.

## Reviewer prompts

Inject core's report contract, relevant checks, current evidence/ledger, and captured inputs.

**Risk:** Review assigned risks against the user's objective and verify claimed existing commands, APIs, and state behavior against direct code/docs. Cite unsupported assumptions as `needs-verification`, naming the decisive check. Instantiate adverse timelines: stale completion, cancellation after a side effect, quiet event sources, retry storms, partial rollout, or permission bypass where relevant. Explain the requirement affected by a missing lifecycle, contract, migration, or validation detail. Apply core's simplicity criteria; a layer or single adapter is not automatically a defect. Give the smallest plan refinement that addresses the evidence.

**Objective:** Identify an acceptance criterion no step delivers, delivers partially or wrongly, an unrequested step, or criteria that cannot be tested. Quote the user's requirement and cite the plan step. Preserve necessary supporting implementation steps; absence of a literal user request for a helper, migration, or test is not by itself scope creep. Keep risk/design findings under Risk.

## Refine and verify

Use core's dispositions. Resolve a technical unknown with the cheapest decisive source inspection or a confirming assignment now; it need not wait for an edit. Defer only a nonblocking implementation choice with an owner and enough constraints to proceed. A real product conflict goes to the user; a routine correction remains authorized work.

Batch accepted refinements and record changed assumptions/invariants and rationale. Every material change to steps, contracts, ownership, acceptance criteria, or validation needs focused independent verification of its consequences on the final plan. A prior reviewer can verify the delta across both axes; do not restart all risk reviews. Pure explanatory wording needs no new assignment. Apply core's completion table when evidence, coverage, or budget is incomplete.

For an evidenced structural problem, compare the smallest workable alternatives first. **Design It Twice** is optional when an unresolved, consequential interface decision benefits from independent alternatives: use at most two assignments from the existing budget, concurrently when slots permit, and reserve delta verification. Ask for distinct interfaces/invariants, a usage example, and concrete trade-offs. Do not create a separate design tournament for an ordinary simplification. A chosen design can be corrected when new evidence invalidates it; arbitrary reversals cannot consume the remaining budget.

## Execution readiness and output

Use a compact plan containing objective/acceptance criteria, assumptions, ordered steps and targets, affected contracts, validation strategy, and unresolved risks/owners. Include conventions, state/lifecycle detail, migrations, and rollout/rollback only where relevant. Group shared commands rather than repeating one for every step. Carry necessary project conventions and core's comment guidance in substance; useful explanations do not make a plan defective.

Check readiness:

- Steps are concrete, feasible, and verifiable against the original objective, with no hidden blocking unknown or unauthorized expansion.
- Touched interfaces and persisted-data transitions are addressed. Async/state boundaries specify the relevant mutation authority, ordering, cancellation/retry/progress, and stale/partial-result handling.
- A faithful acceptance approach exists for each required risky behavior; use deterministic automation where feasible and explain any necessary manual validation. Required project checks are retained; broad runs have an actual coverage reason.
- Applicable failure recovery and rollback are addressed. Nonblocking choices have owners and constraints; blocking choices are resolved or explicitly accepted as risks by the user.
- The final material refinements have independent coverage, and finding/evidence state matches this plan version.

Return the final plan, objective/risk coverage, decisions and unresolved evidence, readiness outcome, and core's cost counters. Do not call the plan execution-ready merely because the last review produced no edit.
