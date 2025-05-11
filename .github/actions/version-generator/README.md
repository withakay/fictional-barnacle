# Versatile Version Generator Action

This GitHub Action implements a flexible version management system that supports both Calendar Versioning (CalVer) and Semantic Versioning (SemVer) formats, with intelligent metadata extraction from PR titles and commit messages.

## Features

- **Dual Versioning Support**: Choose between Calendar Versioning or Semantic Versioning
- **Smart Increment Logic**: Automatically determines version increments based on commit message prefixes
- **Version Suffix Support**: Add optional suffixes like 'alpha', 'beta', or 'rc1'
- **Metadata Extraction**: Extracts JIRA tickets and conventional commit prefixes from PR titles
- **Branch Awareness**: Adds branch information to versions on non-main branches
- **Direct Version Override**: Optionally specify an exact version to use
- **Testable Design**: Core logic extracted to a script that can be tested independently

## Version Formats

The basic format is `Major.Minor.Patch[-Suffix][-Metadata]` where:

### Major Component Options

- **Calendar Versioning**: `YYMM` (Year/Month in format `YYMM`, e.g., 2505 for May 2025)
- **Semantic Versioning**: Standard major version number (e.g., 1, 2, 3)

### Version Parts

- **Minor & Patch**: Incremented based on conventional commit types in commit messages
- **Suffix (Optional)**: Custom suffix like 'alpha', 'beta', 'rc1'
- **Metadata (Optional)**: Auto-generated information for development builds in the format `[jira/prefix]-pr[number].[run_number]-[commit_hash]`

## Examples

- `2505.0.1` - Basic CalVer (May 2025)
- `2505.0.1-beta` - CalVer with suffix
- `2505.0.1-beta-mk123-pr456.42-abc123` - CalVer with suffix and metadata
- `1.2.3` - Basic SemVer
- `1.2.3-rc1` - SemVer with suffix
- `1.2.3-rc1-mk123-pr456.42-abc123` - SemVer with suffix and metadata

## Increment Logic

The action analyzes commit messages since the last tag to determine what to increment:

**For SemVer:**

- `BREAKING CHANGE(scope):` → Bump major version
- `feat(scope):`, `refactor(scope):`, etc. → Bump minor version
- `fix(scope):`, `hotfix(scope):` → Bump patch version

**For CalVer:**

- New month/year → Reset to YYMM.0.1
- Same month/year:
  - `feat(scope):`, `refactor(scope):`, etc. → Bump minor version
  - `fix(scope):`, `hotfix(scope):` → Bump patch version

## Configuration Options

| Input | Description | Default |
|-------|-------------|---------|
| `version-number` | Direct version override | `""` |
| `version-suffix` | Version suffix (e.g., alpha, beta, rc1) | `""` |
| `add-meta` | Add metadata to version | `false` |
| `jira-prefix` | JIRA project prefix | `MK` |
| `alternate-pr-prefixes` | Comma-separated list of PR prefixes | `fix,hotfix,chore,feat,refactor,docs,style,ci` |
| `use-calver` | Use Calendar Versioning | `false` |
| `semver-major` | Initial major version for SemVer | `1` |

## Usage

### Basic Usage

```yaml
- name: Generate Version
  id: version
  uses: ./.github/actions/version-generator
  with:
    add-meta: true
```

### Using Version Suffix

```yaml
- name: Generate Beta Version
  id: version
  uses: ./.github/actions/version-generator
  with:
    version-suffix: "beta"
    add-meta: true
```

### Specifying an Exact Version

```yaml
- name: Generate Specific Version
  id: version
  uses: ./.github/actions/version-generator
  with:
    version-number: "2.3.5"
    version-suffix: "rc2"  # Optional suffix for the provided version
```

### Using Calendar Versioning

```yaml
- name: Generate CalVer Version
  id: version
  uses: ./.github/actions/version-generator
  with:
    use-calver: true
    version-suffix: "alpha"
    add-meta: true
    jira-prefix: "FX"
```

### Full Example Workflow

```yaml
name: Build and Release

on:
  push:
    branches: [ main, develop ]
  pull_request:
    branches: [ main ]

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0

      - name: Generate Version
        id: version
        uses: ./.github/actions/version-generator
        with:
          use-calver: false
          version-suffix: ${{ github.ref == 'refs/heads/develop' && 'beta' || '' }}
          add-meta: ${{ github.ref != 'refs/heads/main' }}
          jira-prefix: "MK"

      - name: Build Application
        run: |
          echo "Building version ${{ steps.version.outputs.version }}"
          # Your build commands here

      - name: Create Release
        if: github.ref == 'refs/heads/main'
        uses: softprops/action-gh-release@v1
        with:
          name: "v${{ steps.version.outputs.version }}"
          tag_name: "v${{ steps.version.outputs.version }}"
          generate_release_notes: true
```

## Testing

The version generator has a comprehensive test suite that verifies all functionality:

### Running Tests

```bash
# Make the scripts executable
chmod +x generate-version.sh test-version.sh

# Run the test suite
./test-version.sh
```

### Test Coverage

The test suite covers:

- Initial version creation (CalVer and SemVer)
- Version increments based on commit types
- Version suffix addition
- Metadata extraction from PR titles
- JIRA ticket extraction and normalization (removing hyphens and spaces)
- Conventional commit prefix extraction
- Branch-specific versioning
- Direct version overrides

### Adding New Tests

To add a new test case, simply add a new test to the `test-version.sh` file:

```bash
# Test template
run_test "Test name" "expected_result" "version_number" "version_suffix" "add_meta" "jira_prefix" "alternate_prefixes" "use_calver" "semver_major" "github_ref" "github_sha" "github_run_number" "github_event_path"
```

## Implementation Details

This action uses a modular approach with separate functions for:

- Creating initial versions
- Calculating version increments based on commit messages
- Applying version suffixes
- Extracting metadata from PR titles

### Metadata Format

When `add-meta` is enabled, the action adds metadata in this format:

`[jira/prefix]-pr[number].[run_number]-[commit_hash]`

Where:
- **jira/prefix**: Normalized JIRA ticket (e.g., `mk123` from `MK-123` or `MK 123`) or commit prefix (e.g., `fix`, `feat`)
- **pr[number]**: Pull request number (e.g., `pr456`)
- **run_number**: GitHub workflow run number (e.g., `42`)
- **commit_hash**: Short commit hash (e.g., `abc123`)

#### JIRA Ticket Normalization

JIRA tickets are normalized by:
1. Converting to lowercase
2. Removing hyphens and spaces between prefix and number

Examples:
- `MK-123` → `mk123`
- `ABC 456` → `abc456`

The core functionality is extracted to a standalone script (`generate-version.sh`), making it:

- Independently testable
- Easier to maintain
- More reusable across different contexts
