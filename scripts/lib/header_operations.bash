#!/usr/bin/env bash

readonly MANAGED_HEADER_BEGIN='add-copyright: begin'
readonly MANAGED_HEADER_END='add-copyright: end'

# preamble_line_count: Counts interpreter and Python encoding preamble lines.
# Arguments: file_path
preamble_line_count() {
  local file="$1" first second extension count=0
  IFS= read -r first < "$file" || true
  second="$(sed -n '2p' "$file")"
  extension="${file##*.}"
  [[ "$first" == '#!'* ]] && count=1
  if [[ "$extension" == "py" ]]; then
    [[ "$first" =~ coding[:=] ]] && count=1
    [[ $count -eq 1 && "$second" =~ coding[:=] ]] && count=2
  fi
  printf '%s' "$count"
}

# read_managed_header: Prints the action-owned header region near the preamble.
# Arguments: file_path, preamble_line_count
read_managed_header() {
  awk -v start="$(( $2 + 1 ))" -v begin="$MANAGED_HEADER_BEGIN" -v end="$MANAGED_HEADER_END" '
    NR < start { next }
    !active && index($0, begin) { active=1 }
    active { print }
    active && index($0, end) { exit }
    !active && NR > start + 1 { exit }
  ' "$1"
}

# managed_header_matches: Checks requested identity only inside an owned header.
# Arguments: file_path, license_type, year, copyright_title
managed_header_matches() {
  local file="$1" license="$2" year="$3" title="$4" header
  header="$(read_managed_header "$file" "$(preamble_line_count "$file")")"
  [[ -n "$header" ]] || return 1
  grep -Fiq "SPDX-License-Identifier: $license" <<< "$header" || return 1
  grep -Fiq "Copyright $year $title" <<< "$header" \
    || grep -Fiq "Copyright (c) $year $title" <<< "$header"
}

# write_source_body: Writes source content without an action-owned header.
# Arguments: file_path, preamble_line_count
write_source_body() {
  awk -v start="$(( $2 + 1 ))" -v begin="$MANAGED_HEADER_BEGIN" -v end="$MANAGED_HEADER_END" '
    NR < start { next }
    NR == start && $0 == "/*" { opening=$0; mode="block-check"; next }
    mode == "block-check" && index($0, begin) { mode="managed-block"; next }
    mode == "block-check" { print opening; mode=""; print; next }
    NR == start && index($0, begin) { mode="managed-line"; next }
    mode == "managed-line" && index($0, end) { mode="after"; next }
    mode == "managed-block" && index($0, end) { mode="block-end"; next }
    mode == "managed-line" || mode == "managed-block" { next }
    mode == "block-end" && /^ \*\/$/ { mode="after"; next }
    mode == "after" && /^$/ { mode=""; next }
    { mode=""; print }
  ' "$1"
}

# write_licensed_content: Writes preserved preamble, notice, and source body.
# Arguments: license_notice, file_path, preamble_line_count
write_licensed_content() {
  local notice="$1" file="$2" preamble_lines="$3"
  [[ "$preamble_lines" -gt 0 ]] && head -n "$preamble_lines" "$file"
  printf '%s\n\n' "$notice"
  write_source_body "$file" "$preamble_lines"
}
