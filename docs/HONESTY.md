# How Dhar keeps its claims honest

Dhar is early. It has a working Stage 0 compiler, a Stage 1 that is scaffolding, and a large design. Every public
statement has to say which of those it is talking about. This file is the rule book, and `tests/test_status.py` enforces
the parts a machine can check.

## 1. Four words, used the same everywhere

| Word | Means | Needs |
| --- | --- | --- |
| **Works** | It runs, and a test in the repository passes | The test, and the boundary of what it covers |
| **Partly** | Some of it runs and is tested; the rest does not | Which part, in the same sentence |
| **Designed** | A written specification exists; the code does not work | The document |
| **Not yet** | Nothing exists | Nothing |

"Complete" is never used alone. It is always "complete within the Strict Alpha subset" or the boundary that applies.

## 2. Two kinds of document, kept apart

* The **Canon** says what Dhar is to become. It is forward-looking and contains no status.
* **Status** says what Dhar does today, with evidence and a date. It lives in `status/status.json` and the files made
  from it (`PROGRESS.md`, the README status table, the website board and timeline).

A design promise is never copied into status as if done. A status line is never copied into the Canon.

## 3. One source of truth

`status/status.json` holds every status statement: the component board, the pipeline, the back-end chips, the direction
tracks and gates, and the dated milestones. `benchmarks/results/*.json` holds every speed number. Nothing else is edited
by hand for these. After editing either file:

```
python3 status/render.py        # rewrites the generated blocks
git add -A && git commit
```

The generated blocks sit between markers such as `<!-- status:board:start -->` and `<!-- gen:status:start -->`. Editing
inside them is pointless: the next run overwrites it, and the test fails until it is regenerated.

**Order of commits.** Commit the code change first, then run `render.py`, then commit the result. The status block
quotes the last commit that touched `src`, `tests` or the `Makefile`, which is only known once the code is committed.

## 4. What the test checks

`python3 tests/test_status.py` fails when:

1. a generated block differs from what `status.json` and the benchmark JSON would produce;
2. `facts.battery_total` differs from the number of tests a real run reports, on each target that can be run;
3. a status word is not one of the four, or an id repeats;
4. a gate in `status.json` is not written up in Canon Amendment A-1;
5. a retired claim reappears (the list is in the test; add to it whenever a claim is withdrawn);
6. the website stops linking to the survey as `survey/`, or claims that Dhar beats C.

The site's own test (`python3 site/tests/run_tests.py --dharc build/dharc --forge-repo .`) also compares the speed
chart with the JSON, the board's row counts with `status.json`, and the three samples with the real compiler's output.

## 5. Rules for claims

1. **A number comes from a run.** Say which run and which commit. Speed figures are always given as median and mean
   together, with the workload named; the median is the steadier one at millisecond scale.
2. **A comparison names what it compared.** "Faster than Python, Java, PHP and Node on this workload" is a claim.
   "Fastest" without a list is not. Nothing was measured against other non-optimising compilers, so nothing is claimed.
3. **"Works" on a platform means it ran on that platform.** Windows output has run in an emulator that enforces the
   Windows calling rules; it has not run on a real Windows machine, and the board says "Partly" until it has.
4. **Absence is stated.** The board lists what does not exist (self-hosting, optimiser, modules, the in-browser
   playground) in the same list as what does.
5. **A correction is a new entry.** Old milestones are not edited. If one was wrong, a later entry says so.
6. **A withdrawn claim goes in the retired list** in `tests/test_status.py` so it cannot return.

## 6. Speaking to collaborators, funders and the public

The default way to say where Dhar stands, until the author decides otherwise, is two short statements together:

> **Specified:** the Canon, in four volumes, describes a systems language and toolchain with a security, AI and quantum direction.
> **Compiles today:** a Stage 0 compiler for a strict subset, producing Linux x86-64 programs and Windows x64 programs checked in an emulator; every conformance test passes (the count is in `status/status.json`). The Stage 1 compiler in Dhar is scaffolding, and self-hosting has not been attempted.

Use the same two statements, with the numbers filled in from `status.json`, in every proposal and application.

## 7. When a review finds a drift

Fix the source of truth, run `render.py`, commit. If the drift came from a hand edit inside a generated block or from a
document the generator does not cover, add that document to `render.py` so it cannot drift again.
