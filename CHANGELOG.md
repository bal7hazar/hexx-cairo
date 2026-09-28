# Changelog

Format: [Keep a Changelog](https://keepachangelog.com/en/1.1.0/). One entry per version, four
fixed headings (plan §9.4): *Parity* (items ported, counterparts, exclusions, the percentage),
*Extensions* (new or changed functions, with their need), *Deviations* (new or changed documented
differences from `hexx`), *Results changed* (any numeric change, with the affected functions and
the reason; empty on a PATCH). The game reads the last heading to know whether its test vectors
move. Versions before `0.1.0` are pre-releases (`0.1.0-rc.N`); nothing is published yet
(decision L-G2: publication needs the owner's explicit go).

## [Unreleased]

Workspace, CI, parity and gas tooling, and a rehearsed (not run) publication pipeline (LIB-04).
No mirror item and no extension exist yet: milestone L-M1 (LIB-05) is the first task that adds
one. `crates/hexx` carries one placeholder public item so every tool has something to run on.

### Parity

Nothing ported yet. `docs/API_PARITY.md` is generated from the pinned `hexx` 0.25.0 checkout;
every mirror item is `missing` or `dropped`/`renamed` where a whole-module exclusion or a named
counterpart applies (plan §4.2). 0.0 % parity.

### Extensions

None yet (`docs/EXTENSIONS.md`).

### Deviations

None yet (`docs/DEVIATIONS.md`).

### Results changed

Nothing shipped, nothing to compare against.
