#!/usr/bin/env bash
set -euo pipefail

output="../output/system_requirements.txt"
temporary_output="${output}.tmp"

required_commands=(
  git
  make
  Rscript
  python3
  pdflatex
  bibtex
)

missing_commands=()

{
  printf "command\tpath\tversion\n"
  for command_name in "${required_commands[@]}"; do
    if command_path="$(command -v "${command_name}" 2>/dev/null)"; then
      command_version="$(${command_name} --version 2>&1 | head -n 1 || true)"
      printf "%s\t%s\t%s\n" "${command_name}" "${command_path}" "${command_version}"
    else
      printf "%s\tMISSING\tMISSING\n" "${command_name}"
      missing_commands+=("${command_name}")
    fi
  done
} > "${temporary_output}"

mv "${temporary_output}" "${output}"

if ((${#missing_commands[@]} > 0)); then
  printf "Missing required command-line tools: %s\n" "${missing_commands[*]}" >&2
  printf "See %s for the full check.\n" "${output}" >&2
  exit 1
fi

printf "Wrote system requirements check to %s\n" "${output}"
