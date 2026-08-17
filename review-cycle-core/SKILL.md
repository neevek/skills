---
name: review-cycle-core
description: Use when running review-plan-cycle or review-fix-cycle, or when either of those skills needs the shared review-loop mechanics — spawning fresh-context read-only reviewers, triage discipline, the finding ledger, the oscillation/stop rule, and ADR / ubiquitous-language discipline. Not usually invoked on its own.
---

# review-cycle-core

The *loop* behind `review-plan-cycle` (subject = a plan) and `review-fix-cycle` (subject = a diff); those skills supply the subject and the checklists. Every pass uses a **fresh-context, read-only** reviewer, so the session that produced the work never reviews its own reasoning.

## Two standing limits (they override everything else)

1. **Stay on the work at hand** — the subject, against the intent the user stated. No adjacent bug hunts, no "while we're here" hardening, no new surfaces, no unrequested refactors. Worthwhile work outside the subject is *one line in the final output, routed to the user*.
2. **Validate with related checks only** — what covers the touched seams. Broad, device, simulator, or e2e runs happen once, at the end.

This loop's failure mode is not missing bugs; it is spending the user's time and growing a small change into a large one.

## Effort tier (choose once, before pass 1 — and say the price out loud)

Size from the *subject*, not from how important the work feels.

| | **Lightweight** | **Standard** | **Full** |
|---|---|---|---|
| when | ≤ ~3 files / ~150 lines or plan steps, one risk class, no changed contract | neither column fits | changed public contract, wire/on-disk format, concurrency or lifecycle ownership, security, migration, or ≥ ~10 files |
| reviewers/pass | **1** — every scope *and* the calling skill's second axis as labelled sections of one prompt | 2 (one per axis) | one per disjoint scope, plus the second axis |
| pass cap | **1** | 2 | 4 (8 only if the user asked for exhaustive) |
| gate | items the subject touches | full, minus untouched stacks | full |
| Design It Twice | no | load-bearing decisions only | available |

**Lightweight is the default whenever the fixer could re-read the whole subject in one sitting.** Announce tier and price before spawning ("Lightweight: 1 reviewer, 1 pass, ~3 min") — a loop whose cost the user cannot see is one they cannot decline. On any signal of urgency, drop a tier, say so, and name what it skips.

**Escalate only for a High, or a Medium in a risk class the scope named.** Every other Medium is fixed, deferred, or recorded as residual risk within the cap: reviewers regenerate Mediums indefinitely, so treating each as an escalation makes a two-file change cost four passes.

## The loop

