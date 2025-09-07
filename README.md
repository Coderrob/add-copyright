# Copyright and License

A GitHub Action that automatically adds copyright headers and full license texts to source files based on SPDX license identifiers. Supports 700+ current open-source licenses with automatic monthly updates from the official SPDX License List Data repository. Ensures compliance and consistency across your codebase.

## Branding

| Attribute | Value  |
| --------- | ------ |
| Color     | yellow |
| Icon      | lock   |

## Inputs

| Name              | Description                                                                                   | Default | Required | Deprecation |
| ----------------- | --------------------------------------------------------------------------------------------- | ------- | -------- | ----------- |
| name              | Name of the copyright holder                                                                  | -       | ✅ Yes    | -           |
| license           | License type (any current SPDX license identifier, e.g., MIT, Apache-2.0, GPL-3.0-only, BSD-3-Clause) | -       | ✅ Yes    | -           |
| working-directory | Directory to scan for source files                                                            | .       | ❌ No     | -           |

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

## License Updates

This action automatically keeps its license database up-to-date by fetching the latest license texts from the [SPDX License List Data](https://github.com/spdx/license-list-data) repository. The update process runs monthly via a scheduled GitHub workflow, ensuring that all supported licenses are current and compliant with the latest SPDX standards.

To manually trigger a license update, you can run the workflow from the Actions tab or execute the update script locally:

    ./scripts/update_licenses.sh

## Supported Licenses

The action supports all current (non-deprecated) licenses from the SPDX License List, including but not limited to:

- MIT
- Apache-2.0
- GPL-3.0-only
- BSD-3-Clause
- And 750+ more current SPDX licenses

Deprecated licenses are automatically excluded from updates to ensure only active and recommended licenses are available.

For a complete list, see the [SPDX License List](https://spdx.org/licenses/).

## Acknowledgments

This project leverages Markdown generation techniques from [coderrob.com](https://coderrob.com), developed by **Robert Lindley**.
