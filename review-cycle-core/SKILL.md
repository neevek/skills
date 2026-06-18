---
name: review-cycle-core
description: Use when running review-plan-cycle or review-fix-cycle, or when either of those skills needs the shared review-loop mechanics — spawning fresh-context read-only reviewers, triage discipline, the finding ledger, the oscillation/stop rule, and ADR / ubiquitous-language discipline. Not usually invoked on its own.
---

# review-cycle-core

Shared machinery for the two review-cycle skills: `review-plan-cycle` (subject = an implementation plan) and `review-fix-cycle` (subject = a code diff). Those skills supply the *subject* and their own checklists; this skill supplies the *loop*. The leading idea: each pass uses a **fresh-context, read-only** reviewer, so the session that produced the work never reviews its own reasoning.

## The loop

1. **Scope** (main session, once before pass 1) — defined by the calling skill (a plan scope or a change map).
2. **Spawn a fresh reviewer** — read-only, cannot edit (see *Spawning* below). Fan out one reviewer per disjoint scope for large or cross-stack subjects.
3. **Triage** in the main session — never blind-apply (see *Triage discipline*). The calling skill names the disposition states.
4. **Act** on accepted findings — main session only.
5. **Record** in the ledger (see *The ledger*).
6. **Repeat** with a new fresh reviewer, passing the ledger. Stop per the *Stop rule*.

## Spawning a fresh reviewer

- **Claude Code**: the Agent/Task subagent tool (not the to-do `TaskCreate`) with `subagent_type: "Explore"`. Fan out by putting multiple tool calls in one message. The subagent's return value is its findings — triage them in the main session.
- **Codex**: spawn an `explorer` with `fork_context: false` and a self-contained prompt (the scope, the reviewer prompt, and the assigned sub-scope). Fan out by spawning one reviewer per disjoint scope; collect their final messages and triage them in the main session.
- **Fresh** means a separate agent — never the current session reviewing its own work.

## Triage discipline

- Never blind-apply. Mark each finding with one of the calling skill's disposition states and record **why** — fresh reviewers guess wrong (taste calls, `unsafe`/lifetimes/FFI/threading, architectural preference is not automatically correct).
- For a high-impact finding (memory safety, ABI/contract break, data loss, security, or a change to architecture/lifecycle/state ownership), spawn **at most one more** read-only reviewer this pass to confirm before acting.
- If a finding is one the reviewer wasn't sure about, resolve it into a real disposition — a feasibility/technical doubt gets that one confirming reviewer; a product/scope decision only the user can make (priorities, intent, acceptable trade-offs) means **stop and ask the user** rather than letting reviewers churn on an undecidable point.

## Respect what's already settled

Before pass 1 and in every reviewer prompt:

- **Ubiquitous language** — read the project's domain glossary (`CONTEXT.md` / `UBIQUITOUS_LANGUAGE.md` if present) and use its terms exactly in findings, the ledger, and the refined work. Consistent language is what lets the next pass *act* on a finding instead of re-interpreting it.
- **Respect ADRs** — do not re-litigate a decision an ADR in the touched area already settled. A reviewer that wants to reopen one must say so explicitly and why; otherwise the decision is out of bounds. Re-raising settled decisions is a top cause of oscillation.
- **Offer an ADR** when a pass settles a load-bearing decision that is *hard to reverse*, *surprising without context*, and *the result of a real trade-off* — so future passes and future readers don't re-raise it. Skip ephemeral or self-evident reasons.

## The ledger

Append-only across passes. Each entry: `finding → disposition (why) → change → [skill-specific fields]`. Pass the **whole ledger** to the next reviewer so it checks prior decisions and hunts **new** issues instead of re-raising settled ones.

## Stop rule

Stop when **either** the reviewer reports nothing at/above the threshold **or** the pass cap is hit (default **4**). Thresholds and cap are overridable in the scope.

- A **new** finding (even another High) is normal — keep going within the cap.
- **Oscillation** — the same concern returning after it was **settled** (accepted or rejected) in the ledger, however reworded — stops the loop early. A **deferred** finding that resurfaces is *not* oscillation; it was never decided.
- If passes oscillate, or the cap is hit with open High items, stop and report **not converged** with the open list.
- If a reviewer can't run (quota/tool failure), report **blocked** (the calling skill may name it "review blocked" / "verification blocked"), not complete.
- Don't chase literal zero findings — reviews regenerate taste-based nits indefinitely.

## Final output (shared skeleton; the calling skill adds specifics)

- Passes run and why the loop stopped (threshold met / cap hit / not converged / blocked).
- The finding ledger, including rejected and deferred findings and why.
- Open findings below threshold, listed not fixed; open questions routed to the user.
- Domain/ADR notes: terms adopted, ADRs respected, any ADR proposed.
