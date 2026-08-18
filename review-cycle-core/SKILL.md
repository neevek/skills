---
name: review-cycle-core
description: Use when running review-plan-cycle or review-fix-cycle, or when either of those skills needs the shared review-loop mechanics — parallel fresh-context read-only reviewers, triage discipline, the finding ledger, the anti-oscillation protocol and stop rule, and ADR / ubiquitous-language discipline. Not usually invoked on its own.
---

# review-cycle-core

The *loop* behind `review-plan-cycle` (subject = a plan) and `review-fix-cycle` (subject = a diff); those skills supply the subject and the checklists. Every pass uses **fresh-context, read-only** reviewers, so the session that produced the work never reviews its own reasoning.

## Three standing limits (they override everything else)

1. **Everything that can run at once, does.** A pass spawns *all* its reviewers in **one message, in parallel, backgrounded** — never one at a time, never one agent walking several scopes in sequence. Validation, measurements, and any confirming reviewer start in that same message; reviewers only read, so nothing races them. Reviewer wall time dominates the loop and is paid once per pass, not once per reviewer.
2. **Related checks only.** Run the narrowest target covering the touched seams — never the whole suite "to be safe", and no reviewer may demand one. A full, device, simulator, browser, or e2e run happens only if the scope flags a cross-cutting change, and then once, at the end.
3. **Stay on the work at hand** — the subject, against the intent the user stated. No adjacent bug hunts, no "while we're here" hardening, no new surfaces, no unrequested refactors. Worthwhile work outside the subject is *one line in the final output, routed to the user*.

This loop's failure mode is not missing bugs; it is spending the user's time and growing a small change into a large one.

## Effort tier (choose once, before pass 1 — and say the price out loud)

Size from the *subject*, not from how important the work feels.

| | **Lightweight** | **Standard** | **Full** |
|---|---|---|---|
| when | ≤ ~3 files / ~150 lines or plan steps, one risk class, no changed contract | neither column fits | changed public contract, wire/on-disk format, concurrency or lifecycle ownership, security, migration, or ≥ ~10 files |
| reviewers/pass | **2** — the calling skill's two axes, concurrent | 2–3 — the axes plus the dominant risk class | one per disjoint scope, plus the second axis |
| pass cap | **1** | 2 | 4 (8 only if the user asked for exhaustive) |
| gate | items the subject touches | full, minus untouched stacks | full |
| Design It Twice | no | load-bearing decisions only | available |

**Lightweight is the default whenever the fixer could re-read the whole subject in one sitting.** Announce tier and price before spawning ("Lightweight: 2 reviewers, 1 pass, ~3 min") — a loop whose cost the user cannot see is one they cannot decline. On urgency, drop a tier, say so, and name what it skips. Extra reviewers are near-free in wall time; extra *passes* are not, so widen the fan-out before raising the cap.

**Escalate only for a High, or a Medium in a risk class the scope named.** Every other Medium is fixed, deferred, or recorded as residual risk within the cap: reviewers regenerate Mediums indefinitely, so treating each as an escalation makes a two-file change cost four passes.

## The loop

