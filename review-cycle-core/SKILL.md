---
name: review-cycle-core
description: Use when running review-plan-cycle or review-fix-cycle, or when either of those skills needs the shared review-loop mechanics — parallel fresh-context read-only reviewers, triage discipline, the finding ledger, the anti-oscillation protocol and stop rule, the simplicity bar, and ADR / ubiquitous-language discipline. Not usually invoked on its own.
---

# review-cycle-core

The *loop* behind `review-plan-cycle` (subject = a plan) and `review-fix-cycle` (subject = a diff); those skills supply the subject and the checklists. Every pass uses **fresh-context, read-only** reviewers, so the session that produced the work never reviews its own reasoning.

Its failure mode is not missing bugs. It is spending the user's time, and growing a small change into a large one.

## Run sheet

Execute from this; each section below is the reference for one line. Read a section when you reach it.

1. Read the standing-instruction files. Build the calling skill's scope map.
2. Pick the tier. Announce tier, reviewer scopes, pass cap, validation breadth — never an elapsed-time estimate.
3. **One message:** every reviewer of the pass, any confirming reviewer, and only validation the pass cannot invalidate. Each prompt carries the scope map, settled decisions, glossary, severity rubric, one-shot contract, factual ledger, and the subject itself.
4. Wait by working — the harness notifies you; don't idle, sleep, or re-spawn to check. All reports in → triage all of it → apply every accepted fix (main session only; reviewers never edit) → one ledger update.
5. Stop unless the Stop rule demands another pass. A next pass reviews **the delta and the mechanism that changed** — never settled hunks, never an unchanged subject.
6. Report: tier, passes, why it stopped, the ledger, open findings, questions routed to the user.

## Four standing limits (they override everything else)

1. **Everything that can run at once, does.** A pass spawns *all* its reviewers in one message, in parallel, backgrounded — never one at a time, never one agent walking several scopes in sequence. Defer only what the pass is likely to invalidate; parallel work that must be repeated is not an optimization.
2. **Related checks only.** Run the narrowest target covering the touched seams — never the whole suite "to be safe", and no reviewer may demand one. A broad or full-suite device, simulator, browser, or e2e run happens only if the scope flags a cross-cutting change, and then once, at the end. A targeted journey is allowed whenever it is the narrowest faithful seam.
3. **Stay on the work at hand** — the subject, against the intent the user stated. No adjacent bug hunts, no "while we're here" hardening, no new surfaces, no unrequested refactors. Worthwhile work outside the subject is *one line in the final output, routed to the user*.
4. **Save work, never thinking time.** Speed comes from correct tiering, parallel independence, batching, and cache reuse. Never set a review timeout, ask a reviewer to conclude early, or stop a slow in-scope read-only review: the prompt and the one-shot contract bound scope, and duration carries no information. Interrupt only when the user replaces the request, the reviewer is demonstrably out of scope, or the review cannot complete — the tool reported failure or disconnection, or required resources are unavailable. Elapsed time alone never qualifies.

## Effort tier (choose once per stable authorized scope — and say the price out loud)

Size from the *subject*, not from how important the work feels.

| | **Lightweight** | **Standard** | **Full** |
|---|---|---|---|
| when | ≤ ~3 production files / ~150 lines or plan steps, one risk class, no changed contract | neither column fits; includes internal concurrency/lifecycle changes contained in one component | public/wire/on-disk contract, security boundary, migration, ownership crossing components/processes, ≥3 named risk classes, or ≥10 production files |
| reviewers/pass | **2** — the calling skill's two axes, concurrent | 2–3 — the axes plus the dominant risk class | one per disjoint scope, plus the second axis |
| pass cap | **1** | 2 | 10 |
| gate | items the subject touches | full, minus untouched stacks | full |
| Design It Twice | no | load-bearing decisions only | available |

Count hand-authored production files and real contract surfaces; tests, generated output, and review-driven growth within the same authorized mechanisms do not raise the initial tier. The Full column's criteria are **floors** — readability or urgency never lowers them, and skipping one needs the user's explicit acceptance of the omitted coverage. Between Standard and Full with no floor triggered, take Standard and widen the first pass around the dominant risk. Re-tier when an authorized expansion adds a floor.

