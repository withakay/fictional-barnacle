# GitHub Version Action

A flexible GitHub Action for generating version strings with support for both Calendar Versioning (CalVer) and Semantic Versioning (SemVer), with intelligent metadata extraction from PR titles and commit messages.

## Overview

This action automatically generates version numbers based on git history and PR information. It supports:

- **Dual Versioning Systems**: Choose between Calendar Versioning or Semantic Versioning
- **Smart Increment Logic**: Automatically determines version increments based on commit message prefixes
- **Metadata Extraction**: Extracts normalized JIRA tickets and conventional commit prefixes from PR titles
- **Flexible Configuration**: Customize version formats with suffixes and metadata

## Version Format

The generated version follows this format:

```text
Major.Minor.Patch[-Suffix][-Metadata]
```

Where metadata (when enabled) follows the pattern:

```text
[jira/prefix]-pr[number].[run_number]-[commit_hash]
```

For example: `1.2.3-beta-mk123-pr456.42-abc123`

### JIRA Ticket Normalization

JIRA tickets are automatically normalized by:

- Converting to lowercase
- Removing hyphens and spaces between prefix and number

Examples:

- `MK-123` → `mk123`
- `ABC 456` → `abc456`

## Usage

### Basic Usage

```yaml
- name: Generate Version
  id: version
  uses: withakay/fictional-barnacle/.github/actions/version-generator@main
  with:
    add-meta: true

- name: Use Version
  run: echo "Building version ${{ steps.version.outputs.version }}"
```

### With Version Suffix

```yaml
- name: Generate Beta Version
  id: version
  uses: withakay/fictional-barnacle/.github/actions/version-generator@main
  with:
    version-suffix: "beta"
    add-meta: true
```

### Using Calendar Versioning

```yaml
- name: Generate CalVer Version
  id: version
  uses: withakay/fictional-barnacle/.github/actions/version-generator@main
  with:
    use-calver: true
    add-meta: true
```

## Configuration Options

| Input | Description | Default |
|-------|-------------|--------|
| `version-number` | Direct version override | `""` |
| `version-suffix` | Version suffix (e.g., alpha, beta, rc1) | `""` |
| `add-meta` | Add metadata to version | `false` |
| `jira-prefix` | JIRA project prefix | `MK` |
| `alternate-pr-prefixes` | Comma-separated list of PR prefixes | `fix,hotfix,chore,feat,refactor,docs,style,ci` |
| `use-calver` | Use Calendar Versioning | `false` |
| `semver-major` | Initial major version for SemVer | `1` |

## Testing

The action includes a comprehensive test suite:

```bash
cd .github/actions/version-generator
./test-generate-version.sh
```

For Docker-based testing (to ensure consistent behavior across environments):

```bash
cd .github/actions/version-generator
./run-tests-in-docker.sh
```

## License

MIT
