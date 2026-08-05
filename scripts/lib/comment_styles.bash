#!/usr/bin/env bash

# load_comment_styles: Loads the extension manifest into an associative array.
# Arguments: manifest_path, destination_array_name
load_comment_styles() {
  local manifest_path="$1"
  local -n destination="$2"
  local extension style
  while IFS=$'\t' read -r extension style; do
    [[ -z "$extension" || "$extension" == \#* ]] && continue
    # shellcheck disable=SC2034 # The caller consumes the nameref destination.
    destination["$extension"]="$style"
  done < "$manifest_path"
}

# comment_style_for: Prints the configured comment style for an extension.
# Arguments: extension, associative_array_name
comment_style_for() {
  local extension="$1"
  local -n styles="$2"
  printf '%s' "${styles[$extension]:-}"
}
