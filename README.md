<p align="center">
  <img
    src="public/img/add-copyright-small-logo.png"
    alt="Barrel Roll logo"
  />
</p>

# Copyright and License

[![GitHub Actions](https://img.shields.io/badge/GitHub%20Actions-2088FF?style=for-the-badge&logo=github-actions&logoColor=white)](https://github.com/features/actions)

[![Coverage](https://img.shields.io/badge/coverage-100%25-brightgreen.svg)](https://github.com/Coderrob/add-copyright)
[![License: Apache-2.0](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](https://opensource.org/licenses/Apache-2.0)
[![SPDX](https://img.shields.io/badge/SPDX--License--List-3.20-blue.svg)](https://spdx.org/licenses/)

A GitHub Action that automatically adds copyright headers and full license texts to source files based on SPDX license identifiers. Supports 700+ current open-source licenses with automatic monthly updates from the official SPDX License List Data repository. Ensures compliance and consistency across your codebase.

## ✨ Features

- **700+ Licenses**: Support for all current SPDX license identifiers
- **Multi-Language**: Handles 15+ programming languages with appropriate comment styles
- **Smart Detection**: Skips files that already have current copyright notices
- **Git Integration**: Respects `.gitignore` and common config file exclusions
- **Auto-Updates**: Monthly license database updates from SPDX
- **Flexible**: Works with any directory structure and file types

## 📋 Table of Contents

- [Quick Start](#-quick-start)
- [Inputs](#-inputs)
- [Outputs](#-outputs)
- [Supported Languages](#-supported-languages)
- [Examples](#-examples)
- [License Updates](#-license-updates)
- [Local Development](#-local-development)
- [Contributing](#-contributing)
- [Troubleshooting](#-troubleshooting)
- [License](#-license)
- [Changelog](CHANGELOG.md)

## 🚀 Quick Start

```yaml
jobs:
  add-copyright:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Add Copyright Headers
        uses: Coderrob/add-copyright@v1
        with:
          name: "Your Company Name"
          license: "MIT"
          working-directory: "src"
```

## 📝 Inputs

| Name                | Description                                                                   | Required | Default | Example        |
| ------------------- | ----------------------------------------------------------------------------- | -------- | ------- | -------------- |
| `name`              | Name of the copyright holder                                                  | ✅ Yes   | -       | `"Acme Corp"`  |
| `license`           | SPDX license identifier (see [SPDX License List](https://spdx.org/licenses/)) | ✅ Yes   | -       | `"Apache-2.0"` |
| `working-directory` | Directory to scan for source files                                            | ❌ No    | `.`     | `"src"`        |

## 📤 Outputs

This action does not define any outputs.

## 💻 Supported Languages

The action automatically detects file types and applies appropriate comment styles:

| Language   | Extensions                 | Comment Style |
| ---------- | -------------------------- | ------------- |
| Shell/Bash | `.sh`, `.bash`             | `#`           |
| Python     | `.py`                      | `#`           |
| JavaScript | `.js`                      | `/* */`       |
| TypeScript | `.ts`                      | `/* */`       |
| Java       | `.java`                    | `/* */`       |
| C/C++      | `.c`, `.cpp`, `.h`, `.hpp` | `/* */`       |
| C#         | `.cs`                      | `/* */`       |
| Go         | `.go`                      | `//`          |
| Swift      | `.swift`                   | `//`          |
| PHP        | `.php`                     | `/* */`       |
| Ruby       | `.rb`                      | `#`           |
| YAML       | `.yml`, `.yaml`            | `#`           |

## 📚 Examples

### Basic Usage

```yaml
- name: Add MIT License Headers
  uses: Coderrob/add-copyright@v1
  with:
    name: "John Doe"
    license: "MIT"
```

### Company-wide License Application

```yaml
- name: Add Apache 2.0 License to All Source Files
  uses: Coderrob/add-copyright@v1
  with:
    name: "Acme Corporation"
    license: "Apache-2.0"
    working-directory: "."
```

### Multiple Directories

```yaml
- name: Add License to Frontend Code
  uses: Coderrob/add-copyright@v1
  with:
    name: "My Project"
    license: "GPL-3.0-only"
    working-directory: "frontend"

- name: Add License to Backend Code
  uses: Coderrob/add-copyright@v1
  with:
    name: "My Project"
    license: "GPL-3.0-only"
    working-directory: "backend"
```

### Using with Matrix Strategy

```yaml
jobs:
  license:
    runs-on: ubuntu-latest
    strategy:
      matrix:
        include:
          - dir: "src"
            license: "MIT"
          - dir: "tests"
            license: "MIT"
    steps:
      - uses: actions/checkout@v4
      - name: Add Copyright
        uses: Coderrob/add-copyright@v1
        with:
          name: "My Organization"
          license: ${{ matrix.license }}
          working-directory: ${{ matrix.dir }}
```

## 🔄 License Updates

This action automatically keeps its license database up-to-date by fetching the latest license texts from the [SPDX License List Data](https://github.com/spdx/license-list-data) repository. The update process runs monthly via a scheduled GitHub workflow.

### Manual License Update

To manually trigger a license update:

1. Go to the Actions tab in your repository
2. Select "Update Licenses" workflow
3. Click "Run workflow"

Or execute the update script locally:

```bash
./scripts/update_licenses.sh
```

## 🛠️ Local Development

### Prerequisites

- Bash shell
- Git
- jq (JSON processor)
- Standard Unix tools (sed, awk, find)

### Running Locally

```bash
# Clone the repository
git clone https://github.com/Coderrob/add-copyright.git
cd add-copyright

# Update license database
./scripts/update_licenses.sh

# Add copyright to files
./scripts/copyright.sh /path/to/your/project MIT "Your Name"
```

### Available Scripts

This project includes several utility scripts:

#### `scripts/copyright.sh`

The main script that adds copyright headers to source files.

```bash
./scripts/copyright.sh <directory> <license-type> <copyright-title>
```

**Arguments:**

- `directory`: Directory to scan for source files
- `license-type`: SPDX license identifier (e.g., MIT, Apache-2.0)
- `copyright-title`: Name of the copyright holder

#### `scripts/update_licenses.sh`

Updates the local license database from the SPDX License List Data repository.

```bash
./scripts/update_licenses.sh
```

#### `scripts/release.sh`

Manages the release process, including creating semantic version tags and release branches.

```bash
./scripts/release.sh
```

### Testing

```bash
# Run the test suite
./scripts/run_tests.sh

# Test specific functionality
./__tests__/test_copyright.sh
```

## 🤝 Contributing

We welcome contributions! Please see our [Contributing Guide](CONTRIBUTING.md) for details.

### Development Setup

1. Fork the repository
2. Clone your fork: `git clone https://github.com/your-username/add-copyright.git`
3. Make your changes
4. Run tests: `./scripts/run_tests.sh`
5. Submit a pull request

### Adding Support for New Languages

To add support for a new programming language:

1. Add the file extension and comment style to `COMMENT_STYLES` array in `scripts/copyright.sh`
2. Test with sample files
3. Update this README with the new language

## 🔧 Troubleshooting

### Common Issues

#### "jq command not found"

```bash
# Install jq
# macOS
brew install jq
# Ubuntu/Debian
sudo apt-get install jq
# CentOS/RHEL
sudo yum install jq
```

#### "License file not found"

- Ensure the license identifier is a valid SPDX identifier
- Check the [SPDX License List](https://spdx.org/licenses/) for valid identifiers
- The license database is updated monthly; try running the update script

#### "Permission denied"

```bash
# Make scripts executable
chmod +x scripts/*.sh
```

#### "Files not being processed"

- Check if files are in `.gitignore`
- Verify file extensions are supported
- Ensure files don't already contain current copyright notices

### Debug Mode

Enable debug logging by setting the `DEBUG` environment variable:

```bash
DEBUG=1 ./scripts/copyright.sh /path/to/project MIT "Your Name"
```

## 🙏 Acknowledgments

- [SPDX License List Data](https://github.com/spdx/license-list-data) for license information
- [GitHub Actions](https://github.com/features/actions) for the CI/CD platform
- Community contributors for their valuable input

---

## License

This project is licensed under the Apache 2.0 License - see the [LICENSE](LICENSE) file for details.

## Ownership

This repository is maintained by **Rob "Coderrob" Lindley**. For inquiries, please contact via GitHub.
