# School Closures and Housing Prices

This project studies how the 2013 Chicago public-school closures affected nearby home prices, housing-market activity, and neighborhood change.

The starting identification strategy compares schools that appeared on CPS's February 2013 closure list and ultimately closed with schools on the same list that remained open. That comparison keeps the treated and primary comparison schools inside a common administrative selection screen. The first empirical design should distinguish the candidate-list announcement, the final closure decision, the end-of-year closure, and later site reuse or vacancy.

## Repository structure

- `data_raw/` holds immutable source data. Its contents are ignored by Git.
- `lit_review/` contains the papers, searchable PDF extracts, bibliography, and map assembled for the project.
- `tasks/` contains reproducible units of work. Each analysis task owns `input/`, `code/`, and `output/` directories.
- `tasks/_lib/` is reserved for code genuinely reused across tasks.
- `tasks/audits/` keeps diagnostics and robustness work separate from the production pipeline.
- `paper/` is the final build target.

## Running the project

From the repository root:

```sh
make setup
make
```

`make setup` checks the command-line tools required by the current repository. `make` runs that check and builds `paper/paper.pdf`.

Run an individual task from its `code/` directory. For example:

```sh
cd tasks/setup_environment/code
make
```

Makefiles are the dependency graph. Inputs passed between tasks should be relative symlinks created by explicit Make rules; scripts should read fixed task-local paths and write fixed task-local outputs.

## Current status

The literature base and a compileable paper entry point are in place. No analysis tasks have been invented before the source data are chosen. The first production task should be added when the raw Chicago school-list and closure records are obtained, followed by the housing-transactions source actually selected for the study.
