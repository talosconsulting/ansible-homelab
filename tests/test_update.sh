#!/usr/bin/env bash
# Static tests for the playbooks and scripts: syntax-check + lint only.
#
# The playbooks perform real, largely irreversible actions (DNF/Windows/Homebrew
# upgrades, firmware flashing) against real inventory hosts, so they are never
# executed here — only parsed and linted.
set -euo pipefail
shopt -s nullglob

cd "$(dirname "${BASH_SOURCE[0]}")/.."

# Don't pollute ansible.log with syntax-check and lint runs.
export ANSIBLE_LOG_PATH=/dev/null

# ansible-playbook requires blocking stdio; piping through cat keeps that
# true even when this script itself runs under a non-blocking terminal.
for playbook in *.yaml; do
  echo "==> ansible-playbook --syntax-check $playbook"
  ansible-playbook "$playbook" --syntax-check 2>&1 | cat
done

# Lint all YAML files, including extensionless group_vars and host_vars.
echo "==> yamllint"
yamllint --strict . group_vars/* host_vars/* 2>&1 | cat

# With no paths, ansible-lint covers every playbook and role in the repo. --offline
# keeps it from reinstalling requirements.yml on every run.
echo "==> ansible-lint"
ansible-lint --offline --strict --profile=production 2>&1 | cat

echo "==> shellcheck"
grep -rlIE --exclude-dir=.git --exclude-dir=.ansible '^#!(/usr)?/bin/(env )?(ba)?sh' roles tests |
  xargs uvx --from shellcheck-py shellcheck 2>&1 | cat

echo "PASS"
