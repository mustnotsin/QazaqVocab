# QazaqVocab agent guide

Read `CONTEXT.md` before changing product behavior, vocabulary concepts, or learner-facing language.

For TestFlight work, read the assigned GitHub issue in full, including comments and native blockers. Read parent specification issue `#1` when the ticket's acceptance criteria require broader product context. Work one unblocked ticket at a time and keep its acceptance criteria as the completion boundary.

## Agent skills

### Issue tracker

Work is specified and tracked in this repository's GitHub Issues. See `docs/agents/issue-tracker.md`.

### Triage labels

Implementation tickets use the canonical five-role triage vocabulary. See `docs/agents/triage-labels.md`.

### Domain docs

This repository uses a single-context domain layout. See `docs/agents/domain.md`.

## Verification

Build behavior test-first at the highest practical seam. Before claiming a ticket complete, run every relevant test and check every acceptance criterion against fresh evidence. Finish implementation tickets with a Standards and Spec review of the diff.