1. **Scope** once (the calling skill's plan scope / change map).
2. **Spawn the pass's reviewers in one message** — read-only, in the background — and in that same message start anything not depending on their findings (validation, a measurement). Reviewers only read, so nothing races them, and their wall time is the loop's dominant cost.
3. **Wait by working, never by polling** — the harness notifies you. Don't idle, sleep, or re-spawn to check.
4. **Triage** in the main session, **act** there too (reviewers never edit), **record** in the ledger.
5. **Repeat only if the Stop rule says to**, scoping the next reviewer to *the delta plus the mechanism that changed*, carrying the ledger. Re-auditing settled hunks re-derives context you already paid for and duplicates findings.

A pass is **atomic**: one full report per axis → triage all of it → act on every accepted finding → one ledger update → then the next pass. Never fix-one/review-one; it burns the cap one finding at a time and reads as oscillation. A report arriving as a single issue or a summary means the one-shot contract was missing from the prompt — fix the prompt, don't spend a pass rediscovering what was withheld.

## Spawning

- **Claude Code** — the Agent/Task subagent tool (not `TaskCreate`), `subagent_type: "Explore"`, parallel calls in one message, backgrounded so the user can interject.
- **Codex** — an `explorer` with `fork_context: false` and a self-contained prompt; GPT reviewers follow tagged blocks (`<task>`, `<severity_rubric>`, `<ledger_factual>`, `<output_contract>`) far better than prose, and their *final message* is the whole deliverable. No subagent tool ⇒ a fresh read-only CLI process (`codex exec`, read-only sandbox).
- **Fresh means a separate agent.** The current session never reviews its own work, not even as a fallback; unavailable spawning is **blocked** (Stop rule).
- **Model** — inherit the session's for judgement-heavy scopes (memory safety, concurrency, contracts, security); a cheaper, faster one suffices for mechanical scopes (comment discipline, test seams, packaging, glossary). Never trade strength on a named risk class.

## One-shot report contract (inject verbatim, with the severity rubric)

A reviewer reports once and is never consulted again; anything withheld costs a whole pass to rediscover.

"Your final message is your entire deliverable and your only report — there are no follow-up questions. Enumerate every finding you can defend here, not just the most severe: after the first plausible issue keep auditing until your scope is exhausted (second-order failures, empty/error states, retries, stale state, rollback).

One line per finding — `[High|Medium|Low] <file:line or plan step> — <defect> — <evidence> — <new | already-settled-in-ledger>`. Evidence: two sentences at most; a claim needing more is a guess, so mark it `needs-verification` and name the one check that would settle it. At most 10 findings — past that, report the 10 that matter and say you truncated. No preamble, no restating what the subject does, no summary of your reasoning: the main session wrote it and has read it.

If nothing is at/above Medium, say exactly that and stop — a padded report costs an extra pass."

`already-settled-in-ledger` routes to the Stop rule's oscillation/corroboration check, not to fresh triage.

## Triage

Never blind-apply. Give every finding a disposition (the calling skill's states) and record **why** — fresh reviewers guess wrong on taste, `unsafe`, lifetimes, FFI, threading, and architectural preference is not automatically correct.

**Classify before accepting** (limit 1):

- a defect in the requested behavior → fix now.
- the same defect on a path the user didn't mention → fix only if it is the same mechanism and the same edit; otherwise record it and tell the user.
- new behavior, a new surface, a new abstraction → **don't build it**; one line to the user. This is how a 15-line change becomes 60 lines nobody asked for. Widening also invalidates the tier — re-size first.

**Confirming a high-impact finding** (memory safety, ABI/contract break, data loss, security, a change to architecture/lifecycle/state ownership): at most one extra read-only reviewer this pass — but at Lightweight confirm it yourself by reading and quoting the cited code, spawning only if the claim turns on code you cannot reach.

**A reviewer's own uncertainty** must resolve: technical doubt → that one confirming reviewer; a scope, priority, or trade-off call only the user can make → **stop and ask the user**.

**Rejecting an at/above-threshold finding** is the author overruling a fresh reviewer on their own work — the one place independence breaks. The rejection is provisional for one pass and resolves in the next reviewer, which was being spawned anyway: the ledger split withholds the rationale, so an independent re-raise is corroboration (reopen, re-triage once); if it doesn't re-raise, append to that prompt "Is this rejection sound? Default to *unsound* if uncertain," quoting the finding and the rationale. Terminal case — no further pass (threshold met, cap hit, Lightweight's single pass): carry the contested rejection into the final output and let the user break the tie.

## Respect what's already settled

Read the standing-instructions file (`CLAUDE.md` / `AGENTS.md`, plus `CONTEXT.md`) before pass 1 and fold into every reviewer prompt: **(a)** decisions the project has settled — honor them like ADRs, and don't raise concerns they rule out (lockstep co-deployed repos make backward-compat and migration concerns non-issues); **(b)** the failure classes it documents — make pass 1 adversarial on those. Use the domain glossary's terms (`CONTEXT.md` / `UBIQUITOUS_LANGUAGE.md`) exactly in findings, ledger, and refined work. Don't re-litigate an ADR in the touched area; a reviewer wanting one reopened must say so and why. Offer a new ADR when a pass settles a load-bearing, hard-to-reverse trade-off. Raising a ruled-out concern is noise; re-raising it is oscillation.

## Comment discipline (fixes apply it; a plan writes it into its conventions)

Default to **no comment** — clearer names, smaller functions, and deleted dead branches beat a comment explaining them. A finding that says "add a comment here" usually means **simplify the code**: do that and reject the comment. A comment is justified only for what the code cannot show — a non-obvious invariant, a why-not-the-obvious-way, a hazard or workaround with its cause, a contract a caller must honor — decided on the first write, ~1–2 lines, no narration, no "fixed X", no reference to this review, no commented-out code.

## The ledger

Append-only: `finding → disposition (why) → change → [skill-specific fields]`. Pass it to the next reviewer in two parts, so anti-oscillation doesn't cost independence:

- **Factual** (always) — what changed, and any new invariant the work now depends on.
- **Rationale** — for accepted and deferred findings; **withheld** for a still-open at/above-threshold finding the author rejected.

## Severity (inject verbatim; the threshold keys on it)

- **High** — wrong behavior, data loss, a broken/incompatible contract, a memory-safety/security defect, or a plan step that will produce one. Blocks convergence.
- **Medium** — correct but fragile, unmaintainable, or under-specified: a latent hazard, a missing test at a real seam, a shallow or leaky design that will cost the next change.
- **Low** — taste, polish, naming, comment nits. Never blocks the loop.

## Stop rule

Stop on **any** of: nothing at/above threshold; the tier's cap (1 / 2 / 4, overridable in the scope); or the **ship condition** — requested work implemented and validated, every open finding below threshold or an accepted residual risk in the ledger. The loop protects the deliverable; it does not outlast it.

- A **new** finding (even a High) is normal — continue within the cap.
- **Oscillation** — a *settled* concern returning, however reworded — ends the loop early. A **deferred** finding resurfacing is not oscillation; it was never decided. A rejected finding re-raised by a reviewer that never saw the rationale is corroboration: re-triage once; if it returns after the rationale was shown, that is oscillation.
- Cap hit with open Highs, or oscillation ⇒ **not converged**, with the open list. A reviewer that can't run ⇒ **blocked**, not complete.
- Don't chase zero findings; reviews regenerate nits indefinitely.

## Final output (skeleton; the calling skill adds specifics)

Write it — and every question routed to the user — in the language the user used (English request → English report; 中文请求 → 中文报告). Internal artifacts may stay English; glossary terms keep their original form.

- Tier, passes run, reviewers spawned, and why the loop stopped (threshold / cap / ship condition / not converged / blocked) — the price belongs next to the result.
- The ledger, including rejected and deferred findings and why.
- Open findings below threshold, listed not fixed; questions routed to the user.
- Domain/ADR notes: terms adopted, ADRs respected, any proposed.
