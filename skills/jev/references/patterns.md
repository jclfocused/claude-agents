# Jev patterns and cookbooks — decompositions, thresholds, when to use

Condensed 2026-09-20 from docs.typesafe.ai patterns + 18 cookbooks. Thresholds are the cookbooks' own, tuned on their corpora — derive yours (see SKILL.md §Testing).

## 5. Patterns and cookbooks

### Route / fill — turn free text into a typed decision

**Intent routing.** One Choice for intent (+ optionally one Score for complexity) in front of a mix of handlers: deterministic DB lookup, specialist LLM prompts with different loaded context, human agents. Route with plain `if`s; escalate on `intent.confidence < 0.5`, and check confidence on the
*score* too — a confidently-classified complaint with an unreliable complexity reading is still an unsafe auto-action. Use when an expensive downstream resource should only be invoked for the requests that need it. *(Choice + Score; `/patterns/intent-routing`.)*

**Speculative fan-out.** Put every question the whole decision tree could need into one request, even the ones most branches discard, and filter in code afterwards. Questions are evaluated in parallel and the state is billed once, so an extra question adds tokens but barely any latency, while an extra round trip adds a full request. Measured: 13 questions in one call cost $0.000497 / 0.27 s versus $0.006090 / 2.71 s as 13 calls — 12.2× cheaper, 10.0× faster, with identical answers (11 of 13 questions had std dev exactly 0.0000 either way). Use for triage, wizards, anything with branches.
*(All primitives; `/patterns/fan-out`, `/cookbooks/parallel_questions`.)*

**Function calling.** Derive questions from Python type hints: `Literal[…]` → a Choice, `list[Literal[…]]` → one Noul per member, `bool` → a flag Noul; `int`, free text and dates get no question and keep the function's default. 10 functions + 28 fillable args became 54 questions in one request; the dispatcher reads only the chosen function's answers. A per-argument `stated` Noul makes an argument optional — answer no, omit the arg, the default stands. Every value that reaches the function is legal by construction: no JSON-schema validation layer, no parse-retry loop.
*(Choice + Noul; `/cookbooks/function_calling`.)*

**Date extraction.** Seven Choices in one call — mode (absolute/relative/none), month, day, year (1900– 2050 + `out_of_range` + `none`), day anchor, weekday, week offset — and **all calendar arithmetic in code**. Gate at `min(confidence of the parts you used) < 0.60` → human review. Use for any field the model reads but must not compute. *(Choice; `/cookbooks/date_extraction_cookbook`.)*

**Autoformat / structure recovery.** Two requests per document: pass 1 asks one Noul per adjacent line pair ("does this line pick up mid-sentence?"), pass 2 asks a Choice per merged block for its type. Merge thresholds are punctuation-conditional (0.2 after a dangling line, 0.5 after terminal punctuation) because no single threshold works for both. Direct evidence a regex can see — blank lines, `- `, `1.`, `#` — never goes to the model. Use for OCR output, pasted plain text, scraped threads. *(Noul + Choice; `/cookbooks/autoformat`.)*

### Select, don't generate

**Pre-parsed value extraction.** A regex over-finds candidate spans; a Choice whose `criteria` *are* those spans (plus an explicit `none`) picks the right one; code copies it verbatim. Because the model only selects among strings that already exist, "it cannot invent a value or transpose a digit". Use for IBANs, totals, order ids, phone numbers — anything where a corrupted character is unacceptable. The hard part becomes candidate generation, which regex solves for structured fields and does not solve for names. *(Choice; `/cookbooks/pre_parsed_value_extraction_cookbook`.)*

**Semantic find.** Tag document lines `L000…L217`, then in one request ask a Choice over the line ids (criteria all `null`) **and** a Noul "does any line answer this at all". The Choice says *where*, the Noul says *whether* — necessary because Choice probabilities always sum to 1 and will name a line even when the document is silent (observed: top line 0.86 while exists = 0.14). Thresholds 0.7 / 0.35; present answers typically read ≥0.9, absent ≤0.05. Gives line-level provenance for free.
*(Choice + Noul; `/cookbooks/semantic_find`.)*

**Hierarchical classification.** One Choice per node over its direct children, walked in code. Greedy top-1 descent is fragile (2 of 4 correct, once landing on a "not otherwise provided for" catch-all);
**beam search with K=3 got 4 of 4**. Path score = `product(edge_probabilities) ** (1/decisions)` (length-normalized so shallow and deep leaves compare); `separation = top/second` is a useful ambiguity metric. Send opaque option keys (`c0, c1…`) mapped back client-side; a single-child node short-circuits with no API call. This is also the documented way past the 255-option cap: narrow to a window, then rank inside it. *(Choice; `/cookbooks/hierarchical_classification`.)*

