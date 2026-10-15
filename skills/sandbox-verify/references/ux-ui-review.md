# UX/UI review — the rubric every browser QA pass applies

Canonical file; link here, never copy it. Justin, 2026-10-15: "we should always be checking UX and UI
also". A browser QA verdict that only proves each journey works is incomplete: the Insights Home shipped
on a functional APPROVE while it looked clunky and unprofessional, and no designer had looked at it.

## Scope and bar

- Every **changed screen** (and every state the change touches: empty, loading, error, filled) at
  **1440 px** and **390 px** wide, in the real browser, light theme plus dark where the app ships it.
- The bar is top-tier SaaS: **Linear, Notion, Stripe, Hex, PostHog, ChatGPT/Claude**. Ask "would this
  screen pass in their product?", not "does it work?".
- Read every screenshot yourself before writing a finding or a verdict. A capture taken mid-load or
  cropped is retaken, not judged.

## Checklist

1. **Layout grid and alignment** — edges share one column grid; nothing breaks the column, overflows,
   clips, or floats off the alignment line of its neighbours.
2. **Visual hierarchy** — the primary thing on the screen is obviously primary; one primary action;
   secondary detail visibly recedes.
3. **Component consistency** — one style per button, chip, card, input, table and icon size on the
   screen; matches the app's existing components and tokens.
4. **Spacing rhythm** — gaps follow the spacing scale; equal siblings have equal spacing; no cramped
   or orphaned blocks.
5. **Typography scale** — a few sizes and weights from the type scale; no ad-hoc sizes; headings,
   labels and body text are distinguishable.
6. **Colour and contrast** — tokens only; text and meaningful icons meet WCAG AA (4.5:1 body, 3:1
   large text and UI parts); colour is never the only signal.
7. **Density and dead space** — the information density fits the job; no large empty regions, no
   wall of controls.
8. **Empty, loading and error states** — each one exists, is designed, says what happened and what
   to do next; no layout jump when data arrives.
9. **Copy clarity** — plain, specific, consistent terms; no internal jargon, placeholder or debug text,
   no wrong language.
10. **Affordances** — controls look like what they do; no dead, misleading, or hidden controls;
    hover, focus and disabled states are visible; keyboard focus order is sane.
11. **Motion** — purposeful and quick; nothing janky; `prefers-reduced-motion` respected.
12. **Responsive behaviour** — 390 px is designed, not squeezed: no horizontal scroll, touch targets
    ≥ 44 px, tables and toolbars adapt.

## Severity

- **BLOCKING:** broken or misaligned layout; inconsistent component styles on the changed screen;
  a contrast failure; a misleading or hidden control; a changed screen that is visibly unpolished
  against the bar.
- **NON-BLOCKING:** taste — a better alternative to something that already meets the bar. File it.

## Output (in the BROWSER-QA.md verdict file)

```
## UX/UI review
1. BLOCKING — <screen> @1440 — <finding> — <fix> — verify-shots/<lane>/<shot>.png
2. NON-BLOCKING — <screen> @390 — <finding> — <fix> — verify-shots/<lane>/<shot>.png
UI VERDICT: <APPROVE|CHANGES>    (CHANGES only with ≥1 BLOCKING)

VERDICT: <APPROVE|CHANGES>       (APPROVE only when the journeys AND the UI pass)
```

`~/.claude/hooks/prod-browser-qa-gate.sh` refuses a production merge whose `BROWSER_QA` file lacks
either the `UI VERDICT: APPROVE` or the `VERDICT: APPROVE` line. `BROWSER_QA=none:<reason>` remains
for docs-only, infra-only and non-UI changes.
