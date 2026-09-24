---
name: reply-format
description: Justin's required shape for every substantive reply — what happened, then actionables, then approvals, in scannable point form. Use on any reply reporting work done, status, findings, a plan, or a failure. Not for one-line answers to one-line questions.
---

# Reply format (binding — Justin, 2026-08-22)

He parses replies fast and acts on them. Giant paragraphs bury the two things he
needs: **what changed** and **what he has to do**. Prose is the defect.

## The shape

```
**Status** — one line. Green / red / blocked / done.

What happened:
- one bullet per real thing. Past tense, specific.
- name the artifact: commit sha, run id, file path, URL.
- a failure gets ONE line: the error, then the fix. Not the investigation.

## Needs you
1. A TASK only he can do, as one imperative sentence: verb + exact thing + where/how
   to hand it back + what it unblocks. One action per item.

## Approvals
1. A QUESTION he answers yes/no (or picks A/B), ending in "?". Says exactly what you
   will do on yes, and what stays as-is on no.
```

## Needs you / Approvals — crystal clear or cut (binding — Justin, 2026-09-24)

He must be able to act on each item **from that line alone**, without reading the rest
of the reply or knowing the session. If he'd have to ask "what are you asking?", it's a defect.

- **Needs you = tasks. Approvals = questions.** Nothing else goes in either section — no
  status, no findings, no FYI, no "X merged without Y" statements. A fact that needs a
  decision becomes a question: not "Xero read-back had no Fable review", but "Run a Fable
  review of the Xero payment code before Xero is switched on?".
- **Number every item** so he can answer "1 yes, 2 B, 3 no".
- **One ask per item.** Never bundle ("create the app + send keys + ratify events" is three items).
- **Plain words.** No plan section numbers, lane names, ticket shorthand, gate ids or
  jargon he didn't coin. Name the concrete thing: the URL to sign up at, the file the key
  goes in, the page the sentence goes on.
- **Decisions are A/B with the default named.** "When a space's Mailchimp can't send: A)
  hold it and tell the owner (current), or B) send it through Kommonz instead?"
- **No closing offers to act.** "Say the word and I'll fix X" is an unasked question — make
  it an Approval item, or, if the work is already authorized, just do it. ("Say the word for
  the detail" is fine: that offers information, not action.)
- **Don't ask what you can already do.** Work that's already authorized (fixing red checks,
  finishing your own task) is neither a task for him nor a question — do it and report it.
- **Self-check before sending:** read each item alone. Is it a task he can start right now,
  or a question he can answer in one word? If not, rewrite it.

## Rules

- **Lead with status.** Green or red, in the first line. Never make him read to find out.
- **Bullets over paragraphs.** A paragraph is allowed only when one idea genuinely
  needs three sentences of connective reasoning. Two paragraphs in a row is a defect.
- **One line per failure.** `X failed: <error>. Fixed by <fix>.` The debugging
  narrative goes in the commit message, not the reply.
- **Questions use AskUserQuestion**, not prose. If the tool isn't available, put them
  under `## Approvals` as a numbered list with the options spelled out.
- **Separate the asks.** Things he must DO (`Needs you`) are not the same as things he
  must APPROVE (`Approvals`). Never merge them; never bury either in narrative.
- **Omit empty sections.** No "no actions needed" headers.
- **Evidence, not adjectives.** "run 32581258111 green" beats "working nicely".
- **No preamble, no recap of his own request, no closing summary of what you just said.**

## Length

Default ≤ 10 lines. A plan or analysis ≤ 20. Longer ONLY when he asks for a report,
walkthrough, or full explanation — then structure still applies, just more of it.

Supporting detail goes behind a one-line offer ("say the word for the detail"), never
into the reply body.

## When NOT to use

A one-line answer to a one-line question. `"Yes, it's green."` needs no headers.
Conversational turns stay conversational.

## Worked example

**Bad** — what he objected to:

> I've now finished setting up the runners and I wanted to walk you through what
> happened. First I checked the Mac and found that it had Xcode 26.3 installed,
> which meant that we could proceed with the archive step. Then I discovered that
> the keychain situation was more complex than expected, because there are actually
> two keychains on the machine and the password file only covers one of them…

**Good**:

> **Status** — iOS red, Android green.
>
> What happened:
> - Android release green on the new runner (`box-coworking-android`).
> - iOS failed 3× on signing. Fixed each: keychain tolerance (`cab191c`),
>   missing `DEVELOPMENT_TEAM` (`434e674`), locked `lfos-sign` keychain (`4c6f821`).
> - Run 4 in flight.
>
> ## Approvals
> 1. Move Android PR checks to our own runner too? On no, they stay on GitHub's
>    runners so a PR never waits behind a busy box.

### Needs you / Approvals — bad vs good (2026-09-24, the reply he couldn't parse)

**Bad**: topic fragments, bundled asks, a statement filed as an approval, an offer at the end:

> ## Needs you
> - Xero: create dev app + send client ID/secret/webhook key; ratify `integration_connected` + `email_provider_*` events
> - Salto: Johanna sends drafted email + gets Business Unit creds (Tadas back 28 Sep)
>
> ## Approvals
> - Xero money read-back merged after 2 Opus review rounds; plan wanted Fable/dual review — none recorded.
>
> Say word → I finish handoff + fix CI e2e + 2 broken timers.

**Good**:

> ## Needs you
> 1. Create a Xero developer app at developer.xero.com, then drop its client ID, client
>    secret and webhook key into `~/.config/commons/xero.env`. This lets us switch Xero on.
> 2. Ask Johanna to request Salto KS test credentials (a "Business Unit") from Salto.
>    This lets us test the Salto doors.
>
> ## Approvals
> 1. Run a Fable review of the Xero payment code before Xero is switched on? It's live
>    but off. On no, it stays as reviewed by Opus.
> 2. Approve the analytics event name `integration_connected`? PostHog can never rename
>    it. On no, nothing is sent until you pick a name.
