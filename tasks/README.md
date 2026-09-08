# Tasks

Each production task is a self-contained unit of work with:

```text
tasks/<task>/
├── input/    # generated symlinks to raw or upstream files
├── code/     # Makefile and linear analysis scripts
└── output/   # files owned by this task
```

Code, task documentation, manual decision tables, and shareable standard data reports in `report/` are tracked. Generated datasets and input symlinks remain ignored. A task README is useful when the task's unit of observation, identifying choices, outputs, or runtime are not obvious from its Makefile.

Run a task from its `code/` directory. Declare upstream files directly, create relative input symlinks in Make, and include `../../shared/code/shell_functions.make` first and `../../shared/code/generic.make` last. Shared rules check upstream tasks for stale outputs. Put diagnostic-only work below `tasks/audits/`.