**Skill / tool suggestion.** Call 1 ranks 182 options in one wide Choice (0.16–0.31 s) plus three gating Nouls; call 2 re-reads the top 3 with 700 chars of real text each plus one `fits::` Noul per candidate. Both stages may return nothing (gate 0.30 on the mean of three oriented nouls, fits 0.30 on the max). Measured against a coding agent: wrong loads 16.8% → 7.3%, needless loads 9.8% → 4.0% — but it fixed 37 and **broke 7** of 315, because a confident wrong suggestion is more persuasive than no suggestion. Append the hint *after* the cached roster block or you invalidate the prompt prefix cache every turn. *(Choice + Noul; `/cookbooks/skill_suggestion`.)*

### Find and judge — retrieval quality

**Rerank.** BM25 (or any cheap retriever) produces a top-30 shortlist; then **one Noul per (query, candidate) pair**, sorted descending by the noul. No rubric to invent, no cross-encoder to host. Measured on 40 CLERC legal queries over 3,565 passages: top-1 5%→18%, top-5 15%→35%, top-10 38%→62%, for 1,200 calls / $0.0645 total. Note pairs cannot be batched — cost scales linearly with k.
*(Noul; `/cookbooks/rerank_typesafe`.)*

**RAG passage classification.** One request per retrieved passage with four Nouls — `is_relevant`, `contains_answer_evidence`, `contradicts_query_premise`, `contains_prompt_injection` — routed first-match-wins in code: injection > 0.70 exclude, contradicts > 0.70 → conflicting-evidence bucket, relevant < 0.45 exclude, evidence > 0.55 include, else exclude. Injection is checked first because it is a security decision; contradiction before evidence so a premise-denying passage does not land in the accepted block. The generator receives accepted and conflicting as **two separate blocks** so it can push back on a false-premise question. Similarity alone could not separate these: the injected forum post ranked #1 by embedding and scored 0.99 on injection. Re-routing costs zero API calls.
*(Noul; `/cookbooks/classifying_rag_passages`.)*

**Citation check.** Exact substring match after normalizing whitespace and curly quotes; no match → `fabricated` with no model call at all. Otherwise one Choice over `supports` / `contradicts` / `says_nothing` → `verified` / `contradicted` / `unsupported`, auto-accepting at 0.8 confidence. On 8 RFC-7519 citations: 4 accurate all ≥0.93, the contradiction caught at 0.99, two weak ones at 0.27 / 0.56 sent to a human. *(Choice; `/cookbooks/citation_check`.)*

### Judgments as features

**Composite scoring.** Break one complex judgment into several one-dimension Scores in a single call, normalize each by `len(criteria) - 1`, then weight them **in your code**. Resume example: four scores, two weight vectors (Senior IC 0.40/0.10/0.40/0.10, Eng Manager 0.15/0.40/0.20/0.25) → two rankings from one API call. Re-prioritizing is a constant change, not a prompt rewrite, and the per-dimension scores are the explanation of the composite. *(Score; `/patterns/composite-scoring`.)*

**Autoresearch feature discovery.** An LLM proposes questions, Jev answers them over every row, a gradient-boosted model trains on the answers, and its worst-predicted rows feed the next proposal round. Encoding: a Score becomes two columns (expected level + spread), a Noul one; 38 questions → 67 columns. Held-out RMSE on 800 wine reviews: predict-the-mean 3.09 → CatBoost word counts 2.47 → *ask Jev for the score directly* 2.15 → 18 questions 1.87 → 38 questions 1.77. Request count scales with
**rows**, not questions — one request per row per round, and a revised question costs a full new pass.
*(Score + Noul; `/cookbooks/autoresearch_feature_discovery`.)*

**Entity alignment.** 450 candidate pairs, one request each: a single 3-level Score whose middle level is literally written as "may or may not be the same" plus three context Nouls for the human reviewer. The entire decision rule is `OUTCOME[min(int(score + 0.5), len(LEVELS)-1)]` — round to the nearest level, no fitted threshold anywhere. Outcome split 8.9% merge / 11.1% curator / 80.0% unlinked. ABV deliberately gets no question: arithmetic belongs in code. *(Score + Noul; `/cookbooks/entity_alignment`.)*

### Verify and escalate

**LLM guardrails.** One request per message, on **both** directions with different batteries: input (jailbreak, harmful request, medical advice, self-harm, severity) and output (broke policy, harmful request, medical advice, self-harm, severity). Four Nouls + one 0–3 severity Score. Two thresholds per hazard (review 0.35, action 0.70 strict / 0.85 permissive) plus a severity promoter, resolved by precedence `support > block > review > pass`. The same assessment blocks under one policy and only reviews under the other — the split is your product's, not the model's. Measured: the DAN prompt 0.98, a subtler framing 0.74 (blocked strict, reviewed permissive), a novelist's poison question passed at 0.05 despite severity 0.8. *(Noul + Score; `/cookbooks/llm_guardrails`.)*

