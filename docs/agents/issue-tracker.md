# Issue tracker: GitHub

QazaqVocab work lives in GitHub Issues for `mustnotsin/QazaqVocab`. Use the `gh` CLI from this clone so repository context is inferred from the `origin` remote.

## Workflow

- Read a ticket and its comments before acting: `gh issue view <number> --comments`.
- Treat native `blocked by` relationships as execution gates. Start only tickets whose blockers are closed.
- Parent specification issue `#1` defines the private TestFlight release. Its child issues `#2`–`#14` are the approved implementation slices.
- Update the assigned ticket with material discoveries that change its execution. Keep product-scope changes for explicit user approval.
- Close a ticket only after its acceptance criteria and required verification are complete.

## Pull requests as a triage surface

PRs as a request surface: no.

## Publishing

When a skill says to publish work to the issue tracker, create or update the corresponding GitHub issue. Implementation tickets use native sub-issue and dependency relationships when applicable.
