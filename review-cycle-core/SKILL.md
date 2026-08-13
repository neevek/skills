---
name: review-cycle-core
description: Use when running review-plan-cycle or review-fix-cycle, or when either of those skills needs the shared review-loop mechanics — spawning fresh-context read-only reviewers, triage discipline, the finding ledger, the oscillation/stop rule, and ADR / ubiquitous-language discipline. Not usually invoked on its own.
---

# review-cycle-core

Shared machinery for `review-plan-cycle` (subject = an implementation plan) and `review-fix-cycle` (subject = a code diff): those skills supply the *subject* and their checklists, this one supplies the *loop*. Leading idea: every pass uses a **fresh-context, read-only** reviewer, so the session that produced the work never reviews its own reasoning.

## Effort tier (choose once, before pass 1)

Scale the loop to the subject's size and risk — everything below is the *full* tier; don't pay it on a small change.

- **Lightweight** — small, low blast radius, at most one risk class (a localized fix, a plan with a handful of steps): one reviewer folding all relevant scopes, one pass (cap 1), the calling skill's gate reduced to the items the subject touches, no Design It Twice.
- **Full** — large, or touches multiple risk classes, public contracts, concurrency/lifecycle, persisted/wire state, or security: fan out by scope, pass cap per the Stop rule, full gate, Design It Twice available.

When unsure, start Lightweight and escalate only if pass 1 surfaces anything at/above threshold in a risk class — escalating costs one pass; starting Full on a trivial change costs every pass.

## The loop

1. **Scope** (main session, once) — defined by the calling skill (plan scope or change map).
2. **Spawn a fresh reviewer** — read-only, cannot edit (see *Spawning*); fan out one per disjoint scope for large or cross-stack subjects.
3. **Triage** in the main session — never blind-apply (see *Triage discipline*).
4. **Act** on accepted findings — main session only.
5. **Record** in the ledger.
6. **Repeat** with a new fresh reviewer, passing the ledger; stop per the *Stop rule*.

A pass is **atomic**: one complete findings report → triage all of it → act on every accepted finding → one ledger update → only then the next reviewer. Never interleave fix-one/review-one — that burns the cap one finding at a time and presents as oscillation. A report that comes back as a single issue or short summary means the one-shot report contract was missing from its prompt; fix the prompt, don't spend passes rediscovering withheld findings.

## Spawning a fresh reviewer

- **Claude Code**: the Agent/Task subagent tool (not the to-do `TaskCreate`) with `subagent_type: "Explore"`; fan out via multiple tool calls in one message. The subagent's return value is its findings — triage in the main session.
- **Codex**: spawn an `explorer` with `fork_context: false` and a self-contained prompt (scope + reviewer prompt + assigned sub-scope). GPT-based reviewers follow explicit block-structured contracts far better than prose norms: wrap the prompt in tags — `<task>`, `<severity_rubric>`, `<ledger_factual>`, `<output_contract>` (the one-shot report contract) — and remember the agent's *final message* is the whole deliverable. If no subagent tool is available, run a fresh read-only CLI process (e.g. `codex exec` with a read-only sandbox) on the same prompt.
- **Fresh** means a separate agent — never the current session reviewing its own work, not even as a fallback when spawning is unavailable (that is **blocked**, per the Stop rule).

## One-shot report contract (inject verbatim, alongside the severity rubric)

A reviewer reports once and is never consulted again; anything held back costs a full extra pass to rediscover — and GPT-based reviewers especially tend to stop at the first plausible issue and compress their final message unless the prompt forbids both. Inject into every reviewer prompt:

"Your final message is your entire deliverable and your only report — there are no follow-up questions. Enumerate every finding you can defend in this one response, not just the most severe: after the first plausible issue, keep auditing until your assigned scope is exhausted (second-order failures, empty/error states, retries, stale state, rollback). Do not truncate for brevity. Format: one line per finding — `[High|Medium|Low] <file:line or plan step> — <defect> — <evidence> — <new | already-settled-in-ledger>`. If nothing is at/above Medium, say exactly that."

A finding tagged `already-settled-in-ledger` routes to the Stop rule's oscillation/corroboration check instead of fresh triage.

## Triage discipline

- Never blind-apply. Mark each finding with one of the calling skill's disposition states and record **why** — fresh reviewers guess wrong (taste calls, `unsafe`/lifetimes/FFI/threading; architectural preference is not automatically correct).
- A high-impact finding (memory safety, ABI/contract break, data loss, security, or a change to architecture/lifecycle/state ownership) gets **at most one more** read-only reviewer this pass to confirm before acting.
- A finding the reviewer itself was unsure of must resolve into a real disposition: a feasibility/technical doubt gets that one confirming reviewer; a product/scope decision only the user can make (priorities, intent, acceptable trade-offs) means **stop and ask the user** rather than letting reviewers churn on an undecidable point.

## Adjudicating a rejected finding (no extra spawn)

Rejecting an at/above-threshold finding is the author overruling a fresh reviewer on the author's own work — the one place the loop's independence breaks. Guard it without a dedicated reviewer: the rejection is *provisional for one pass* and resolves inside the next pass's reviewer, which was being spawned anyway. (Below-threshold findings need none of this — reject them freely.)

