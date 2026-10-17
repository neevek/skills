---
name: review-cycle-core
description: Shared execution rules for review-plan-cycle and review-fix-cycle, including bounded independent review, evidence-based triage, delta verification, and convergence. Load with either calling skill; not a general review trigger.
---

# review-cycle-core

The calling skill supplies the subject and domain checks. This skill owns scheduling, triage, and completion. Only the main session edits the subject, fixes included, because it holds the triage context; independent agents review it. Preserve the user's scope and existing authorization.

## Run sheet

1. Read applicable `AGENTS.md` / `CLAUDE.md`, `REVIEW.md`, decisions, and glossary. Capture the calling skill's scope map and subject version.
2. Choose a tier and assign coverage. Announce initial reviewers, total review budget, available concurrency, and scoped validation, reserving capacity to verify material fixes.
3. Launch independent assignments concurrently up to available slots, handing over the subject files and version, relevant boundary context, intent, assigned checks, severity/threshold, and the report contract below. Work on independent preparation while they run.
4. Collect the affected assignments before editing their shared subject. Deduplicate and triage all findings; resolve evidence gaps now. Apply accepted fixes in one batch, then validate and independently verify material changes, concurrently where inputs and resources permit.
5. Update finding, coverage, and validation state. Continue only for a named unresolved check or affected delta within budget, evaluating the completion table after each batch.
6. Report the result, evidence, unresolved work, and actual cost counters.

## Scope and evidence

Review the requested behavior and regressions in paths affected by the same mechanism. Direct caller, consumer, dependency, and boundary inspection is allowed even when the initial map omitted a file; update the map, but do not turn it into an adjacent bug hunt.

Routine corrections needed for the authorized deliverable remain in scope. Ask only when a necessary edit adds a repository, service, public surface, platform, or deliverable outside existing authorization, or when requirements genuinely conflict. Record unrelated suggestions without building them.

Respect documented decisions while checking their applicability. Lockstep deployment may exempt mixed-version communication; it does **not** exempt persisted-data migration, old caches/files, partial rollout, or rollback. New evidence invalidating an assumption may reopen a decision with an explicit explanation.

## Effort and scheduling

Size by changed mechanisms and consequences, not checklist labels; validation and UX do not each force another reviewer. Group related risks under one owner without omitting coverage, and split an owner's subject by path or mechanism, within budget, when it is too large for one pass rather than accept `coverage: incomplete`.

| Tier | Subject | Initial assignments | Total review assignments | Edit batches |
|---|---|---|---|---|
| Lightweight | Small, locally understandable change or plan; one bounded mechanism, no security or external contract change | 1, covering both calling axes with separate findings | 2 | 1 |
| Standard | Contained multi-file work, including internal lifecycle/concurrency | 2, the calling axes | 4 | 2 |
| Full | Security boundary, public/wire/on-disk contract, migration, ownership across components/processes, or large independent change surfaces | Up to 3: grouped risk scopes plus objective/spec | 40 | 3 |

An assignment is an initial audit, delta audit, confirming review, or design exploration; follow-up audits count even on an existing agent, while retrieving already-produced findings or one factual clarification continues the original assignment. Edit batches count subject refinements, not temporary regression-test states or non-material Low edits. The limits govern new assignments and batches, not completion of already-started work or main-session evidence and validation checks. User-specified budgets take precedence. Re-size only for authorized scope changes, never by renaming review-induced growth.

Edit batches, not assignments, bound review rounds; the larger Full total funds splitting a large subject by path or mechanism, not further rounds. Reserve at least one assignment for material-delta verification and use the rest only for concrete uncovered risks. Budget exhaustion is a reporting boundary, never evidence of correctness. Prefer one focused existing reviewer over respawning an unaffected axis. Do not repeat clean validation or settled coverage to spend remaining budget.

Use the host's actual concurrency limit, counting the parent and other active agents. Queue assignments when slots are full; fewer slots do not block review, and one child slot means running assignments sequentially. Start independent work together when supported; a single tool message is not a correctness requirement.

Do not impose reviewer deadlines or equate slowness with failure. Wait on the harness's completion notification or wait tool, not busy polling, invented work, or timed wake-ups that can fire after the work is done. On reported failure or disconnection, keep completed coverage and retry only the missing assignment within budget; unavailable required resources are a real blocker. Let active in-scope reviewers finish.

## Reviewer execution

Inspect the spawn tool's parameters once rather than hardcoding a host/version's schema. Initial reviewers start with fresh context (e.g. `fork_turns: "none"` or `fork_context: false` where exposed). Delta verification may reuse an independent reviewer who did not author the changes. A contested rejection gets an independent check without the author's rationale, not a reviewer repeating its own claim.

Honor a requested model and reasoning effort; otherwise:

