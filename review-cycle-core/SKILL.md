---
name: review-cycle-core
description: Shared execution rules for review-plan-cycle and review-fix-cycle, including bounded independent review, evidence-based triage, delta verification, and convergence. Load with either calling skill; not a general review trigger.
---

# review-cycle-core

The calling skill supplies the subject and domain checks. This skill owns scheduling, triage, and completion. Only the main session edits the subject; independent agents review it. Preserve the user's scope and existing authorization.

## Run sheet

1. Read applicable `AGENTS.md` / `CLAUDE.md`, decisions, and glossary. Capture the calling skill's scope map and subject version.
2. Choose a tier and assign coverage. Announce initial reviewers, total review budget, available concurrency, and scoped validation. Reserve capacity for verifying material fixes.
3. Launch independent assignments concurrently up to available slots. Hand over the captured subject, relevant boundary context, intent, assigned checks, severity/threshold, and report contract below. Work on independent preparation; otherwise use the harness's notification/wait mechanism.
4. Collect the affected assignments before editing their shared subject. Deduplicate and triage all findings; resolve evidence gaps now. Apply accepted fixes in one batch, then validate and independently verify material changes, concurrently where their inputs and resources permit.
5. Update finding, coverage, and validation state. Continue only for a named unresolved check or affected delta within budget. Evaluate the completion table after each batch; closing finding keys alone is insufficient.
6. Report the result, evidence, unresolved work, and actual cost counters.

## Scope and evidence

Review the requested behavior and regressions in paths affected by the same mechanism. Direct caller, consumer, dependency, and boundary inspection is allowed even when the initial map omitted a file; update the map. Do not turn that inspection into an adjacent bug hunt.

Routine corrections needed for the authorized deliverable remain in scope. Ask only when a necessary edit adds a repository, service, public surface, platform, or deliverable outside existing authorization, or when requirements genuinely conflict. Record unrelated suggestions without building them.

Respect documented decisions while checking their applicability. Lockstep deployment may exempt mixed-version communication; it does **not** exempt persisted-data migration, old caches/files, partial rollout, or rollback. New evidence invalidating an assumption may reopen a decision with an explicit explanation.

## Effort and scheduling

Size by actual changed mechanisms and consequences, not the number of checklist labels. Validation and UX do not each force another reviewer. Group related risks under one owner without omitting coverage.

| Tier | Subject | Initial assignments | Total review assignments | Edit batches |
|---|---|---|---|---|
| Lightweight | Small, locally understandable change or plan; one bounded mechanism, no security or external contract change | 1, covering both calling axes with separate findings | 2 | 1 |
| Standard | Contained multi-file work, including internal lifecycle/concurrency | 2, the calling axes | 4 | 2 |
| Full | Security boundary, public/wire/on-disk contract, migration, ownership across components/processes, or large independent change surfaces | Up to 3: grouped risk scopes plus objective/spec | 8 | 3 |

An assignment is an initial audit, delta audit, confirming review, or design exploration. Follow-up audits count even on an existing agent. Retrieving already-produced findings or one factual clarification continues the original assignment. Edit batches count subject refinements, not temporary regression-test states. These limits govern new review assignments and edit batches, not completion of already-started work or main-session evidence/validation checks. User-specified budgets take precedence. Re-size only for authorized scope changes; do not buy extra budget by renaming review-induced growth.

Reserve at least one assignment for material-delta verification; use the others only for concrete uncovered risks. Budget exhaustion is a reporting boundary, never evidence of correctness. Prefer one focused existing reviewer over respawning an unaffected axis. Do not repeat clean validation or settled coverage just to spend the remaining budget.

Use the host's actual concurrency limit, including the parent and other active agents. Queue assignments when slots are occupied; fewer slots do not mean review is blocked. With one child slot, run distinct assignments sequentially. Start independent work together when supported; a single tool message is not a correctness requirement.

