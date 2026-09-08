# Project instructions

## Objective

This repository studies the effects of Chicago's 2013 neighborhood-school closures on housing prices, market activity, and neighborhood change. The preferred starting comparison is between schools on the February 2013 closure list that closed and schools on that list that remained open. Schools never listed are secondary comparisons or diagnostics, not the default counterfactual.

Clarity and traceability are part of correctness. A result should be easy to locate, reproduce, and connect to its raw inputs.

## Repository graph

- `data_raw/`: immutable source files; never edit these in place.
- `lit_review/`: source papers, searchable reading copies, bibliography, and the closure-list map.
- `tasks/<task>/input/`: symlinks to raw data or upstream task outputs.
- `tasks/<task>/code/`: the task Makefile and the shortest clear scripts needed for the task.
- `tasks/<task>/output/`: the task's owned products.
- `tasks/shared/code/`: helpers used by more than one production task.
- `tasks/audits/`: diagnostics, validation, and robustness work that should not enter the production graph by accident.
- `paper/`: the final paper and the root build target.

The Make graph is the source of truth. Do not create a second orchestration layer or a task-graph artifact until the real dependency graph is large enough to need one.

## Task design

Every production task must have `input/`, `code/`, and `output/` directories. Empty generated directories do not need to be tracked.

Each task must:

1. declare concrete file dependencies in `code/Makefile`;
2. create input symlinks through explicit Make rules;
3. read fixed paths below `../input/`;
4. write fixed paths below `../output/`;
5. expose analytical choices as command-line arguments only when they are genuinely varied; and
6. include `../../shared/code/shell_functions.make` first and `../../shared/code/generic.make` last.

Run tasks from their `code/` directories. Use relative paths in Makefiles and scripts so the repository can move without edits.

Do not add wrapper runners, stamp files, generic smoke targets, or speculative pipeline stages. Do not put audit-only files in production output directories. A helper belongs in `tasks/shared/code/` only after at least two production tasks use it.

## Makefiles

- Keep Makefiles short and declarative.
- Use direct paths in targets and prerequisites.
- Let Make own directory creation and cross-task execution.
- Use order-only prerequisites for directories.
- Add a `link-inputs` target when a task has upstream inputs.
- Preserve incrementality: a second `make` should do no substantive work.
- Do not hide missing inputs behind fallbacks or silently skip work because an output happens to exist.
- Avoid a `clean` target unless it has a narrow, recoverable purpose.
- Never use `test -s` or existence-only recipes as substitutes for output producers. Every output must have a rule that can recreate it. For scripts producing several files under GNU Make 3.81, list those files in one producer rule and use `.NOTPARALLEL:` in that task to prevent duplicate simultaneous runs.

A normal task Makefile should look like this:

```make
include ../../shared/code/shell_functions.make

all: ../output/result.parquet

../output/result.parquet: build_result.R ../input/source.parquet Makefile | ../output
	$(RSCRIPT) $<

../input/source.parquet: ../../upstream_task/output/source.parquet | ../input
	@test "$$(readlink "$@" 2>/dev/null)" = "$<" || ln -sf "$<" "$@"

link-inputs: ../input/source.parquet

include ../../shared/code/generic.make
```

## Code style

Prefer linear, top-to-bottom scripts. A reader should be able to follow input, cleaning, analysis, checks, and output in execution order.

- Use descriptive object names and literal paths at call sites.
- Keep transformations close to the analysis they support.
- Avoid classes, configuration frameworks, registries, and helpers used only once.
- Delete dead code rather than commenting it out.
- Fail loudly on missing columns, unmatched identifiers, duplicated keys, invalid geometries, or implausible coverage.
- Do not use `log1p()` or inverse-hyperbolic-sine transforms as substitutes for an explicit economic definition.
- Keep comments focused on economic meaning, identification, non-obvious data choices, and assumptions.

## Data and joins

State the unit of observation and intended key before each material merge. Validate key uniqueness on the side that is supposed to be unique, use the narrowest justified join, and report or assert match coverage. Do not allow an accidental many-to-many join.

Raw data remain immutable. Derived data belong to exactly one task. If a manual coding or crosswalk decision affects production results, store the decision in a documented, auditable file rather than burying it in code.

## Spatial work

Chicago point data generally arrive in longitude and latitude. Assign EPSG:4326 immediately, then transform to Illinois StatePlane East, EPSG:3435, before distances, buffers, areas, or spatial joins. Record units explicitly and validate geometries before analysis.

## Empirical work

Keep the primary treatment definition tied to the closure-list design. Preserve separately the candidate-list date, final vote, end-of-year closure, building vacancy, demolition, reuse, and welcoming-school assignment. Site disposition is a post-treatment mechanism unless the design explicitly says otherwise.

For housing outcomes, inspect both prices conditional on sale and market activity using an appropriate denominator. Plot pre-trends, make overlapping exposure explicit, and keep never-listed schools as a secondary comparison or diagnostic unless a different design is justified.

## Verification

Before handing off a change:

1. run the changed task or target;
2. run it a second time to verify incrementality;
3. inspect produced files rather than relying only on exit status;
4. run `git diff --check` and inspect `git status`; and
5. confirm that generated inputs, outputs, logs, caches, and paper build files remain ignored.
