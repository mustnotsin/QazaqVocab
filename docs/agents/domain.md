# Domain docs

QazaqVocab uses one domain context.

Before changing product behavior or learner-facing language, read `CONTEXT.md` at the repository root. Use its canonical terms in issues, tests, UI proposals, and implementation explanations.

Before changing an area governed by an architectural decision, read relevant records under `docs/adr/` when that directory exists. If a proposed change contradicts an ADR, surface the conflict explicitly.

Create domain documents lazily:

- `CONTEXT.md` is a glossary, not a feature specification or implementation plan.
- `docs/adr/` records only decisions that are hard to reverse, surprising without context, and selected through a real trade-off.
- Missing ADRs are not an error; proceed unless a qualifying decision is being made.
