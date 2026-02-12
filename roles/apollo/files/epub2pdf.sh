#!/bin/env bash

/opt/calibre/ebook-convert "${1}" "${2}" --output-profile=tablet --pretty-print --pdf-page-numbers --linearize-tables