**Lightweight is the default whenever its row permits and the fixer could re-read the whole subject in one sitting.** Announce the price before spawning — e.g. "Standard: Correctness + Spec + lifecycle, cap 2, focused unit validation" — meaning reviewers, pass cap, and validation breadth, never elapsed time. Extra concurrent reviewers are cheaper than extra passes: widen the fan-out before raising the cap.

**Escalate only for a High, or a Medium in a risk class the scope named.** Fix, defer, or record every other Medium within the cap — reviewers regenerate Mediums indefinitely, so escalating each makes a two-file change cost four passes.

## The pass

A pass is **atomic**: all reports in → triage all of it → act on every accepted finding → one ledger update → next pass. Never fix-one/review-one; it burns the cap one finding at a time and reads as oscillation. A report arriving as a single issue or a summary means the one-shot contract was missing from the prompt — fix the prompt, don't spend a pass rediscovering what was withheld.

**Never spend a pass on an unchanged subject.** If triage produced no edit, more reviewers on the same bytes cannot say anything the last ones didn't. The lone exception is a contested rejection, and that is one confirming reviewer on that one key — not a pass.

User-visible checkpoints:

- **Before pass 1** — tier, reviewer scopes, pass cap, validation breadth.
- **After each pass** — High/Medium keys by disposition, which validation is green versus dirty, and the concrete reason another pass is necessary.
- **Before a meaningful scope expansion** — name the newly required repository, service, public contract, platform, or deliverable and ask for direction, unless the user already placed it in scope. Read-only boundary inspection is not expansion; mutation is.

## Spawning

- **Claude Code** — the Agent/Task subagent tool (not `TaskCreate`), `subagent_type: "Explore"`, **all calls in a single message**, backgrounded so the user can interject.
- **Codex** — `explorer`s with `fork_context: false` and self-contained prompts, launched together. GPT reviewers follow tagged blocks (`<task>`, `<severity_rubric>`, `<ledger_factual>`, `<output_contract>`) far better than prose, and their *final message* is the whole deliverable. No subagent tool ⇒ concurrent read-only `codex exec` runs.
- **Fresh means a separate agent.** The current session never reviews its own work, not even as a fallback; unavailable spawning is **blocked** (Stop rule).
- **Model** — reviewers run on the host's mid-tier model at every tier and risk class; review strength is bought with fan-out and fresh context, not with a frontier model inherited by accident. **Claude Code:** pass `model: "sonnet"` explicitly on every spawn — since CLI 2.1.251 an omitted model makes an `Explore` subagent inherit the parent session's model and ignore `CLAUDE_CODE_SUBAGENT_MODEL`, so an Opus session silently fans out Opus reviewers. **Codex:** `explorer` takes no model parameter — leave the invocation alone; a `codex exec` fan-out uses the CLI default. Either host: when the user's request names a model, use it — for the reviewers they named, or all of them if they named none (Codex: `codex exec --model`).
- **Hand over the subject; don't send a scavenger hunt.** Paste the diff or plan into the prompt when it fits, otherwise give the one command that produces it. Discovery you already paid for, repeated once per reviewer, is this loop's quietest cost. Pass 2+ hands over the delta the same way — the hunks or steps the last pass changed — and states that the rest of the subject is settled context, in scope only where the delta breaks it.

## One-shot report contract (inject verbatim, with the severity rubric)

A reviewer reports once and is never consulted again; anything withheld costs a whole pass to rediscover.

"Your final message is your entire deliverable and your only report — there are no follow-up questions. Enumerate every finding you can defend here, not just the most severe: after the first plausible issue keep auditing until your scope is exhausted (second-order failures, empty/error states, retries, stale state, rollback).

One line per finding — `[High|Medium|Low] <file:line or plan step> — <defect> — <evidence> — <new | already-settled-in-ledger>`. Evidence: two sentences at most — for a wrong-behavior claim, the concrete input or state and the wrong outcome it produces. A claim needing more, or one you cannot instantiate, is a guess: mark it `needs-verification` and name the one check that would settle it. At most 10 findings — past that, report the 10 that matter and say you truncated. No preamble, no restating what the subject does, no summary of your reasoning: the main session wrote it and has read it.

