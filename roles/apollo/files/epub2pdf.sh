#!/usr/bin/env bash
set -euo pipefail

/opt/calibre/ebook-convert "${1}" "${2}" --output-profile=tablet --pretty-print --pdf-page-numbers --linearize-tables