- The general reviewer never sees the rejection rationale (the ledger split). If it independently **re-raises** the finding, that is corroboration: reopen and re-triage — not oscillation (see Stop rule).
- If it does **not**, append a targeted question to that same reviewer's prompt: quote the finding and the rejection rationale, ask "Is this rejection sound? Default to *unsound* if uncertain." Upheld → the rejection settles and its rationale enters the ledger normally; unsound → reopen and re-triage. This adds tokens, not a round-trip.
- **Terminal case** — if no further pass will run (Stop rule met, cap hit, Lightweight's single pass), don't spawn to adjudicate: carry the contested rejection into the Final output as an open item routed to the user, with the finding and the rationale. The user, not another reviewer, breaks the last tie.

## Respect what's already settled

Before pass 1 and in every reviewer prompt:

- **Standing decisions & hazard classes** — read the project's standing-instructions file (`CLAUDE.md` under Claude Code, `AGENTS.md` under Codex, plus `CONTEXT.md` if present) and fold both into every reviewer prompt: **(a)** decisions the project has settled — honor them like ADRs, don't raise concerns they declare out of bounds (e.g. lockstep co-deployed repos make backward-compat/old-client/migration concerns non-issues); **(b)** the recurring failure classes the project documents — make pass 1 adversarial on those modes, not merely broad. Raising a ruled-out concern is noise; re-raising it across passes is oscillation.
- **Ubiquitous language** — read the domain glossary (`CONTEXT.md` / `UBIQUITOUS_LANGUAGE.md` if present) and use its terms exactly in findings, ledger, and refined work — consistent terms are what let the next pass *act* on a finding instead of re-interpreting it.
- **Respect ADRs** — don't re-litigate a decision an ADR in the touched area settled; a reviewer wanting to reopen one must say so explicitly and why. Re-raising settled decisions is a top cause of oscillation.
- **Offer an ADR** when a pass settles a load-bearing decision that is hard to reverse, surprising without context, and a real trade-off — so future passes and readers don't re-raise it. Skip ephemeral or self-evident reasons.

## Comment discipline (shared — fixes apply it, plans carry it)

Applies to every edit the fixer makes; a plan hands it to the implementer by writing it into the plan's conventions (the implementer won't infer it):

- Default to **no comment** — clearer names, smaller functions, and removed dead branches beat a comment that explains them. A finding that says "add a comment to explain this" is usually a signal to **simplify the code** instead; prefer that, and reject the comment if the simplification removes the confusion.
- A comment is justified only when it records something the code cannot show: a non-obvious invariant, a why-not-the-obvious-way, a known hazard/workaround with its cause, or a contract a caller must honor. Decide it is **absolutely** necessary by that test before writing — on the first write, not after a reminder.
- When warranted, state the fact precisely — no narrating what the line does, no "fixed X" or references to the review/plan/task, no commented-out code — capped at ~1–2 lines even in a comment-dense file; matching surrounding density never licenses verbosity.

## The ledger

Append-only across passes. Entry: `finding → disposition (why) → change → [skill-specific fields]`.

Pass it to the next reviewer split in two, so anti-oscillation doesn't cost independence:

- **Factual** (always passed) — what changed, plus any new invariant the refined work now depends on. Lets the reviewer build on settled work instead of re-deriving it, and check the prior decisions.
- **Rationale** — passed for **accepted** and **deferred** findings, **withheld** for a still-open at/above-threshold finding the author **rejected**: don't hand the reviewer the reason a live concern was dismissed. An independent re-raise is then corroboration, not oscillation (see Stop rule).

## Severity (same scale every pass — inject verbatim into every reviewer prompt)

The stop threshold keys on this scale, so a fresh reviewer must use these definitions, not its own.

- **High** — wrong behavior, data loss, a broken/incompatible contract, a memory-safety/security defect, or a plan step that will produce one. Blocks convergence.
- **Medium** — correct but fragile, unmaintainable, or under-specified: a latent hazard, a missing test at a real seam, a shallow or leaky design that will cost the next change.
- **Low** — taste, polish, naming, comment nits. Never blocks the loop.

## Stop rule

Stop when **either** the reviewer reports nothing at/above the threshold **or** the pass cap is hit (default **8**; **1** in Lightweight). Thresholds and cap are overridable in the scope.

- A **new** finding (even another High) is normal — keep going within the cap.
- **Oscillation** — a concern returning after being **settled** (accepted or rejected) in the ledger, however reworded — stops the loop early. A **deferred** finding resurfacing is *not* oscillation; it was never decided.
- **Not oscillation:** a rejected finding independently re-raised by a reviewer that (per the ledger split) never saw the rejection rationale — that is corroboration. Reopen and re-triage **once**; if rejected again with the rationale now shown to the reviewer and it still returns, that is oscillation and stops the loop.
- If passes oscillate, or the cap is hit with open High items, stop and report **not converged** with the open list.
- If a reviewer can't run (quota/tool failure), report **blocked** (the calling skill may name it "review blocked" / "verification blocked"), not complete.
- Don't chase literal zero findings — reviews regenerate taste-based nits indefinitely.

## Final output (shared skeleton; the calling skill adds specifics)

- **User's language** — write the final report, verdicts, and every question routed to the user in the language the user invoked the loop in (English request → English report; 中文请求 → 中文报告). Internal artifacts (reviewer prompts, ledger entries) may stay in English; the synthesis the user reads must not. Glossary/domain terms keep their exact original form either way.
- Passes run and why the loop stopped (threshold met / cap hit / not converged / blocked).
- The finding ledger, including rejected and deferred findings and why.
- Open findings below threshold, listed not fixed; open questions routed to the user.
- Domain/ADR notes: terms adopted, ADRs respected, any ADR proposed.