Do not impose reviewer deadlines or equate slowness with failure. Use supported waits without busy polling or inventing extra work. On reported failure/disconnection, preserve completed coverage and retry only the missing assignment within budget; unavailable required resources are a real blocker. Let active in-scope reviewers finish.

## Reviewer execution

Inspect available tool parameters once; do not hardcode a host/version's spawn schema. Initial reviewers start with separate, fresh context (for example `fork_turns: "none"` or `fork_context: false` only where exposed). Later delta verification may reuse an independent reviewer who did not author the changes. A contested rejection gets an independent check without the author's rejection rationale; do not ask a reviewer merely to repeat its own claim.

Honor a requested model. Otherwise explicitly select a supported mid-tier reviewer model and suitable reasoning effort where available; do not assume `explorer` or a CLI default selects one. Use a configured review agent/profile if needed. If selection is unavailable, disclose the inherited/unknown setting and use the available reviewer within budget; do not change global configuration. A harder model or extra reviewer needs a specific unresolved reasoning task, not a blanket fan-out.

Enforce read-only permissions where the host supports them. An `explorer` label or a prompt is not a sandbox; inspect effective permissions, including inherited overrides. When enforcement is unavailable, retain the no-edit contract and report that limitation rather than claiming isolation.

If native delegation is absent, use independent CLI processes only if available and authorized. For a CLI exposing these options, a concrete fallback is `codex exec --sandbox read-only --model MODEL --config 'model_reasoning_effort="medium"' --cd REPO --output-last-message REPORT -`, with the self-contained prompt on stdin. Substitute verified values using structured arguments or safe shell quoting; give each process a separate report path. Capture exit status and output, and check available flags first. No usable independent reviewer means **blocked**, not self-review passed.

## Report contract (inject with the rubric)

> Review read-only; do not edit, spawn agents, or run builds, tests, benchmarks, or profilers. Audit the assigned subject and directly affected boundaries against the supplied intent. The main session owns measurements. Continue until assigned coverage is exhausted, then return findings together.
>
> For each finding give severity, axis, file/line or plan step, defect, concrete triggering state and outcome, evidence, and the smallest remedy or verification check. Use enough detail to substantiate the claim; uncertainty is `needs-verification`, not a proven defect. Omit taste-only nits. If no blocking findings exist, say so.
>
> Report every defensible High/Medium finding. A brief main report may link a harness-managed overflow artifact if supported; otherwise return the findings in text. Never silently discard overflow. State `coverage: complete` or `incomplete`, the subject version, and any uninspected scope, output truncation, or unavailable evidence. Missing output is not a clean review.

## Severity and triage

- **High:** demonstrated serious wrong behavior, data loss, broken required contract, memory/security defect, or a plan that entails one.
- **Medium:** a concrete lesser behavior defect, material performance risk, missing acceptance requirement, or evidenced fragility/testability/maintenance problem in the touched mechanism.
- **Low:** taste, naming, polish, or speculative future cost. Never blocks by default.

**Default blocking threshold: High and Medium.** The user may explicitly choose another threshold or accept a specific residual risk. Do not silently downgrade severity to finish. Unresolved evidence for a plausible at-threshold finding remains pending; uncertainty is not acceptance or rejection.

Read the cited subject before deciding. Deduplicate by stable location/requirement + failure mechanism across reviewers and batches. Dispositions are `accept`, `reject` with evidence, `needs-verification`, or `defer` with owner/reason. Defer only nonblocking implementation details or explicitly accepted residual risks; deferral alone cannot clear a blocker.

Resolve technical doubt using the cheapest decisive source read or main-session check. One factual clarification to the existing reviewer is allowed. If independent judgment is still needed, schedule one confirming assignment **now**, within the budget, even if no edit has occurred. Confirmation must precede a decision depending on it; it never requires a fictitious next pass. An unsupported suggestion can be rejected as such; a disputed, evidence-backed blocker remains open until resolved or explicitly accepted by the user.

