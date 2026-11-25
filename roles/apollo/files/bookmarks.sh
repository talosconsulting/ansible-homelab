#!/usr/bin/env bash

set -euo pipefail

CHROME_DIR="${HOME}/.config/google-chrome"
CONFIG_FILE="${HOME}/.config/bookmarks.conf"

if [[ ! -r "${CONFIG_FILE}" ]]; then
  cat >&2 <<EOF
Missing ${CONFIG_FILE}. Create it with:
  PERSONAL_EMAIL="you@example.com"
  BUSINESS_EMAIL="you@company.com"
EOF
  exit 1
fi

# shellcheck source=/dev/null
source "${CONFIG_FILE}"

: "${PERSONAL_EMAIL:?PERSONAL_EMAIL must be set in ${CONFIG_FILE}}"
: "${BUSINESS_EMAIL:?BUSINESS_EMAIL must be set in ${CONFIG_FILE}}"

WORKDIR=$(mktemp -d)
trap 'rm -rf "${WORKDIR}"' EXIT

# Profile directory names differ between installs (e.g. "Profile 1" vs "Profile 2"),
# so resolve them by the signed-in account. Newer Chrome installs keep synced
# bookmarks in AccountBookmarks rather than Bookmarks.
bookmarks_file() {
  local profile file candidate
  profile=$(jq -r --arg email "$1" 'first(.profile.info_cache // {} | to_entries[] | select(.value.user_name == $email) | .key) // empty' "${CHROME_DIR}/Local State")
  if [[ -z "${profile}" ]]; then
    echo "No Chrome profile found for $1" >&2
    return 1
  fi
  for file in AccountBookmarks Bookmarks; do
    candidate="${CHROME_DIR}/${profile}/${file}"
    if [[ -s "${candidate}" ]] &&
      jq -e '[.roots // {} | .[]? | objects | .children // [] | length] | add > 0' "${candidate}" >/dev/null 2>&1; then
      echo "${candidate}"
      return 0
    fi
  done
  echo "No populated bookmarks file found in ${CHROME_DIR}/${profile}" >&2
  return 1
}

json_to_html() {
  python3 -c '
import html
import json
import sys

EPOCH_DIFF = 11644473600

def to_unix(ts):
    try:
        v = int(ts) // 1_000_000 - EPOCH_DIFF
        return str(v) if v > 0 else "0"
    except (TypeError, ValueError):
        return "0"

def write_nodes(nodes, indent):
    pad = "    " * indent
    for node in nodes or []:
        node_type = node.get("type")
        name = html.escape(node.get("name") or "", quote=False)
        if node_type == "url":
            url = html.escape(node.get("url") or "", quote=True)
            added = to_unix(node.get("date_added"))
            print(f"{pad}<DT><A HREF=\"{url}\" ADD_DATE=\"{added}\">{name}</A>")
        elif node_type == "folder":
            added = to_unix(node.get("date_added"))
            modified = to_unix(node.get("date_modified"))
            print(f"{pad}<DT><H3 ADD_DATE=\"{added}\" LAST_MODIFIED=\"{modified}\">{name}</H3>")
            print(f"{pad}<DL><p>")
            write_nodes(node.get("children"), indent + 1)
            print(f"{pad}</DL><p>")

data = json.load(sys.stdin)
roots = data.get("roots") or {}
bar = roots.get("bookmark_bar") or {}

print("<!DOCTYPE NETSCAPE-Bookmark-file-1>")
print("<!-- This is an automatically generated file.")
print("     It will be read and overwritten.")
print("     DO NOT EDIT! -->")
print("<META HTTP-EQUIV=\"Content-Type\" CONTENT=\"text/html; charset=UTF-8\">")
print("<TITLE>Bookmarks</TITLE>")
print("<H1>Bookmarks</H1>")
print("<DL><p>")
if bar:
    bar_name = html.escape(bar.get("name") or "Bookmarks bar", quote=False)
    bar_added = to_unix(bar.get("date_added"))
    bar_modified = to_unix(bar.get("date_modified"))
    print(f"    <DT><H3 ADD_DATE=\"{bar_added}\" LAST_MODIFIED=\"{bar_modified}\" PERSONAL_TOOLBAR_FOLDER=\"true\">{bar_name}</H3>")
    print("    <DL><p>")
    write_nodes(bar.get("children"), 2)
    print("    </DL><p>")
write_nodes((roots.get("other") or {}).get("children"), 1)
write_nodes((roots.get("synced") or {}).get("children"), 1)
print("</DL><p>")
'
}

PERSONAL_BOOKMARKS=$(bookmarks_file "${PERSONAL_EMAIL}")
BUSINESS_BOOKMARKS=$(bookmarks_file "${BUSINESS_EMAIL}")

STRIP_FOLDERS='def strip_folders:
  walk(
    if type == "object" and (.children | type) == "array" then
      .children |= map(select(
        .type != "folder"
        or ((.name // "") | . != "Health" and . != "Homelab" and (startswith("Updates (") | not))
      ))
    else . end
  );'

# Everything to the right of this bookmark on the bookmark bar is excluded.
LAST_BOOKMARK_URL='https://www.youtube.com/@NASCAR/videos'

# shellcheck disable=SC2016  # $last and $last_url are jq variables
TRIM_BOOKMARK_BAR='def trim_bookmark_bar:
  .roots.bookmark_bar.children |= (
    (map(.url) | index($last_url)) as $last
    | if $last == null then error("\($last_url) not found on the bookmark bar")
      else .[:($last + 1)] end
  );'

PERSONAL_SOURCE_FILE="${WORKDIR}/personal.json"
PERSONAL_HTML_FILE="${WORKDIR}/personal.html"
BUSINESS_SOURCE_FILE="${WORKDIR}/business.json"
BUSINESS_HTML_FILE="${WORKDIR}/business.html"

cp "${PERSONAL_BOOKMARKS}" "${PERSONAL_SOURCE_FILE}"
jq --arg last_url "${LAST_BOOKMARK_URL}" \
  "${STRIP_FOLDERS} ${TRIM_BOOKMARK_BAR} trim_bookmark_bar | del(.roots.synced.children,.sync_metadata) | strip_folders" \
  "${PERSONAL_SOURCE_FILE}" | json_to_html > "${PERSONAL_HTML_FILE}"
ssh zeus "rclone rcat onedrive:/bookmarks/personal/bookmarks.html" < "${PERSONAL_HTML_FILE}"

cp "${BUSINESS_BOOKMARKS}" "${BUSINESS_SOURCE_FILE}"
jq 'del(.roots.bookmark_bar.children[0],.sync_metadata)' \
  "${BUSINESS_SOURCE_FILE}" | json_to_html > "${BUSINESS_HTML_FILE}"
ssh zeus "rclone rcat onedrive:/bookmarks/business/bookmarks.html" < "${BUSINESS_HTML_FILE}"
