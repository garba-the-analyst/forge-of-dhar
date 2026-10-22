/*
 * questions.js: the "Shaping Dhar" question bank.
 *
 * This file is DATA. To add, reword or remove a question you only edit this file;
 * survey.js reads it and builds the page, the branching, the validation and the
 * email report from it.
 *
 * ---------------------------------------------------------------------------
 * HOW THE DATA IS SHAPED
 * ---------------------------------------------------------------------------
 *
 * SURVEY
 *   version    string   Bump it whenever question wording or option ORDER changes.
 *                       It is printed in every emailed response and it names the
 *                       browser-storage slot, so old saved drafts never mix with
 *                       a new question set.
 *   sections   array    The steps of the survey, in order.
 *
 * SECTION
 *   id         string   Unique, used in the DOM and in saved drafts.
 *   title      string   Step heading shown on the page.
 *   reportTitle string  Heading of this section in the emailed report (capitals).
 *   intro      string   One line under the heading.
 *   hideHeading bool    Optional. Keeps the heading for screen readers only (used
 *                       by the first step, where the page title already says it).
 *   showIf     cond     Optional. The step is skipped unless the condition holds.
 *   questions  array
 *
 * QUESTION
 *   code       string   Unique, stable. Used in the emailed report as "[A3]" and as
 *                       the CSV column name. NEVER reuse a code for a different
 *                       question.
 *   type       string   text | textarea | email | radio | checkbox | likert |
 *                       scale | grid
 *   text       string   The question, exactly as the respondent reads it.
 *   hint       string   Optional extra line under the question.
 *   required   bool     Must be answered before "Next". Default false.
 *   showIf     cond     Optional. The question is hidden (and left out of the
 *                       report and validation) unless the condition holds.
 *   group      object   Optional {id, title}. Consecutive questions with the same
 *                       group id are folded into one collapsible block.
 *   autocomplete string Optional. A browser autofill hint for text fields, for
 *                       example 'country-name' or 'email'. Default 'off'.
 *   placeholder string  Optional grey example text for text, textarea and email.
 *   replyTo     boolean Optional. When the answer contains an email address, the relay
 *                       (relay/Code.gs) uses it as the Reply-To of the delivered message.
 *                       Set it on the contact question only.
 *
 *   radio / checkbox
 *     options  array    Strings, or objects {id, label, hint, short, other, exclusive}.
 *                       "short" is a briefer name used in the email subject and the
 *                       "Roles:" line (only the role question uses it).
 *                       A string gets the positional id "o1", "o2", ... (so the
 *                       order matters; see "version" above). OTHER adds an
 *                       "Other" option with a free-text box. An option with
 *                       exclusive:true clears every other option when picked
 *                       (for "None of these").
 *     max      number   checkbox only: the most options that can be ticked.
 *     layout   string   'chips' lays short options out in a compact grid.
 *
 *   likert     Five points. Needs labels {1:'...', 3:'...', 5:'...'} for the ends
 *              (and optionally the middle).
 *   scale      Numbers from `from` to `to`, with labels {from:'...', to:'...'}.
 *   grid       rows: array of statements, each rated 1-5; labels as for likert.
 *   text/textarea/email   placeholder (optional).
 *
 * CONDITIONS (showIf)
 *   { role: 'student' }                    the respondent ticked that role
 *   { roleAny: ['prof', 'researcher'] }    any of these roles
 *   { q: 'C1', is: 'yes' }                 a radio question has this option id
 *   { q: 'A3', has: 'security' }           a checkbox question includes this id
 *   { q: 'A3', hasAny: ['web', 'mobile'] } includes any of these ids
 *   { all: [cond, cond] }  /  { any: [cond, cond] }
 */