## Delta verification and anti-oscillation

Track review coverage separately from findings. A **material delta** changes behavior, a contract, algorithm, ownership/lifecycle, acceptance criteria, validation meaning, or an executable plan step. It requires independent verification on its final version, plus affected-boundary checks. Pure formatting, links, and explanatory wording that change none of these can be checked locally. Closing a finding does not cover the resulting delta.

After a fix, give a prior independent reviewer the exact delta, current relevant context, affected requirements, and regression/validation evidence. Reuse unaffected coverage. Ask only for correctness, objective, and boundary consequences of this delta; one reviewer can cover multiple affected axes. Verification may run alongside scoped validation on that same frozen state. If another material edit follows, invalidate only its affected coverage and validation.

Incomplete or truncated coverage remains queued even on unchanged code. Retrieve omitted findings or audit the missing scope within budget. The no-duplicate-work rule does not prohibit filling a coverage gap or resolving a contested finding.

Allow correction of a review-introduced regression when evidence improves and the earlier requirement remains satisfied. Overlapping lines, duplicate reports in one batch, or fewer findings are not convergence tests. Record what new evidence changed the decision. If the same key returns after two reasoned dispositions with **no new evidence**, freeze that key and report unresolved disagreement. Do not undo other validated work or freeze unrelated fixes. Genuinely incompatible requirements go to the user; an ordinary technical correction does not.

## Ledger and completion

Keep a compact current ledger with an append-only decision history; send reviewers only relevant entries and invariants. For an unresolved rejection, omit the author's rationale from an independent confirmation prompt while supplying raw evidence. Preserve artifacts across context loss, outside the deliverable unless requested.

- Finding: `key → severity/axis → evidence → disposition/reason → fix version → verification → residual risk/owner`.
- Coverage: `scope/axis → reviewed subject + dependency state → complete/incomplete → material delta pending`.
- Validation: the calling skill's targets, input state, and result.

Evaluate in order:

| Condition | Outcome |
|---|---|
| Required, unwaived evidence/tool/reviewer unavailable | **blocked**, naming the missing capability and completed work |
| User decision required, unresolved disagreement, or remaining unwaived work requires review assignments/edit batches beyond their budgets | **not converged**, with the exact remaining work |
| Complete subject coverage, every material delta independently verified, readiness gate satisfied, no unresolved at-threshold findings and no risk waivers | **converged** |
| Same requirements satisfied except for specific gaps/risks explicitly accepted by the user | **complete with accepted risks**, listing the waivers; never imply the missing check passed |
| Anything else | Perform the next named check within budget; no blanket restart |

No-edit, cap reached, all original keys closed, or a successful test alone is not convergence. Preserve current work on exit; never restore an entire checkout to an old green snapshot.

## Simplicity and final output

Prefer the smallest remedy that satisfies every affected requirement without worsening a relevant performance bound. A deep module exposes little callers must learn; evaluate locality, invariants, and dependency direction. One implementation or a forwarding layer is a question to investigate, not proof that a seam is unnecessary. Require a concrete maintenance cost and minimal remedy before accepting structural work.

Prefer clear names and concise code. Comments are useful for non-obvious invariants, rationale, hazards, and contracts; remove narration, not necessary explanations. Do not refactor merely to avoid writing a useful comment.

Report in the user's language: outcome and scope; accepted/rejected/deferred/open findings with evidence; validation and coverage gaps; residual risks and user decisions. Include tier, edit batches, assignments, actual agent/model settings where known, and checks reused. Use already available timing/token counters to distinguish wall time from total work; never add a benchmark to an ordinary run or claim an unmeasured speedup.

For skill maintenance only, [evaluation cases](evals/cases.json) exercise scheduling and completion decisions. They are not part of a normal review run. Give an independent evaluator only each case's input and these skills, then compare its next actions/outcome with the expected invariants.
