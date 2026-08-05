# Checks function documentation, physical size, and cyclomatic complexity.

function report(message) {
  print FILENAME ":" function_start ": " message > "/dev/stderr"
  failures++
}

function finish_function(physical_lines) {
  physical_lines = FNR - function_start + 1
  if (physical_lines > 25) {
    report(function_name " has " physical_lines " lines; maximum is 25")
  }
  if (complexity >= 4) {
    report(function_name " has cyclomatic complexity " complexity "; maximum is 3")
  }
  in_function = 0
  case_depth = 0
}

FNR == 1 {
  previous_line = ""
  in_function = 0
  delete documentation_line
}

$0 ~ /^#[[:space:]]*[a-zA-Z_][a-zA-Z0-9_]*:[[:space:]]/ {
  documented_name = $0
  sub(/^#[[:space:]]*/, "", documented_name)
  sub(/:.*/, "", documented_name)
  documentation_line[documented_name] = FNR
}

!in_function && $0 ~ /^[a-zA-Z_][a-zA-Z0-9_]*\(\)[[:space:]]*\{/ {
  function_name = $0
  sub(/\(\).*/, "", function_name)
  function_start = FNR
  complexity = 1
  if (!(function_name in documentation_line) || FNR - documentation_line[function_name] > 4) {
    report(function_name " lacks an adjacent function-level documentation comment")
  }
  in_function = 1
  if ($0 ~ /\{[^{}]*\}[[:space:]]*$/) {
    finish_function()
  }
}

in_function {
  if ($0 ~ /^[[:space:]]*(if|elif|for|while|until|select)[[:space:]]/) {
    complexity++
  }
  if ($0 ~ /^[[:space:]]*case[[:space:]]/) {
    case_depth++
  }
  if (case_depth > 0 && $0 ~ /^[[:space:]]*[^[:space:]#*][^)]*\)[[:space:]]/) {
    complexity++
  }
  if ($0 ~ /^[[:space:]]*esac([[:space:]]|$)/) {
    case_depth--
  }
  if ($0 ~ /^}[[:space:]]*$/) {
    finish_function()
  }
}

{ previous_line = $0 }

END { exit failures > 0 }