**Structured-extraction cascade.** A cheap LLM extracts; a per-field Noul battery verifies (seven metrics — name/desc mismatch, type mismatch, unreasonable, hallucinated, off-target, incomplete, format violation — plus `absence_wrong` for empty fields); only flagged records pay for the expensive reasoning model. Fire at 0.7, aggregated with **max, not mean** — a mean averages one confident red flag into silence. The per-field heads massively outperform a holistic "is this record wrong" head (0.95 vs 0.56 on the same fabricated field), so the holistic head is computed and deliberately excluded from the gate. Note a JSON-Schema-valid record can still be a fabrication: schema validation is necessary, not sufficient. *(Noul; `/cookbooks/sde_cascade`.)*

**Confidence-gated routing.** Confidence as a second decision axis: one global floor below which nothing is automated, then a per-action threshold sized to the consequence of being wrong. Banking example: floor 0.6 → human; `check_balance` acts at 0.6 ("worst case is the user hearing their balance"); `approve_transfer` auto-executes only above 0.85 and asks for confirmation between. Low confidence always gets a named destination, never a silent default. *(Choice; `/patterns/confidence-routing`.)*

**Consistency harness.** 15 repeats per condition with a fresh nonce, measuring **repeatability, not accuracy**. Noul: mean per-question probability std dev 0.0102, but `covered` spanned 0.43–0.53, crossing a 0.5 threshold — hence the recommended `<0.30 no / 0.30–0.70 uncertain / >0.70 yes` band. Choice: raw plurality agreement 90.8% → **99.2%** once `max(probabilities) < 0.60` becomes `uncertain`, leaving 74.2% automatic and zero questions with two different concrete labels.
*(Noul, Choice; `/cookbooks/consistency_noul_cookbook`, `/cookbooks/consistency_choice_cookbook`.)*

### Changing state

**Classification using confidence.** 75-option SIC-code Choice; above 0.9 confidence report the narrow industry group, below it report the parent **division** — a broader-but-still-useful label at no extra call. On 60 SEC filings: confident half 27/30 (90%) right, unsure half 12/30 (40%) → 70% once reported one level up, 48/60 useful overall. Generalizes to any taxonomy with a rollup.
*(Choice; `/cookbooks/classification_using_confidence`.)*

**Second requests only on a real dependency.** Make a second call only when your code cannot build it without the first answer — to fetch more data, to decide what the next state contains, or to pick the next question's options. Everything else batches. Named exceptions: skill suggestion (rank 182, then re-judge the top 3), structure recovery (merge lines, then classify blocks), hierarchical classification (each Choice picks the next options).

**Smart-home demo.** The one published demo. Category, domain, device type and action asked in one speculative fan-out even though most are irrelevant; a Noul detects a compound request and an LLM splits it into atomic commands, each re-evaluated by Jev; conversational turns fall back to an LLM, where "the initial TypeSafe response is so fast compared to the LLM response that it adds negligible latency." Source not yet public.

---


## 10. Generic use-pattern catalogue

Ordered by likely value on a typical product.

> The catalogue below is authored here for this brief. TypeSafe publishes its own industry→workflow map at https://docs.typesafe.ai/concepts/use-case-map; where the two differ, the vendor's is the marketed scope and this one is our reading.