- **Claude Code:** the `review-cycle-reviewer` agent type (this skill's `agents/review-cycle-reviewer.md`): Sonnet, medium effort, and read-only tools, so the host enforces the no-edit, no-build, no-spawn contract. The harder model is `model: "opus"` on the same type. If the type is not listed, use `general-purpose` with `model: "sonnet"`, report that read-only is then instruction-level only, and tell the user to symlink that file into `~/.claude/agents/`. Not `Explore`, which reads excerpts to locate code rather than audit it.
- **Codex:** `gpt-6-luna` at `max` effort, set on the spawn call with `fork_turns: "none"`, since a full-history fork inherits the parent's model and effort. The harder model is `gpt-6-astra` at `high`.
- **Other hosts:** an explicitly selected mid-tier model and suitable effort.

Neither an `explorer` label nor a CLI default selects a model. Enforce read-only permissions where the host supports them; neither a label nor a prompt is a sandbox, so check effective permissions, including inherited overrides. Where selection or enforcement is unavailable, disclose the inherited or unknown setting, use the available reviewer within budget, keep the no-edit contract, and report the limitation rather than claiming isolation; do not change global configuration. The harder model or an extra reviewer needs a specific unresolved reasoning task, such as a hotspot re-audit or a contested blocker, not a blanket fan-out.

Hand reviewers files, never pasted bytes or a moving ref. For code, run this skill's `scripts/snapshot.sh OUT_DIR BASE [PREV_TREE] [-- PATHSPEC...]` by absolute path from inside the repository under review, with `OUT_DIR` in the session scratch directory when the host has one (reviewers read it without a permission prompt), else `$(git rev-parse --git-path review-cycle)`. It records staged, unstaged, and untracked work as a tree ID without touching the index and writes the subject patch, plus the exact delta patch given the previous tree. The tree ID is the subject version: equal IDs mean nothing in the worktree changed, and `git diff --name-only` between IDs names the paths whose coverage and checks are affected. For a plan, write each version to its own file and diff versions with `git diff --no-index`. Include a digest of the project instructions already read, so reviewers need not re-read them; a `REVIEW.md`'s failure modes, skip paths, and nit limits for the touched areas go in with the rubric.

Without native delegation, use independent CLI processes only if available and authorized, e.g. `codex exec --sandbox read-only --model gpt-6-luna --config 'model_reasoning_effort="max"' --cd REPO --output-last-message REPORT -` with the self-contained prompt on stdin. Substitute the selected model/effort and verified paths, check flags first, quote safely, give each process its own report path, and capture exit status and output. No usable independent reviewer means **blocked**, not self-review passed.

## Report contract (inject with the rubric)

> Review read-only; do not edit, spawn agents, or run builds, tests, benchmarks, or profilers; the main session owns measurements. This prompt is your whole brief; do not load the review-cycle skills. Audit the assigned subject and directly affected boundaries against the supplied intent until assigned coverage is exhausted, then return all findings together.
>
> For each finding give severity, axis, defect class, every instance of that class in the assigned scope by file/line or plan step, concrete triggering state and outcome, evidence, and the smallest remedy or verification check. For code, give the origin: `introduced` by the subject, or `pre-existing` when the same defect is present on the base. Use enough detail to substantiate the claim; uncertainty is `needs-verification`, not a proven defect. Omit taste-only nits and cleanup-only or diagnostic suggestions; if nothing blocks, say so.
>
> Do not re-raise a supplied, already-dispositioned finding without new evidence. When given a delta, unchanged code is in scope only where the delta changes its behavior or holds another instance of a class the delta fixes.
>
> Report every defensible High/Medium finding. Never silently drop overflow; a brief main report may link a harness-managed artifact if supported, otherwise return the findings in text. State `coverage: complete` or `incomplete`, the subject version, and any uninspected scope, truncation, or unavailable evidence. Missing output is not a clean review.

## Severity and triage

- **High:** demonstrated serious wrong behavior, data loss, broken required contract, memory/security defect, or a plan that entails one.
- **Medium:** a concrete lesser behavior defect, material performance risk, missing acceptance requirement, or fragility/testability/maintenance problem in the touched mechanism with a concrete change or input that would break it.
- **Low:** taste, naming, polish, cleanup without such a trigger, or speculative future cost. Never blocks by default.

**Default blocking threshold: High and Medium.** The user may explicitly choose another threshold or accept a specific residual risk. Re-rate a finding whose evidence fails its severity's definition, recording why; never downgrade one to finish. Unresolved evidence for a plausible at-threshold finding remains pending; uncertainty is not acceptance or rejection.

Read the cited subject before deciding. Deduplicate by defect class + failure mechanism (or requirement) across reviewers and batches, so sibling instances share one key and are fixed in one batch. Dispositions are `accept`, `reject` with evidence and a reason (`wrong`, `intentional`, or `irrelevant`), `needs-verification`, or `defer` with owner/reason. Confirm a `pre-existing` origin against the base; such a finding does not block unless the subject makes it newly reachable or worse or fixing it is the stated intent, and is otherwise reported as pre-existing without being fixed. Defer only nonblocking implementation details or explicitly accepted residual risks; deferral alone cannot clear a blocker. Apply a Low finding only when its edit is non-material, and otherwise list it in the report; Low findings never justify a delta assignment.

Resolve technical doubt with the cheapest decisive source read or main-session check; one factual clarification to the existing reviewer is allowed. If independent judgment is still needed, schedule one confirming assignment **now**, within budget, even with no edit; a decision that depends on it waits for it, never for a fictitious next pass. An unsupported suggestion can be rejected as such; a disputed, evidence-backed blocker stays open until resolved or explicitly accepted by the user.

## Delta verification and anti-oscillation

Track review coverage separately from findings. A **material delta** changes behavior, a contract, algorithm, ownership/lifecycle, acceptance criteria, validation meaning, or an executable plan step, and needs independent verification on its final version plus affected-boundary checks. Pure formatting, links, local renames, and explanatory wording that change none of these can be checked locally. Closing a finding does not cover the resulting delta.

After a fix, give a prior independent reviewer the exact delta, relevant context, affected requirements, regression/validation evidence, and the keys already dispositioned for the affected scope, asking only for correctness, objective, and boundary consequences; one reviewer can cover several affected axes. Reuse unaffected coverage. Verification may run alongside scoped validation on the same frozen state. A later material edit invalidates only its affected coverage and validation.

Incomplete or truncated coverage stays queued even on unchanged code: retrieve omitted findings or audit the missing scope within budget. Filling a coverage gap or resolving a contested finding is not duplicate work.

Allow correcting a review-introduced regression when evidence improves and the earlier requirement stays satisfied. Record what new evidence changed a decision. Overlapping lines, duplicate reports in one batch, or fewer findings are not convergence tests. If the same key returns after two reasoned dispositions with **no new evidence**, freeze that key and report the disagreement, without undoing other validated work or freezing unrelated fixes. Genuinely incompatible requirements go to the user; an ordinary technical correction does not.

The same-key rule misses a **hotspot**, where each delta on one step or mechanism turns up a *new* key. Once delta reviews there have twice yielded a new at-threshold finding (initial-audit findings do not count), stop patching edge cases one at a time. Within the remaining budget, spend the next assignment on a single re-audit of the whole mechanism with the harder reviewer model, asking for the design that satisfies every requirement recorded against it; apply it as one batch and verify it like any material delta. For code, a design that replaces the change's approach rather than reworking the mechanism within it is the user's decision: report **not converged** with the proposed design instead of applying it. If the re-audit and its verification no longer fit the budget, report **not converged** and name the hotspot.

## Ledger and completion

Keep a compact current ledger with an append-only decision history; send reviewers only relevant entries and invariants, and for an unresolved rejection supply raw evidence without the author's rationale. Preserve artifacts across context loss, outside the deliverable unless requested.

- Finding: `key (class + mechanism) → severity/axis/origin → instances → evidence → disposition/reason → fix version → verification → residual risk/owner`.
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

Prefer the smallest remedy that satisfies every affected requirement without worsening a relevant performance bound.

Prefer clear names and concise code. Comments earn their place for non-obvious invariants, rationale, hazards, and contracts; remove narration, not necessary explanations, and do not refactor merely to avoid a useful comment.

Report in the user's language: outcome and scope; accepted/rejected/deferred/open findings with evidence, rejections counted by reason; pre-existing findings; validation and coverage gaps; residual risks and user decisions; touched high-risk areas (security, billing, CI workflows, migrations, release/update paths) that warrant human review whatever the outcome; finding classes that recurred and could be encoded in `CLAUDE.md`, `REVIEW.md`, a skill, or a lint rule, as suggestions only; tier, edit batches, assignments, actual agent/model settings where known, and checks reused. Distinguish wall time from total work using counters already available; never add a benchmark to an ordinary run or claim an unmeasured speedup.

For skill maintenance only, not normal runs, [evaluation cases](evals/cases.json) exercise scheduling and completion decisions. Replay them with an independent evaluator given only each case's input and these skills, and compare its decisions with the expected invariants.

Those cases do not measure whether reviewers find defects. Measure that separately before keeping a change to the reviewer rubric, model, or effort: replay subjects with a known escaped defect (a bug-introducing commit, with the expected finding taken from its fix or revert) and known-clean subjects, and keep the change only if it finds more expected defects without more false alarms. Rejection reasons from real runs show which kinds of finding are noise.