1. **Scope** once (the calling skill's plan scope / change map).
2. **Spawn the whole pass in one message** — every reviewer, plus validation and any measurement or confirmation not depending on their findings.
3. **Wait by working, never by polling** — the harness notifies you. Don't idle, sleep, or re-spawn to check.
4. **Triage** in the main session, **act** there too (reviewers never edit), **record** in the ledger.
5. **Repeat only if the Stop rule says to**, scoping the next reviewers to *the delta plus the mechanism that changed*, carrying the ledger. Re-auditing settled hunks re-derives context you already paid for and duplicates findings.

A pass is **atomic**: all reports in → triage all of it → act on every accepted finding → one ledger update → next pass. Never fix-one/review-one; it burns the cap one finding at a time and reads as oscillation. A report arriving as a single issue or a summary means the one-shot contract was missing from the prompt — fix the prompt, don't spend a pass rediscovering what was withheld.

## Spawning

- **Claude Code** — the Agent/Task subagent tool (not `TaskCreate`), `subagent_type: "Explore"`, **all calls in a single message**, backgrounded so the user can interject.
- **Codex** — `explorer`s with `fork_context: false` and self-contained prompts, launched together; GPT reviewers follow tagged blocks (`<task>`, `<severity_rubric>`, `<ledger_factual>`, `<output_contract>`) far better than prose, and their *final message* is the whole deliverable. No subagent tool ⇒ concurrent read-only `codex exec` runs.
- **Fresh means a separate agent.** The current session never reviews its own work, not even as a fallback; unavailable spawning is **blocked** (Stop rule).
- **Model** — inherit the session's for judgement-heavy scopes (memory safety, concurrency, contracts, security); a cheaper, faster one suffices for mechanical scopes (comment discipline, test seams, packaging, glossary). Never trade strength on a named risk class.

## One-shot report contract (inject verbatim, with the severity rubric)

A reviewer reports once and is never consulted again; anything withheld costs a whole pass to rediscover.

"Your final message is your entire deliverable and your only report — there are no follow-up questions. Enumerate every finding you can defend here, not just the most severe: after the first plausible issue keep auditing until your scope is exhausted (second-order failures, empty/error states, retries, stale state, rollback).

One line per finding — `[High|Medium|Low] <file:line or plan step> — <defect> — <evidence> — <new | already-settled-in-ledger>`. Evidence: two sentences at most; a claim needing more is a guess, so mark it `needs-verification` and name the one check that would settle it. At most 10 findings — past that, report the 10 that matter and say you truncated. No preamble, no restating what the subject does, no summary of your reasoning: the main session wrote it and has read it.

If nothing is at/above Medium, say exactly that and stop — a padded report costs an extra pass."

## Triage

Never blind-apply. Give every finding a disposition (the calling skill's states) and record **why** — fresh reviewers guess wrong on taste, `unsafe`, lifetimes, FFI, threading, and architectural preference is not automatically correct.

**Classify before accepting** (limit 3):

- a defect in the requested behavior → fix now.
- the same defect on a path the user didn't mention → fix only if it is the same mechanism and the same edit; otherwise record it and tell the user.
- new behavior, a new surface, a new abstraction → **don't build it**; one line to the user. This is how a 15-line change becomes 60 lines nobody asked for. Widening also invalidates the tier — re-size first.

**Confirming a high-impact finding** (memory safety, ABI/contract break, data loss, security, a change to architecture/lifecycle/state ownership): at most one extra read-only reviewer, launched in the *next* pass's message so it costs no extra wall time — but at Lightweight confirm it yourself by reading and quoting the cited code, spawning only if the claim turns on code you cannot reach.

**A reviewer's own uncertainty** must resolve: technical doubt → that one confirming reviewer; a scope, priority, or trade-off call only the user can make → **stop and ask the user**.

**Rejecting an at/above-threshold finding** is the author overruling a fresh reviewer on their own work — the one place independence breaks. It is provisional for one pass and resolves in the next reviewer, which was being spawned anyway: the ledger split withholds the rationale, so an independent re-raise is corroboration (reopen, re-triage once). With no further pass coming, carry the contested rejection into the final output and let the user break the tie.

## Anti-oscillation protocol

Every finding gets a **key** — touched location + mechanism, assigned in the main session on first sight. Rewording, a different severity, a different axis, or a different reviewer does **not** mint a new key. Keys, not sentences, are what the ledger tracks.

- **Two strikes.** A key may be triaged at most twice in the whole loop. Its third appearance is terminal: stop editing for it, freeze the subject as it stands, record both positions as residual risk, route it to the user. Do not re-argue it in-loop.
- **No reversals.** If acting on a finding would undo or re-tune an edit an earlier pass made for a *different* key, stop: that is a trade-off only the user owns. Keep the last state that passed validation, record both positions, ask. Never let two reviewers take turns on the same lines.
- **Passes must be monotonic.** Each pass must strictly shrink the open at/above-threshold key set. A pass ending with the same or a larger set of the *same* keys ends the loop as **not converged**, listing them — the reviewers have stopped producing new information.
- **Settled means settled.** A concern ruled out by an ADR, the stated intent, or a recorded rejection whose rationale the reviewer *was shown* is noise on first return and oscillation on the second.
- **Exempt:** a **new** key (normal — continue within the cap); a **deferred** key (never decided); a rejected key re-raised by a reviewer that never saw the rationale (corroboration — re-triage once; that is strike two).

Any trigger here ends the loop *immediately* rather than at the cap, and the exit is always the same: freeze, record, hand the open keys to the user.

## Respect what's already settled

Read the standing-instructions files (`CLAUDE.md` / `AGENTS.md`, `CONTEXT.md`) before pass 1 and fold into every reviewer prompt: **(a)** decisions the project has settled — honor them like ADRs, and don't raise concerns they rule out (lockstep co-deployed repos make backward-compat and migration concerns non-issues); **(b)** the failure classes it documents — make pass 1 adversarial on those. Use the glossary's terms (`CONTEXT.md` / `UBIQUITOUS_LANGUAGE.md`) exactly. Don't re-litigate an ADR in the touched area; a reviewer wanting one reopened must say so and why. Offer a new ADR when a pass settles a load-bearing, hard-to-reverse trade-off.

## Comment discipline (fixes apply it; a plan writes it into its conventions)

Default to **no comment** — clearer names, smaller functions, and deleted dead branches beat a comment explaining them. A finding that says "add a comment here" usually means **simplify the code**: do that and reject the comment. A comment is justified only for what the code cannot show — a non-obvious invariant, a why-not-the-obvious-way, a hazard or workaround with its cause, a contract a caller must honor — decided on the first write, ~1–2 lines, no narration, no "fixed X", no reference to this review, no commented-out code.

## The ledger

Append-only: `key → finding → disposition (why) → strikes → change → [skill-specific fields]`. Pass it to the next reviewers in two parts, so anti-oscillation doesn't cost independence:

- **Factual** (always) — what changed, and any new invariant the work now depends on.
- **Rationale** — for accepted and deferred findings; **withheld** for a still-open at/above-threshold finding the author rejected.

## Severity (inject verbatim; the threshold keys on it)

- **High** — wrong behavior, data loss, a broken/incompatible contract, a memory-safety/security defect, or a plan step that will produce one. Blocks convergence.
- **Medium** — correct but fragile, unmaintainable, or under-specified: a latent hazard, a missing test at a real seam, a shallow or leaky design that will cost the next change.
- **Low** — taste, polish, naming, comment nits. Never blocks the loop.

## Stop rule

Stop on **any** of: nothing at/above threshold; the tier's cap; any anti-oscillation trigger; or the **ship condition** — requested work implemented and validated, every open finding below threshold or an accepted residual risk in the ledger. The loop protects the deliverable; it does not outlast it.

Cap hit with open Highs, or an oscillation exit ⇒ **not converged**, with the open list. A reviewer that can't run ⇒ **blocked**, not complete. Don't chase zero findings; reviews regenerate nits indefinitely.

## Final output (skeleton; the calling skill adds specifics)

Write it — and every question routed to the user — in the language the user used (English request → English report; 中文请求 → 中文报告). Internal artifacts may stay English; glossary terms keep their original form.

- Tier, passes, reviewers spawned, and why the loop stopped (threshold / cap / oscillation / ship condition / not converged / blocked) — the price belongs next to the result.
- The ledger: accepted, rejected, deferred, frozen — and why.
- Open findings below threshold, listed not fixed; questions and frozen trade-offs routed to the user.
- Domain/ADR notes: terms adopted, ADRs respected, any proposed.