If nothing is at/above Medium, say exactly that and stop — a padded report costs an extra pass."

## Triage

Never blind-apply. Give every finding a disposition (the calling skill's states) and record **why** — fresh reviewers guess wrong on taste, `unsafe`, lifetimes, FFI, threading, and architectural preference is not automatically correct. Disposition from the subject, not the report: read the cited code or step before deciding and accept only what you can see there; a claim you cannot confirm by reading resolves as reviewer uncertainty below.

**Classify before accepting** (limit 3):

- a defect in the requested behavior → fix now.
- the same defect on a path the user didn't mention → fix only if it is the same mechanism and the same edit; otherwise record it and tell the user.
- new behavior, a new surface, a new abstraction → **don't build it**; one line to the user. This is how a 15-line change becomes 60 lines nobody asked for. Widening also invalidates the tier — re-size first.

**Confirming a high-impact finding** (memory safety, ABI/contract break, data loss, security, a change to architecture/lifecycle/state ownership): at most one extra read-only reviewer, launched in the *next* pass's message so it costs no extra wall time. At Lightweight or in the final pass, confirm it yourself by reading and quoting the cited code, spawning the lone reviewer only if the claim turns on code you cannot reach.

**A reviewer's own uncertainty** must resolve: technical doubt → that one confirming reviewer; a scope, priority, or trade-off call only the user can make → **stop and ask the user**.

**Rejecting an at/above-threshold finding** is the author overruling a fresh reviewer on their own work — the one place independence breaks. It stands provisionally for one pass: the ledger split withholds the rationale, so an independent re-raise is corroboration (reopen, re-triage once — that is strike two). With no further pass coming, carry the contested rejection into the final output and let the user break the tie.

## Anti-oscillation protocol

Every finding gets a **key** — touched location + mechanism, assigned in the main session on first sight. Rewording, a different severity, a different axis, or a different reviewer does **not** mint a new key. Keys, not sentences, are what the ledger tracks.

- **Two strikes.** A key may be triaged at most twice in the whole loop. Its third appearance is terminal: stop editing for it, freeze the subject as it stands, record both positions as residual risk, route it to the user. Do not re-argue it in-loop.
- **No reversals.** If acting on a finding would undo or re-tune an edit an earlier pass made for a *different* key, stop — that is a trade-off only the user owns. Keep the last state that passed validation, record both positions, ask. Never let two reviewers take turns on the same lines.
- **Passes must be monotonic.** Each pass must strictly shrink the open at/above-threshold key set. A pass ending with the same or a larger set of the *same* keys ends the loop as **not converged**, listing them: the reviewers have stopped producing new information.
- **Settled means settled.** A concern ruled out by an ADR, the stated intent, or a recorded rejection whose rationale the reviewer *was shown* is noise on first return and oscillation on the second.
- **Exempt:** a **new** key (normal — continue within the cap); a **deferred** key (never decided); a rejected key re-raised by a reviewer that never saw the rationale (corroboration — re-triage once; that is strike two).

Any trigger here ends the loop *immediately* rather than at the cap, and the exit is always: freeze, record, hand the open keys to the user.

## Respect what's already settled

Read the standing-instructions files (`CLAUDE.md` / `AGENTS.md`, `CONTEXT.md`) before pass 1 and fold into every reviewer prompt: **(a)** decisions the project has settled — honor them like ADRs, and don't raise concerns they rule out (lockstep co-deployed repos make backward-compat and migration concerns non-issues); **(b)** the failure classes it documents — make pass 1 adversarial on those. Use the glossary's terms (`CONTEXT.md` / `UBIQUITOUS_LANGUAGE.md`) exactly. Don't re-litigate an ADR in the touched area; a reviewer wanting one reopened must say so and why. Offer a new ADR when a pass settles a load-bearing, hard-to-reverse trade-off.

## Simplicity bar and design vocabulary (both skills judge and author against this)

**Simple and easy to reason about — but correct and efficient first.** Simplicity is not fewer characters and never a licence to drop a case, a bound, or a guard; it is *less for the next reader to hold in their head*. Take the earliest remedy that works: delete the code → fold it into its one caller → clearer name or smaller function → *then* a new abstraction. A layer added to hide complexity usually just moves it, and a reviewer asking for a comment is usually asking for a simpler shape. The bar binds authoring too, not just judging: apply an accepted finding as the smallest edit that resolves it on every path it affects — no branch, field, flag, or wrapper the finding doesn't require.

Judge with these terms, so complexity findings are reproducible rather than taste:

- **Deep vs shallow module** — deep = small interface, much behavior behind it; shallow = interface nearly as complex as the implementation (a pass-through). Prefer deep.
- **Interface** — everything a caller must know to use a module correctly: signature *plus* invariants, ordering, error modes, required config, performance characteristics. **Seam** — where that interface lives (its own decision). **Adapter** — a concrete thing satisfying an interface at a seam.
- **Leverage** — behavior gained per unit of interface learned. **Locality** — change, bugs, knowledge, and verification concentrating in one place.
- **Deletion test** — imagine deleting the module: complexity vanishing means it was a pass-through; complexity reappearing across N callers means it earned its keep.
- **One adapter is a hypothetical seam; two is a real one** — don't build a seam unless something actually varies across it.

Accept a simplification only when behavior stays identical on every path the subject touches and no hot path gets measurably or asymptotically worse. Efficiency claims follow the calling skill's evidence rules; "simpler" is never evidence, and neither is "faster".

## Comment discipline (fixes apply it; a plan writes it into its conventions)

Default to **no comment** — clearer names, smaller functions, and deleted dead branches beat a comment explaining them. A comment is justified only for what the code cannot show: a non-obvious invariant, a why-not-the-obvious-way, a hazard or workaround with its cause, a contract a caller must honor. Decided on the first write, ~1–2 lines, no narration, no "fixed X", no reference to this review, no commented-out code.

## The ledger

Append-only: `key → finding → disposition (why) → strikes → change → [skill-specific fields]`. Pass it to the next reviewers in two parts, so anti-oscillation doesn't cost independence:

- **Factual** (always) — what changed, and any new invariant the work now depends on.
- **Rationale** — for accepted and deferred findings; **withheld** for a still-open at/above-threshold finding the author rejected.

## Severity (inject verbatim; the threshold keys on it)

- **High** — wrong behavior, data loss, a broken/incompatible contract, a memory-safety/security defect, or a plan step that will produce one. Blocks convergence.
- **Medium** — correct but fragile, unmaintainable, or under-specified: a latent hazard, a missing test at a real seam, a shallow or leaky design that will cost the next change.
- **Low** — taste, polish, naming, comment nits. Never blocks the loop.

## Stop rule

Stop on **any** of: nothing at/above threshold; the tier's cap; any anti-oscillation trigger; triage that produced no edit (bar the one confirming reviewer a contested rejection earns); or the **ship condition** — requested work implemented and validated, every open finding below threshold or an accepted residual risk in the ledger. The loop protects the deliverable; it does not outlast it.

Cap hit with open Highs, or an oscillation exit ⇒ **not converged**, with the open list. A reviewer that can't run ⇒ **blocked**, not complete. Don't chase zero findings; reviews regenerate nits indefinitely.

## Final output (skeleton; the calling skill adds specifics)

Write it — and every question routed to the user — in the language the user used (English request → English report; 中文请求 → 中文报告). Internal artifacts may stay English; glossary terms keep their original form.

- Tier, passes, reviewers spawned, and why the loop stopped (threshold / cap / oscillation / no-edit / ship condition / not converged / blocked) — the price belongs next to the result.
- The ledger: accepted, rejected, deferred, frozen — and why.
- Open findings below threshold, listed not fixed; questions and frozen trade-offs routed to the user.
- Domain/ADR notes: terms adopted, ADRs respected, any proposed.