(function (global) {
  'use strict';

  var OTHER = { id: 'other', label: 'Other', other: true };

  /* Shared option lists, so the same area is worded identically everywhere. */
  var AREAS = [
    { id: 'software',   label: 'Backend and software development' },
    { id: 'web',        label: 'Web' },
    { id: 'mobile',     label: 'Mobile' },
    { id: 'data',       label: 'Data analysis and data science' },
    { id: 'ai',         label: 'Artificial intelligence (LLMs, agents, vision, speech)' },
    { id: 'ml',         label: 'Machine learning (training, models, MLOps)' },
    { id: 'systems',    label: 'Systems and embedded programming' },
    { id: 'security',   label: 'Cybersecurity' },
    { id: 'blockchain', label: 'Blockchain and Web3' }
  ];

  var YEARS = ['Less than 1 year', '1 to 3 years', '3 to 5 years', '5 to 10 years', '10+ years'];

  /*
   * Builds the three optional "in detail" questions for one area. Keeping this in a
   * function guarantees every area is asked in the same way, so answers can be
   * compared across areas.
   */
  function areaBlock(prefix, groupId, title, when, capabilities) {
    var group = { id: groupId, title: title };
    return [
      {
        code: prefix + '1', type: 'checkbox', group: group, showIf: when, max: 5,
        text: 'What would Dhar need to offer in ' + title.toLowerCase() + ' before you would use it for real work?',
        hint: 'Choose up to 5.',
        options: capabilities.concat([OTHER])
      },
      {
        code: prefix + '2', type: 'textarea', group: group, showIf: when,
        text: 'Which libraries, frameworks or tools do you rely on in ' + title.toLowerCase() + ' today that Dhar would need to work with or replace?',
        placeholder: 'Names are enough, for example the packages you install most.'
      },
      {
        code: prefix + '3', type: 'textarea', group: group, showIf: when,
        text: 'What is the biggest problem in ' + title.toLowerCase() + ' that a new language could realistically help fix?'
      }
    ];
  }

  var SURVEY = {
    version: '1.0',
    title: 'Shaping Dhar',

    /* The role question is special: survey.js reads its answer to decide which
       role sections to show. Its option ids must match the { role: ... } conditions. */
    roleQuestion: {
      code: 'ROLE', type: 'checkbox', required: true,
      text: 'Which of these describe you?',
      hint: 'Pick every one that fits. You will only see the questions for the roles you pick.',
      options: [
        { id: 'prof',       group: 'Academics',
          label: 'I teach at a university, polytechnic or similar institution',
          hint: 'Professor, lecturer or instructor at a tertiary institution.',
          short: 'Academic (professor or lecturer)' },
        { id: 'researcher', group: 'Academics',
          label: 'I do technical or academic research',
          hint: 'Programming languages, compilers, computer systems, cybersecurity, AI/ML or related fields, whether or not you also teach.',
          short: 'Technical researcher' },
        { id: 'student',
          label: 'I am a student or independent learner',
          hint: 'Undergraduate, postgraduate, bootcamp, or learning on your own.',
          short: 'Student' },
        { id: 'dev',
          label: 'I work as a developer or engineer',
          hint: 'Another hands-on technical role also counts, professionally or seriously as an independent or freelance practitioner.',
          short: 'Developer or engineer' }
      ]
    },

    sections: [

      /* ------------------------------------------------------------------ */
      {
        id: 'start', title: 'Start', reportTitle: 'ROLES', hideHeading: true,
        intro: '',
        questions: [] /* filled with roleQuestion below */
      },

      /* ------------------------------------------------------------------ */
      {
        id: 'about', title: 'About you', reportTitle: 'ABOUT YOU',
        intro: 'A few basics, so your answers can be read in context.',
        questions: [
          { code: 'A1', type: 'text', required: true, autocomplete: 'country-name',
            text: 'Which country or region are you currently based in?' },
          { code: 'A2', type: 'radio', required: true, layout: 'chips',
            text: 'How many years of experience do you have with programming or software-related work?',
            options: YEARS },
          { code: 'A3', type: 'checkbox', required: true,
            text: 'Which of the following are you currently involved in, in any capacity?',
            hint: 'Select all that apply. The areas you pick decide which optional detail questions you see later.',
            options: [
              { id: 'software',   label: 'Software and application development (backend, tools, enterprise)' },
              { id: 'web',        label: 'Web development' },
              { id: 'mobile',     label: 'Mobile development' },
              { id: 'data',       label: 'Data analysis and data science' },
              { id: 'ai',         label: 'Artificial intelligence (LLMs, agents, vision, speech)' },
              { id: 'ml',         label: 'Machine learning (training, models, MLOps)' },
              { id: 'systems',    label: 'Systems and embedded programming' },
              { id: 'security',   label: 'Cybersecurity' },
              { id: 'blockchain', label: 'Blockchain and Web3' },
              { id: 'cloud',      label: 'Cloud and DevOps infrastructure' },
              { id: 'games',      label: 'Game development' },
              OTHER,
              { id: 'none', label: 'None of these yet', exclusive: true }
            ] },
          { code: 'A4', type: 'checkbox', required: true, layout: 'chips',
            text: 'Which programming languages do you currently use regularly?',
            hint: 'Select all that apply.',
            options: ['C', 'C++', 'Rust', 'Java', 'Python', 'JavaScript or TypeScript', 'Go', 'C#', 'Swift', 'Kotlin', 'PHP', 'Ruby', 'SQL',
              OTHER, { id: 'none', label: 'None yet', exclusive: true }] },
          { code: 'A5', type: 'radio', required: true,
            text: 'Before today, had you heard of Dhar?',
            options: ['No, this is the first time I am hearing of it',
              'I had heard the name but knew nothing about it',
              'I knew a little about it',
              'I am already familiar with it'] }
        ]
      },

      /* ------------------------------------------------------------------ */
      {
        id: 'prof', title: 'Teaching', reportTitle: 'ACADEMIC: PROFESSOR OR LECTURER',
        intro: 'For lecturers, professors and instructors.',
        showIf: { role: 'prof' },
        questions: [
          { code: 'P1', type: 'checkbox', required: true,
            text: 'What level(s) do you currently teach?', hint: 'Select all that apply.',
            options: ['Undergraduate: introductory and foundational', 'Undergraduate: advanced', 'Postgraduate (Masters)', 'PhD supervision', OTHER] },
          { code: 'P2', type: 'checkbox',
            text: 'Which courses do you teach (or have taught) that a new language could realistically fit into?',
            hint: 'Select all that apply.',
            options: ['Introduction to Programming', 'Data Structures and Algorithms', 'Compilers or Programming Language Theory', 'Operating Systems',
              'Computer Architecture or Systems Programming', 'Computer Security', 'Software Engineering', 'Database Systems', 'AI and Machine Learning', OTHER] },
          { code: 'P3', type: 'likert', required: true,
            text: 'How open would you be to introducing a new, independently built programming language into your teaching?',
            labels: { 1: 'Not open at all', 5: 'Very open' } },
          { code: 'P4', type: 'checkbox', required: true, max: 3,
            text: 'What would most influence that decision?', hint: 'Pick your top 3.',
            options: ['Quality and completeness of documentation', 'A textbook or structured course material', 'An existing job market for the language',
              'Institutional or departmental approval processes', 'Peer or colleague adoption elsewhere', 'Student interest and demand',
              'Tooling and IDE support', 'Being open source and freely usable', 'Alignment with accreditation or curriculum standards', OTHER] },
          { code: 'P5', type: 'likert', required: true,
            text: 'Dhar’s own bootstrap compiler is being built in public, stage by stage: lexer, parser, type checker, code generator, self-hosting. How useful would that documented process be as course material for a compilers or programming-languages course?',
            labels: { 1: 'Not useful', 5: 'Very useful' } },
          { code: 'P6', type: 'radio', required: true,
            text: 'Would you be interested in co-developing or piloting a course module using Dhar?',
            options: ['Yes, definitely', 'Possibly, send me more information', 'Unlikely', 'No'] },
          { code: 'P7', type: 'radio', required: true,
            text: 'Would you be willing to supervise a student thesis, dissertation or capstone project that extends Dhar?',
            hint: 'For example a standard-library module, a new hardware backend, or formally verifying part of its type system.',
            options: ['Yes', 'Possibly', 'No'] },
          { code: 'P8', type: 'textarea',
            text: 'What institutional or administrative barriers do you anticipate to adopting a new teaching language?' },
          { code: 'P9', type: 'textarea',
            text: 'Which existing language(s) do you currently find hardest to teach effectively, and why?' },
          { code: 'P10', type: 'textarea',
            text: 'Is there a specific gap in how programming or computer science is taught in your context that a language built for both teaching and real-world capability could help address?' },
          { code: 'P11', type: 'radio', required: true,
            text: 'Would free teaching materials, sample syllabi and instructor support increase your interest?',
            options: ['Yes', 'No', 'I already have enough information to decide'] },
          { code: 'P12', type: 'textarea',
            text: 'Any other thoughts, from a teaching perspective?' }
        ]
      },

      /* ------------------------------------------------------------------ */
      {
        id: 'researcher', title: 'Research', reportTitle: 'TECHNICAL RESEARCHER',
        intro: 'For people who do technical or academic research.',
        showIf: { role: 'researcher' },
        questions: [
          { code: 'R1', type: 'checkbox', required: true,
            text: 'Which areas does your research touch on?', hint: 'Select all that apply.',
            options: ['Programming language design and theory', 'Compilers and code generation', 'Formal verification and methods', 'Operating systems',
              'Computer and network security', 'Cryptography', 'Distributed systems', 'AI and ML systems', 'Human-computer interaction',
              'Software engineering', 'Data science and analytics', 'Blockchain and distributed ledgers', OTHER] },
          { code: 'R2', type: 'likert', required: true,
            text: 'How interested would you be in using Dhar as a research vehicle, for example to study multi-paradigm language design, memory-safety models without a garbage collector, or compiler bootstrapping?',
            labels: { 1: 'Not interested', 5: 'Very interested' } },
          { code: 'R3', type: 'likert', required: true,
            text: 'Dhar’s memory model combines compile-time ownership tracking with arena allocation, deliberately without Rust-style explicit lifetimes. How interesting is that specific trade-off as a research question?',
            labels: { 1: 'Not interesting', 5: 'Very interesting' } },
          { code: 'R3b', type: 'textarea',
            text: 'What would you want to test about it?' },
          { code: 'R4', type: 'radio', required: true,
            text: 'Would you be interested in independently verifying or benchmarking Dhar’s safety or performance claims once a working compiler exists?',
            options: ['Yes', 'Possibly', 'No'] },
          { code: 'R5', type: 'radio', required: true,
            text: 'The project has already identified one open problem. Proving the bootstrap compiler is free of a "Trusting Trust"-style backdoor requires an independently built second compiler for comparison (Diverse Double-Compiling). Are you interested in that as a research collaboration?',
            options: ['Yes, very interested', 'Interested, I want more detail', 'Not my area', 'No'] },
          { code: 'R6', type: 'textarea',
            text: 'Would you consider publishing or citing work related to Dhar’s design once there is a stable specification and working implementation? What would make it citation-worthy?' },
          { code: 'R7', type: 'textarea',
            text: 'What would you want to see benchmarked, formally proven or independently audited first?' },
          { code: 'R8', type: 'radio', required: true,
            text: 'Would open access to Dhar’s full specification and design-decision history, including rejected alternatives, be useful to your research process?',
            options: ['Yes', 'Somewhat', 'No'] },
          { code: 'R9', type: 'textarea',
            text: 'Any other thoughts, from a research perspective?' }
        ]
      },

      /* ------------------------------------------------------------------ */
      {
        id: 'student', title: 'Learning', reportTitle: 'STUDENT',
        intro: 'For students and independent learners.',
        showIf: { role: 'student' },
        questions: [
          { code: 'S1', type: 'radio', required: true,
            text: 'What best describes your current stage?',
            options: ['Undergraduate (early years)', 'Undergraduate (final years)', 'Postgraduate: Masters', 'Postgraduate: PhD', 'Coding bootcamp', 'Self-taught, independent learner'] },
          { code: 'S2', type: 'text',
            text: 'What was, or is, the first programming language you learned?' },
          { code: 'S3', type: 'checkbox', required: true, max: 3,
            text: 'What makes a programming language easy or hard for you to learn?', hint: 'Pick your top 3 concerns.',
            options: ['Clarity of error messages', 'Quality and quantity of documentation', 'Availability of tutorials and courses', 'Simplicity of syntax',
              'Community support (forums, Discord, Stack Overflow)', 'Job-market demand', 'IDE and editor support', 'Number of existing libraries', OTHER] },
          { code: 'S4', type: 'likert', required: true,
            text: 'How important is it to you that a language you invest time learning has strong job-market demand?',
            labels: { 1: 'Not important', 5: 'Essential' } },
          { code: 'S5', type: 'radio', required: true,
            text: 'Would learning a systems-level language (closer to C or Rust) that also reads simply (closer to Python) make you more interested in exploring lower-level programming, compilers or systems engineering?',
            options: ['Yes', 'Maybe', 'No', 'I am already interested regardless'] },
          { code: 'S6', type: 'radio', required: true,
            text: 'Would you be interested in contributing to Dhar’s open-source development as a way to build real experience, for example through a guided "good first issue" path?',
            options: ['Yes, very interested', 'Interested if guided', 'Not right now', 'No'] },
          { code: 'S7', type: 'radio', required: true,
            text: 'Would a free elective module, hackathon or recognized certificate around Dhar make it more appealing to learn?',
            options: ['Yes', 'No', 'It depends on whether my institution recognizes it'] },
          { code: 'S8', type: 'textarea',
            text: 'What worries you, if anything, about investing time in a brand-new language rather than an established one?' },
          { code: 'S9', type: 'textarea',
            text: 'What would most excite you about a Nigerian or African-built programming language specifically?' },
          { code: 'S10', type: 'textarea',
            text: 'Any other thoughts, from a student’s perspective?' }
        ]
      },

      /* ------------------------------------------------------------------ */
      {
        id: 'dev', title: 'Building', reportTitle: 'DEVELOPER OR ENGINEER',
        intro: 'For developers and engineers.',
        showIf: { role: 'dev' },
        questions: [
          { code: 'D1', type: 'checkbox', required: true,
            text: 'What is your primary domain of work?', hint: 'Select all that apply.',
            options: ['Backend and server software', 'Web development', 'Mobile development', 'Data analysis and data science',
              'Artificial intelligence (LLMs, agents, vision, speech)', 'Machine learning (training, models, MLOps)',
              'Systems, embedded and OS-level programming', 'Cybersecurity', 'Blockchain and Web3', OTHER] },
          { code: 'D2', type: 'radio', required: true, layout: 'chips',
            text: 'How many years of professional experience do you have?',
            options: ['Less than 1', '1 to 3', '3 to 5', '5 to 10', '10+'] },
          { code: 'D3', type: 'checkbox', required: true, max: 4,
            text: 'What would make you personally consider using a new systems language for a real project, even a small or internal one?',
            hint: 'Choose up to 4.',
            options: ['Proven, benchmarked performance', 'Strong memory-safety guarantees', 'Good IDE, editor and debugging support', 'A mature package ecosystem',
              'Ability to call existing C, Rust, Python and Java libraries', 'An active community and support', 'Clear, stable documentation',
              'Backing from a credible organization', 'Employer or team buy-in', OTHER] },
          { code: 'D4', type: 'textarea',
            text: 'What are your biggest deal-breakers, the things that would stop you adopting a new language regardless of its technical merits?' },
          { code: 'D5', type: 'grid', required: true,
            text: 'How important is each of the following to you?',
            hint: 'Rate every line from 1 to 5.',
            labels: { 1: 'Not important', 5: 'Essential' },
            rows: [
              'Performance at or above C’s level, with no garbage collector',
              'Memory safety guaranteed by the compiler (bounds checking, no use-after-free)',
              'Explicit typing for systems work, with inference for everyday code',
              'A dynamic-typing option for scripting-style flexibility',
              'Multi-paradigm support (procedural, object-oriented, functional, logical and symbolic in one language)',
              'Built-in async and concurrency support',
              'Generics and traits or interfaces for reusable code',
              'A package manager with real dependency resolution and lockfiles',
              'Direct interoperability with existing C, C++, Rust, Java and Python code',
              'Cross-platform support (x86-64, ARM64, RISC-V, WASI, Windows)',
              'Formal security assurance and audit-readiness for critical systems'
            ] },
          { code: 'D6', type: 'textarea',
            text: 'Which existing library or framework gap, if filled in Dhar, would most motivate you to actually use it?',
            placeholder: 'For example a web framework, an ML or data library, a crypto library, a blockchain SDK.' },
          { code: 'D7', type: 'radio', required: true,
            text: 'Would you contribute a package to Dhar’s package registry (Kun) if the core tooling were solid?',
            options: ['Yes', 'Possibly', 'No'] },
          { code: 'D8', type: 'radio', required: true,
            text: 'Which of these target domains are you personally most interested in using Dhar for?', hint: 'Pick one.',
            options: ['Backend and server', 'Web', 'Mobile', 'Data analysis and data science', 'Artificial intelligence', 'Machine learning',
              'Systems and embedded', 'Cybersecurity', 'Blockchain and Web3', OTHER] },
          { code: 'D9', type: 'textarea',
            text: 'What would convince your employer or team to seriously evaluate Dhar for a real project?' },
          { code: 'D10', type: 'textarea',
            text: 'Any other thoughts, from a developer or engineering perspective?' }
        ]
      },

      /* ------------------------------------------------------------------ */
      /* Optional deep dives, one block per area ticked in A3. */
      {
        id: 'areas', title: 'Your areas in detail', reportTitle: 'AREAS IN DETAIL',
        intro: 'You said you work in these areas. Open any you would like to say more about. Everything on this page is optional.',
        showIf: { q: 'A3', hasAny: ['software', 'web', 'mobile', 'data', 'ai', 'ml', 'systems', 'security', 'blockchain'] },
        questions: [].concat(

          areaBlock('SW', 'software', 'Backend and software development', { q: 'A3', has: 'software' }, [
            'Web server, HTTP, REST and gRPC libraries',
            'Database drivers (PostgreSQL, MySQL, SQLite, MongoDB, Redis)',
            'An ORM or query builder',
            'Logging, tracing and metrics',
            'Built-in testing, benchmarking and mocking',
            'JSON, TOML and YAML parsing and configuration',
            'Container and CI/CD support',
            'Calling existing Java, C# or Python services and libraries',
            'Fast compile times and hot reload',
            'Long-term backward compatibility'
          ]),

          areaBlock('WM', 'webmobile', 'Web and mobile', { q: 'A3', hasAny: ['web', 'mobile'] }, [
            'A WebAssembly target for the browser',
            'A web framework (routing, templating, sessions)',
            'Frontend, DOM bindings or a UI toolkit',
            'Android and iOS support',
            'HTTP client and WebSocket support',
            'Authentication libraries (OAuth, JWT)',
            'SDKs for African payments, mobile money, USSD and SMS',
            'Small binaries and low memory use for low-end phones',
            'Offline-first apps and data sync',
            'Easy deployment (a single static binary or serverless)'
          ]),

          areaBlock('DA', 'data', 'Data analysis and data science', { q: 'A3', has: 'data' }, [
            'A DataFrame library (like pandas or Polars)',
            'Readers for CSV, Excel, Parquet, JSON and SQL',
            'Plotting and visualization',
            'Numerical arrays and statistics (like NumPy and SciPy)',
            'A notebook or REPL experience',
            'SQL integration or a query engine',
            'Calling existing Python data libraries',
            'Handling large datasets in limited memory',
            'Geospatial and time-series support'
          ]),

          areaBlock('AI', 'ai', 'Artificial intelligence', { q: 'A3', has: 'ai' }, [
            'Calling hosted LLM and inference APIs',
            'Running local models (GGUF, ONNX) through bindings',
            'Embeddings, vector search and RAG tooling',
            'Agent and tool-calling frameworks',
            'Speech, vision and NLP tooling, including African-language models',
            'GPU and accelerator access (CUDA, ROCm, Vulkan, Metal)',
            'Tokenizer and prompt tooling',
            'Python interop for existing AI libraries',
            'Efficient on-device and edge inference'
          ]),

          areaBlock('ML', 'ml', 'Machine learning', { q: 'A3', has: 'ml' }, [
            'A tensor library with automatic differentiation',
            'Training loops, optimizers and common layers',
            'Interop with PyTorch, TensorFlow and JAX models (ONNX)',
            'GPU and accelerator compute kernels',
            'Data loading, augmentation and batching pipelines',
            'Experiment tracking, model packaging and serving (MLOps)',
            'Classical ML (like scikit-learn)',
            'Reproducible, deterministic numerics',
            'Quantization and edge or embedded deployment'
          ]),

          areaBlock('SY', 'systems', 'Systems and embedded programming', { q: 'A3', has: 'systems' }, [
            'Direct hardware access (registers, volatile memory, inline assembly)',
            'A freestanding, no-runtime mode for kernels and bare metal',
            'Deterministic memory with no garbage-collection pauses',
            'Targets such as ARM Cortex-M, RISC-V and x86-64',
            'Linker-script and memory-layout control',
            'Debugger support (GDB, LLDB, DWARF)',
            'Calling C libraries through the C ABI',
            'Interrupt, DMA and async embedded support',
            'Static analysis and worst-case stack bounds',
            'Safety-certification evidence (MISRA-style rules, DO-178C or ISO 26262 qualification)'
          ]),

          areaBlock('SE', 'security', 'Cybersecurity', { q: 'A3', has: 'security' }, [
            'A vetted, constant-time cryptography library',
            'Sockets, packet capture and raw network access',
            'Binary parsing, disassembly and reverse-engineering helpers',
            'Coverage-guided fuzzing support and sanitizers',
            'Memory-safety guarantees that remove whole bug classes',
            'A secure-by-default standard library',
            'Reproducible builds, SBOMs and signing',
            'Sandboxing and capability-style permissions',
            'Tooling for authorized penetration testing and exploit research',
            'Formal verification or audit-friendly semantics'
          ]),

          areaBlock('BC', 'blockchain', 'Blockchain and Web3', { q: 'A3', has: 'blockchain' }, [
            'Smart-contract targets (Solana, WebAssembly contracts, EVM interop)',
            'Wallet, signing and key-management libraries (ed25519, secp256k1)',
            'Client SDKs for chains (RPC and transactions)',
            'Fully deterministic execution with no undefined behaviour',
            'Hashing, Merkle trees and zero-knowledge proof libraries',
            'Validator-grade performance and peer-to-peer networking',
            'Formal verification of contracts',
            'A local test validator, deployment and testing tooling',
            'Binary serialization (Borsh, protobuf, ABI encoding)',
            'Cross-chain and bridge interoperability'
          ])
        )
      },

      /* ------------------------------------------------------------------ */
      {
        id: 'shared', title: 'Your view of Dhar', reportTitle: 'SENTIMENT AND PRIORITIES',
        intro: 'For everyone.',
        questions: [
          { code: 'X1', type: 'likert', required: true,
            text: 'Overall, how do you feel about a new systems programming language being built independently out of Nigeria and Africa?',
            labels: { 1: 'Very negative', 3: 'Neutral', 5: 'Very positive' } },
          { code: 'X2', type: 'likert', required: true,
            text: 'How important do you think it is for Africa to have its own independently built systems-level language and toolchain, rather than relying entirely on foreign-built ones?',
            labels: { 1: 'Not important', 5: 'Very important' } },
          { code: 'X3', type: 'scale', required: true, from: 0, to: 10,
            text: 'On a scale of 0 to 10, how likely are you to try Dhar once a working, installable compiler is available?',
            labels: { from: 'Not at all likely', to: 'Extremely likely' } },
          { code: 'X4', type: 'textarea',
            text: 'What would most increase that likelihood?' },
          { code: 'X5', type: 'checkbox', required: true, max: 3,
            text: 'Of the areas Dhar aims to serve, which two or three matter most to you personally?',
            hint: 'Choose up to 3.',
            options: AREAS },
          { code: 'X6', type: 'textarea',
            text: 'What has caused you to abandon or avoid adopting a new programming language in the past, even one you were initially curious about?' },
          { code: 'X7', type: 'textarea',
            text: 'Is there a feature, capability or design idea, not covered anywhere above, that you think Dhar should have?' }
        ]
      },

      /* ------------------------------------------------------------------ */
      {
        id: 'closing', title: 'Stay in touch', reportTitle: 'CONTACT',
        intro: '',
        questions: [
          { code: 'C1', type: 'radio', required: true,
            text: 'Would you like to stay informed as Dhar develops: early access, updates and ways to contribute?',
            options: [{ id: 'yes', label: 'Yes, here is how to reach me' }, { id: 'no', label: 'Not right now' }] },
          { code: 'C2', type: 'text', required: true, showIf: { q: 'C1', is: 'yes' }, autocomplete: 'email', replyTo: true,
            text: 'What email address or other contact should we use?',
            placeholder: 'An email address or WhatsApp number' }
        ]
      }
    ]
  };

  /* The role question is the only question of the first step. */
  SURVEY.sections[0].questions = [SURVEY.roleQuestion];

  global.DHAR_SURVEY = SURVEY;
})(window);
