# Copyright and License

Automatically adds a copyright header to all source files in the repository based on the selected open-source license.

## Branding

| Attribute | Value  |
| --------- | ------ |
| Color     | yellow |
| Icon      | lock   |

## Inputs

| Name              | Description                                                  | Default | Required | Deprecation |
| ----------------- | ------------------------------------------------------------ | ------- | -------- | ----------- |
| name              | Name of the copyright holder                                 | -       | ✅ Yes    | -           |
| license           | License type (apache-2.0, mit, gpl-3.0, bsd-3-clause, other) | -       | ✅ Yes    | -           |
| working-directory | Directory to scan for source files                           | .       | ❌ No     | -           |

## Outputs

This action does not define any outputs.

## Environment Variables

This action does not require any environment variables.

## Dependencies

This section provides a graph of dependencies relevant to this action.

    dependencies:
    - GitHub Actions Runner
    - Specific environment variables
    - Required files and configurations

## Runs

**Execution Type:** composite

This is a composite action composed of multiple steps.

- - **Step ID:** ensure-executable
  - **Run Command:** chmod +x "${{ github.action_path }}/scripts/copyright.sh"
  - **Shell:** bash
- - **Step ID:** execute-update
  - **Run Command:** "${{ github.action_path }}/scripts/copyright.sh" \
"${{ inputs.working-directory }}" \
"${{ inputs.license }}" \
"${{ inputs.name }}"

  - **Shell:** bash

## Example Usage

    jobs:
      example:
        runs-on: ubuntu-latest
        steps:
          - uses: actions/checkout@v2
          - name: Run Copyright and License
            uses: ./
            with:
              name: <value>
              license: <value>
              working-directory: <value>

## Acknowledgments

This project leverages Markdown generation techniques from [coderrob.com](https://coderrob.com), developed by **Robert Lindley**.