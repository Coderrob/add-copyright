#!/bin/bash

# Copyright (c) 2025 Robert Lindley
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

set -e # Ensure strict error handling

# Directory containing license text files
LICENSES_DIR="licenses"

# Get the current year dynamically
CURRENT_YEAR=$(date +"%Y")

# Define supported file extensions and their respective comment styles
declare -A COMMENT_STYLES=(
  ["sh"]="#"
  ["py"]="#"
  ["js"]="/*"
  ["ts"]="/*"
  ["java"]="/*"
  ["cpp"]="/*"
  ["hpp"]="/*"
  ["c"]="/*"
  ["h"]="/*"
  ["cs"]="/*"
  ["go"]="//"
  ["swift"]="//"
  ["php"]="/*"
  ["rb"]="#"
)

# Function: should_ignore_file
# Checks whether a file should be ignored based on Git's ignore rules and specific patterns.
should_ignore_file() {
  local file="$1"

  # Check if Git ignore rules apply
  git check-ignore -q "$file" && return 0

  # Ignore ESLint config files
  [[ "$file" == *".eslintrc"* || "$file" == "eslint.config."* ]] && return 0

  return 1
}

# Function: get_comment_style
# Determines the appropriate comment style based on the file extension.
get_comment_style() {
  local file="$1"
  local ext="${file##*.}"

  # Return the associated comment style or an empty string if not found
  echo "${COMMENT_STYLES[$ext]:-}"
}

# Function: get_license_text
# Retrieves and formats the license text by replacing the placeholder with the actual copyright notice.
get_license_text() {
  local license="$1"
  local title="$2"
  local license_file="$LICENSES_DIR/$license.txt"

  if [[ ! -f "$license_file" ]]; then
    echo "Error: License file '$license_file' not found." >&2
    exit 1
  fi

  # Replace the placeholder {{COPYRIGHT_NOTICE}} with the actual copyright statement
  sed "s/{{COPYRIGHT_NOTICE}}/Copyright (c) $CURRENT_YEAR $title/g" "$license_file"
}

# Function: format_license_notice
# Formats the license text using the appropriate comment style for the file type.
format_license_notice() {
  local license_text="$1"
  local style="$2"

  if [[ "$style" == "/*" ]]; then
    {
      echo "/*"
      echo "$license_text" | sed 's/^/ * /'
      echo " */"
      echo "" # Ensure a blank line after the license block
    }
  elif [[ "$style" == "//" ]]; then
    {
      echo "$license_text" | sed 's/^/\/\//'
      echo "" # Ensure a blank line after the license
    }
  else
    {
      echo "$license_text" | sed 's/^/'"$style"' /'
      echo "" # Ensure a blank line after the license
    }
  fi
}

# Function: prepend_license
# Adds the formatted license notice to the beginning of a file, ensuring it is not duplicated.
prepend_license() {
  local file="$1"
  local license="$2"
  local title="$3"

  # Determine the comment style for the given file type
  local comment_style
  comment_style=$(get_comment_style "$file")

  # Skip files without a recognized comment style
  [[ -z "$comment_style" ]] && return

  # Retrieve and format the license text
  local license_text
  license_text=$(get_license_text "$license" "$title")

  # Check if the file already contains the copyright notice
  grep -q "Copyright (c) $CURRENT_YEAR $title" "$file" && return

  # Format the license text with appropriate commenting
  local formatted_notice
  formatted_notice=$(format_license_notice "$license_text" "$comment_style")

  # Prepend the license notice to the file, ensuring a blank line after it
  {
    echo "$formatted_notice"
    echo "" # Extra newline before the file content
    cat "$file"
  } >temp_file && mv temp_file "$file"

  echo "Updated: $file"
}

# Function: scan_directory
# Recursively scans a directory and applies the license to applicable files.
scan_directory() {
  local dir="$1"
  local license="$2"
  local title="$3"

  find "$dir" -type f | while read -r file; do
    should_ignore_file "$file" || prepend_license "$file" "$license" "$title"
  done
}

# Ensure correct script usage
if [[ $# -ne 3 ]]; then
  echo "Usage: $0 <directory> <license-type> <copyright-title>"
  exit 1
fi

LICENSE_TYPE="$2"
COPYRIGHT_TITLE="$3"

echo "Processing with license: $LICENSE_TYPE, Title: $COPYRIGHT_TITLE..."
scan_directory "$1" "$LICENSE_TYPE" "$COPYRIGHT_TITLE"
echo "Processing complete."
