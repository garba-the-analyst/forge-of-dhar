# Canon amendment index

The Canon's working principle is that a correction goes into every affected document, not only the one where it began.
This index is the list of what each of the 14 documents must receive, so none is missed. It lists amendments, not
status; status never goes into the Canon.

**Read this first.** The Canon sources (the PDFs and the `dharstyle.py` design system that builds them) are not in this
repository and were not available when this index was written. Everything below is therefore written from three things
only: the document titles and volumes, the project's "Complete Picture" and bootstrap blueprint, and the Stage 0
repository's references to `StageAlpha` sections. Where a document's content is a guess from its title, the table says
so. Send the Canon sources (or the PDFs) and each amendment can be applied in place, in the document's own words, rather
than as a list here.

| Marker | Meaning |
| --- | --- |
| **Sure** | Follows from what the repository or the blueprint states |
| **Inferred** | Placed by the document's title or volume; check against the text |
| **Unknown** | The document's content could not be inferred; amendment is general |

## Amendments that apply to every document

* **X1. Direction paragraph.** Add the one-paragraph direction from A-1 section 2 where the document states Dhar's purpose.
* **X2. Order of domains.** Wherever a document lists the domains Dhar serves, order them: cybersecurity, then AI, then quantum, then the rest.
* **X3. Claims name their gate.** Any claim about security, speed or correctness points at the A-1 gate that backs it, or is reworded as an aim.
* **X4. No status.** Any sentence that describes what exists today moves to `PROGRESS.md`; the Canon keeps only what is to be.

## Per document

| # | Document | Volume | Amendment | Basis |
| --- | --- | --- | --- | --- |
| 1 | **Spec0** (vision) | I | Add principles P1 to P5 (A-1 section 3). Add the three tracks to the statement of purpose. State that independence means *no dependencies*, and that outside implementations serve only as test oracles. | Inferred |
| 2 | **Spec1** (language) | I | (a) Numeric types: `f16`, `bf16`, a complex pair, fixed-width vector types, and explicit wrapping, saturating and checked arithmetic. (b) A *secret* qualifier with the S2 rules, and an explicit reveal. (c) Extend the bounds-checking rule (§14.4) from `raw[N]` to every slice, tensor and view. (d) Define `sys` by name (`sys.write`, `sys.exit`) as well as by number, so one program can target several operating systems; the numbers differ (Linux x86-64 write is 1, Linux ARM64 and RISC-V write is 64). (e) Constant-time select and rotate as built-in operations. (f) Record in the subset section that `give` takes a value or one operation. Syntax proposals are provisional and fall under the Stage 1 freeze rule in `PROGRESS.md` §4. | Sure for (d), (f); Inferred for the rest |
| 3 | **Stage-alpha** (Stage 0) | II | (a) Target dispatch: `linux` and `windows` are the Stage 0 targets; **an unsupported target is a fatal error and never a fallback**. (b) Windows x64: the system bridge is a stub mapping Linux numbers 0, 1 and 60 to `ReadFile`, `WriteFile` and `ExitProcess`; calls keep the 16-byte stack alignment and 32-byte shadow space; the image is linked at a fixed low base because Stage 0 uses 32-bit absolute addresses. (c) `give` takes a value, or one operation (`+ - * / %`) over names and numbers; anything longer is rejected. (d) `gen` emits exactly the text, with no terminator. (e) The conformance battery is the acceptance gate for the subset, run on every supported target. (f) Other instruction sets belong to Stage 1, not Stage 0. | Sure (the repository cites `StageAlpha §2.2` and `§3`) |
| 4 | **Stage-beta** (Stage 1; assumed to be Stage 1 by order) | II | Add R1 to R5 (A-1 section 8). Add the back-end list in order (x86-64, ARM64, RISC-V, WebAssembly/WASI, Windows) with the target-description tables of R4. Add the S4 build gates: fixed point, diverse double-compilation, reproducibility. State that Stage 0 is archived after the hand-off. | Inferred (order and the Complete Picture) |
| 5 | **Stage-gamma** (Stage 2, the optimiser; assumed) | II | Add the constant-time-preserving rule (R2) as an invariant every pass must keep, with a test per pass. Add deterministic floating point as the default (no reordering without being asked). Add vectorisation as a goal for the A4 kernels. | Inferred |
| 6 | **Stage-delta** (Stage 3, standard library and tooling; assumed) | II | Add `std.crypto` (S3, then Q1), `std.num` and `std.tensor` (A1, A2), `std.quantum` (Q2, Q3). Add the documented weight-file format for A3. Make the conformance vectors part of the library's own tests. | Inferred |
| 7 | **Stage-epsilon** (Stage 4, hardening; assumed) | II | Add reproducible builds, bill of materials and signing (S4) as release gates; constant-time timing tests and fuzzing in continuous integration; a migration path for post-quantum algorithms. | Inferred |
| 8 | **Tempering Dhar** | III | Add the conformance-vector suites, the timing test of S3 and the gate table of A-1 section 9 to whatever it requires of testing and hardening. | Inferred from the title |
| 9 | **Casting Dhar** | III | Add X1 to X4 only. | Unknown |
| 10 | **The Guild of Dhar** | III | Add a two-reviewer rule and a published disclosure process for code in `std.crypto`. Add maintainer admission at the Stage 1 self-hosting gate (the author's stated plan; to ratify). | Inferred from the title and the author's plan |
| 11 | **Fueling Dhar** | III | Add X1 to X4 only. If it covers funding or sustaining the project, add that funding lines follow the track order and that audits of `std.crypto` are a named line. | Unknown |
| 12 | **The Hallmark of Dhar** | III | Add the rule that a trust mark or public claim is allowed only for a passed gate, with the exact form of words in A-1 section 10. | Inferred from the title |
| 13 | **Tooling Dhar** | III | Add `dhar test --vectors`, `dhar verify-build` (reproducibility), `dhar sbom`, and a tool to export a circuit as OpenQASM. The author noted this document was missing from the Canon files; if it is still missing, recreate it with these. | Inferred; the author's note |
| 14 | **The Pact of Developing Dhar** | IV | Add the honesty clause: four status words (works, partly, designed, not yet), one source of truth for status, claims need evidence, a correction is a new entry (`docs/HONESTY.md`). Add the two-reviewer rule for security code. Add that outside implementations are oracles only. | Sure for the honesty clause; Inferred for the rest |

## What is done and what is not

* Done: this index, A-1, and the rules in `docs/HONESTY.md`.
* Not done: editing the 14 Canon documents themselves. They are not here. Ratify A-1, send the sources, and each is
  amended in one pass.
* Open for the author: Stage-beta to Stage-epsilon are assumed to be Stages 1 to 4 by order, and the Volume III
  documents' contents are partly guessed. Correct any of these in your reply and the index will be fixed first.