1. Inbound queue of free text (tickets, emails, alerts, intake) → one fan-out call returns category, severity, sentiment and flags; route in code. *[Choice+Score+Noul — fan-out / intent-routing]*
2. An expensive LLM or agent runs on every request → put a cheap classifier in front and only pay frontier prices on the hard tail. *[Choice+Score — intent-routing]*
3. An assistant that can take actions → gate each action on a confidence threshold proportional to reversibility, with a confirm band in between. *[Choice — confidence-routing]*
4. A RAG pipeline → per-passage relevance/evidence/contradiction/injection Nouls between retrieval and the prompt, accepted and conflicting passed as separate blocks. *[Noul — classifying_rag_passages]*
5. A retriever whose top-1 is mediocre → rerank its top-k with one Noul per pair and sort by the probability. *[Noul — rerank_typesafe]*
6. An LLM-facing surface with no guardrail → two Noul batteries plus a severity Score, on input and output, with policy thresholds as product config. *[Noul+Score — llm_guardrails]*
7. LLM-generated structured output written to a DB → per-field Noul verification battery, escalate on max > 0.7. *[Noul — sde_cascade]*
8. Any ranked queue with competing stakeholders → one-dimension Scores in one call, several weight vectors applied in code for several rankings. *[Score — composite-scoring]*
9. A deep internal taxonomy (support tree, chart of accounts, policy tree, agent roster) → beam search K=3 over per-node Choices. *[Choice — hierarchical_classification]*
10. Extraction where a corrupted character is unacceptable → regex finds candidates, Choice selects, code copies verbatim. *[Choice — pre_parsed_value_extraction]*
11. Tool/function dispatch from natural language → derive Choices and Nouls from type hints so every argument is legal by construction. *[Choice+Noul — function_calling]*
12. A dedupe or entity-resolution pipeline → 3-level Score whose middle level *is* the review queue, plus context Nouls for the reviewer. *[Score+Noul — entity_alignment]*
13. Claims or quotes in generated output → exact-match in code, then one relation Choice; four verdicts including `fabricated` for free. *[Choice — citation_check]*
14. A classifier that must degrade gracefully → report the parent category below a confidence gate instead of guessing or dropping. *[Choice — classification_using_confidence]*
15. A free-text column feeding a classical ML model → Scores and Nouls as calibrated numeric features (Score = 2 columns, Noul = 1). *[Score+Noul — autoresearch_feature_discovery]*
16. A date/amount/duration field a model must read but not compute → parts as Choices over closed sets, arithmetic in code, `min()` confidence gate. *[Choice — date_extraction]*
17. Text that lost its markup (OCR, pasted, scraped) → line-pair Nouls to heal wrapped sentences, block Choices for type; output is byte-derived from input. *[Noul+Choice — autoformat]*
18. Semantic search over one document where provenance matters → line-id Choice plus an existence Noul; returns *where* and *whether*. *[Choice+Noul — semantic_find]*
19. A multi-step wizard or decision tree → ask every question the tree could need on step one, render later steps from answers already in hand. *[all — fan-out]*
20. A "how many X" prompt anywhere → replace with one Noul per item and a sum in code; the model cannot count. *[Noul — jev-1.13 jaggedness]*
21. An existing LLM-as-judge in an eval pipeline → replace prose grading with typed Scores plus confidence so grades are comparable and thresholdable across runs. *[Score — consistency cookbooks]*
22. A real-time or per-keystroke surface → at ~0.1–0.5 s a typed judgment fits inside the request path (live intent detection, inline moderation before submit). *[all — smart-home demo]*
23. A human review queue with no principled entry criterion → route low confidence there, and use the accumulating low-confidence set as the labelled data telling you which criteria are ambiguous. *[Choice+Score — confidence-routing]*
24. A large agent skill/tool roster competing for context → rank wide, re-read the top 3, allow both stages to return nothing. *[Choice+Noul — skill_suggestion]*
25. A compound user request → one Noul detects "more than one distinct action", and only then does an LLM split it. *[Noul — smart-home demo]*

**The vendor's own map** (`/concepts/use-case-map`), for comparison.

Five headline categories (verbatim framing, condensed):
- *AI Automation Software* — interleave AI with reliable software so it can run a million times in the background with no human co-pilot; "code owns control flow (not markdown files)" while TypeSafe handles semantic decisions.
- *Real-time applications* — "frontier intelligence at real-time speeds (150ms)", pitched as faster than human perception: playable in games, embeddable in a UI.
- *AI Map Reduce over Big Data* — "100x cheaper" as the enabler for giant corpora: search, classify agent traces, extract features for prediction.
- *Universal Verification* — verify another AI's prompt, extractions, reasoning traces or tool calls; detect jailbreaks, citation errors and hallucinations "at a fraction of the cost for the actual LLM call".
- *Harness Engineering* — Jev inside the harness: model routing, semantic context retrieval, LLM error detection and guardrails, reasoning-trace classification.

Twenty example domains (same page): search and retrieval · scientific discovery · model routing · LLM guardrails · semantic code linting · feature extraction for predictive modeling · recruiting · lead generation · customer support · insurance claims · financial crime · legal and compliance · e-commerce marketplaces · moderation and trust & safety · advertising · gaming · risk assessment · demand forecasting · graphs and knowledge graphs.

Ten decision shapes ("Example task categories" — the shape vocabulary the docs expect you to design against): Classification (one known category wins) · Detection (probability one property is present) · Scoring (ordered rubric) · Routing (a category selects the next code path) · Search (find items matching a natural-language query) · Retrieval (most relevant context/records) · Ranking (order by semantic relevance or quality) · Verification (check an artifact for specific failure modes) · ML Feature Extraction (semantic signals for a classical model) · Structured Data Extraction (recover known fields from unstructured input).

---

