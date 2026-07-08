---
name: review-cycle-core
description: Use when running review-plan-cycle or review-fix-cycle, or when either of those skills needs the shared review-loop mechanics — spawning fresh-context read-only reviewers, triage discipline, the finding ledger, the oscillation/stop rule, and ADR / ubiquitous-language discipline. Not usually invoked on its own.
---

# review-cycle-core

Shared machinery for the two review-cycle skills: `review-plan-cycle` (subject = an implementation plan) and `review-fix-cycle` (subject = a code diff). Those skills supply the *subject* and their own checklists; this skill supplies the *loop*. The leading idea: each pass uses a **fresh-context, read-only** reviewer, so the session that produced the work never reviews its own reasoning.

## Effort tier (choose once, before pass 1)

Scale the whole loop to the subject's size and risk — everything below is the *full* tier; don't pay it on a small change.

- **Lightweight** — subject is small, low blast radius, and touches at most one risk class (a localized fix, a plan with a handful of steps). One reviewer folding all relevant scopes, **one pass** (cap 1), the calling skill's gate reduced to the items the subject actually touches, no Design It Twice.
- **Full** — subject is large, or touches multiple risk classes, public contracts, concurrency/lifecycle, persisted/wire state, or security. Fan out by scope, pass cap per the Stop rule, full gate, Design It Twice available.

When unsure, start Lightweight and escalate to Full only if pass 1 surfaces anything at/above threshold in a risk class. Escalating costs one pass; starting Full on a trivial change costs every pass.

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

## Adjudicating a rejected finding (no extra spawn)

Rejecting an at/above-threshold finding is the author overruling a fresh reviewer on the author's *own* work — the one place the loop's independence breaks. Guard it **without** paying for a dedicated reviewer: make such a rejection *provisional for one pass* and resolve it inside the next pass's reviewer, which you were spawning anyway. (Below-threshold findings need none of this — reject them freely.)

- The general reviewer never sees the rejection rationale (the ledger split). If it **independently re-raises** the finding, that is corroboration: reopen and re-triage — not oscillation (see Stop rule).
- If it does **not** re-raise it, append a targeted question to **that same reviewer's** prompt: quote the finding and the author's rejection rationale, and ask "Is this rejection sound? Default to *unsound* if uncertain." Uphold → the rejection settles and its rationale enters the ledger normally; not sound → reopen and re-triage. This adds tokens, not a round-trip.
- **Terminal case** — if no further pass will run (Stop rule met, cap hit, or Lightweight's single pass), do **not** spawn to adjudicate: carry the contested rejection into the Final output as an open item routed to the user, with the finding and the author's rationale. The user, not another reviewer, breaks the last tie.

## Respect what's already settled

Before pass 1 and in every reviewer prompt:

- **Standing decisions & hazard classes** — read the project's `CLAUDE.md` (and `CONTEXT.md` if present) and fold both into every reviewer prompt: **(a)** decisions the project has already settled — honor them like ADRs and do **not** raise concerns they declare out of bounds (e.g. for lockstep co-deployed repos, backward-compatibility / old-client / migration concerns are non-issues — don't flag them); **(b)** the recurring failure classes the project documents — make pass 1 adversarial on those specific modes rather than merely broad. A reviewer raising a concern the project has explicitly ruled out is noise, and re-raising it across passes is oscillation.
- **Ubiquitous language** — read the project's domain glossary (`CONTEXT.md` / `UBIQUITOUS_LANGUAGE.md` if present) and use its terms exactly in findings, the ledger, and the refined work. Consistent language is what lets the next pass *act* on a finding instead of re-interpreting it.
- **Respect ADRs** — do not re-litigate a decision an ADR in the touched area already settled. A reviewer that wants to reopen one must say so explicitly and why; otherwise the decision is out of bounds. Re-raising settled decisions is a top cause of oscillation.
- **Offer an ADR** when a pass settles a load-bearing decision that is *hard to reverse*, *surprising without context*, and *the result of a real trade-off* — so future passes and future readers don't re-raise it. Skip ephemeral or self-evident reasons.

## The ledger

Append-only across passes. Each entry: `finding → disposition (why) → change → [skill-specific fields]`.

Pass the ledger to the next reviewer split in two, so anti-oscillation doesn't cost independence:

- **Factual** (always passed) — what changed, and any new invariant the refined work now depends on. Lets the reviewer build on settled work instead of re-deriving it, and checks the prior decisions.
- **Rationale** — passed for **accepted** and **deferred** findings, but **withheld** for a still-open at/above-threshold finding the author **rejected**. Don't hand the reviewer the reason a live concern was dismissed. If a fresh reviewer that never saw the rationale independently re-raises it, that is corroboration the rejection was wrong — not oscillation (see Stop rule).

## Severity (calibrate every finding to this — same scale every pass)

The stop threshold keys on this scale, so a fresh reviewer must use these definitions, not its own. **Inject them verbatim into every reviewer prompt.**

- **High** — wrong behavior, data loss, a broken or incompatible contract, a memory-safety/security defect, or a plan step that will produce one. Blocks convergence.
- **Medium** — correct but fragile, unmaintainable, or under-specified: a latent hazard, a missing test at a real seam, a shallow or leaky design that will cost the next change.
- **Low** — taste, polish, naming, comment nits. Never blocks the loop.

## Stop rule

Stop when **either** the reviewer reports nothing at/above the threshold **or** the pass cap is hit (default **4**; **1** in the Lightweight tier). Thresholds and cap are overridable in the scope.

- A **new** finding (even another High) is normal — keep going within the cap.
- **Oscillation** — the same concern returning after it was **settled** (accepted or rejected) in the ledger, however reworded — stops the loop early. A **deferred** finding that resurfaces is *not* oscillation; it was never decided.
- **Not oscillation:** a rejected finding independently re-raised by a reviewer that (per the ledger split) never saw the rejection rationale — that is corroboration. Reopen and re-triage it **once**; if it's rejected again with the rationale now shown to the reviewer and still returns, that is oscillation and stops the loop.
- If passes oscillate, or the cap is hit with open High items, stop and report **not converged** with the open list.
- If a reviewer can't run (quota/tool failure), report **blocked** (the calling skill may name it "review blocked" / "verification blocked"), not complete.
- Don't chase literal zero findings — reviews regenerate taste-based nits indefinitely.

## Final output (shared skeleton; the calling skill adds specifics)

- Passes run and why the loop stopped (threshold met / cap hit / not converged / blocked).
- The finding ledger, including rejected and deferred findings and why.
- Open findings below threshold, listed not fixed; open questions routed to the user.
- Domain/ADR notes: terms adopted, ADRs respected, any ADR proposed.
