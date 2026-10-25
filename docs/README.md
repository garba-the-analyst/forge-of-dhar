# Where the other documents are

This repository holds the Stage 0 compiler (`dharc`), its tests, the benchmarks, and the single source of truth for what
Dhar can do today (`status/status.json`).

Everything else moved to the [Dhar-website-and-docs](https://github.com/garba-the-analyst/Dhar-website-and-docs)
repository, which is also the website (https://dhar.onrender.com):

* the website and the survey (`public/`),
* the Canon of Dhar and its amendments (`docs/canon/`),
* the progress reports (`docs/reports/`),
* the rules for honest claims (`docs/HONESTY.md`),
* the plan for ARM64, RISC-V and WebAssembly (`docs/MULTI-ISA-PLAN.md`).

That repository keeps a copy of `status/status.json` and the benchmark results, refreshed with
`python3 tools/sync_from_forge.py ../forge-of-dhar`, and fails its tests if the website drifts from them.
