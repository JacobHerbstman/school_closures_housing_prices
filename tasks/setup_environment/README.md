# Setup environment

This task checks the command-line tools required by the current repository and
records their locations and versions in `output/system_requirements.txt`. It
also installs missing R packages from CRAN and records the installed versions
in `output/R_packages.txt`.

Install any missing system tools reported by the check, then run `make` from
this task's `code/` directory.
