# Iteration and feedback protocol

## Approval semantics
Record exactly what the user approved.

Examples:
- “The opening is good” -> opening only.
- “B is better” -> B is preferred, not approved.
- “Keep everything except drums” -> preserve all other currently referenced elements.
- “Use this” -> clarify from context whether it means concept baseline, runtime asset, or final release only when ambiguity materially affects work.

Never infer approval from silence.

## Experiment size
Use the smallest experiment that can answer the current question.

- Exploration: 2–3 differentiated concepts.
- Focused correction: 1 revision by default.
- Ambiguous correction: baseline + 1–2 targeted variants.
- Technical/export task: no extra musical alternatives.
- Large user-requested batch: obey, but label unreviewed material experimental.

## Change discipline
Before rendering, write internally:
- baseline
- preserve
- change
- hypothesis
- success evidence

Avoid changing melody, harmony, instrumentation, tempo, mix and adaptive logic simultaneously unless the user explicitly wants a reset.

## Feedback record
Store detailed round records under `docs/music/rounds/` when useful. Preserve:
- candidate ID / hash
- date
- user wording
- scoped interpretation
- keep / change / avoid
- next hypothesis

Do not bloat `STATE.md` with full history.

## Listening questions
Ask a listening question only when it improves the decision.

Good:
- “Does A's opening feel less intrusive, while keeping the identity?”
- “Is the fuller section still background enough during driving?”

Skip it for:
- installation
- export
- file validation
- a straightforward single correction where the result itself is the requested deliverable

## Failure handling
After a small batch fails:
1. stop seed-chasing;
2. identify whether the failure is composition, timbre, mix, or generation control;
3. change the cause;
4. if model control is insufficient, switch technique rather than overprompting.

“None of these” is useful data.
