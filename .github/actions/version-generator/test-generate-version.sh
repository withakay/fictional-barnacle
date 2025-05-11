#!/usr/bin/env bash
set -euo pipefail

# Import the version generation script
source "$(dirname "$0")/generate-version.sh"

# Terminal colors for better readability
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Mock git functions
find_latest_tag() {
  echo "$MOCK_LATEST_TAG"
}

get_commits_since_tag() {
  echo "$MOCK_COMMITS"
}

# Function to run a test case
run_test() {
  local test_name="$1"
  local expected="$2"
  local version_number="${3:-}"
  local version_suffix="${4:-}"
  local add_meta="${5:-false}"
  local jira_prefix="${6:-MK}"
  local alternate_prefixes="${7:-fix,hotfix,chore,feat,refactor,docs,style,ci}"
  local use_calver="${8:-false}"
  local semver_major="${9:-1}"
  local github_ref="${10:-refs/heads/main}"
  local github_sha="${11:-1234567890abcdef1234567890abcdef12345678}"
  local github_run_number="${12:-42}"
  local github_event_path="${13:-}"

  # Set mock variables based on test configuration
  export MOCK_LATEST_TAG="$MOCK_LATEST_TAG_VALUE"
  export MOCK_COMMITS="$MOCK_COMMITS_VALUE"

  # Run the function
  local result=$(generate_next_version \
    "$version_number" \
    "$version_suffix" \
    "$add_meta" \
    "$jira_prefix" \
    "$alternate_prefixes" \
    "$use_calver" \
    "$semver_major" \
    "$github_ref" \
    "$github_sha" \
    "$github_run_number" \
    "$github_event_path"
  )

  # Check the result
  if [ "$result" = "$expected" ]; then
    echo -e "${GREEN}PASS${NC}: $test_name - Got: $result"
  else
    echo -e "${RED}FAIL${NC}: $test_name - Expected: $expected, Got: $result"
    FAILED_TESTS=$((FAILED_TESTS + 1))
  fi
}

# Setup for PR tests
setup_pr_test() {
  # Create a temporary event file with PR info
  local temp_dir=$(mktemp -d)
  local event_file="$temp_dir/event.json"

  cat > "$event_file" << EOF
{
  "pull_request": {
    "number": $PR_NUMBER,
    "title": "$PR_TITLE"
  }
}
EOF

  echo "$event_file"
}

# Main test runner
run_tests() {
  # Track failed tests
  FAILED_TESTS=0

  echo "Running version generation tests..."

  # Test 1: Initial SemVer version
  MOCK_LATEST_TAG_VALUE=""
  MOCK_COMMITS_VALUE=""
  run_test "Initial SemVer version" "1.0.0" "" "" "false" "MK" "fix,hotfix,chore" "false" "1"

  # Test 2: Initial CalVer version (assume current date gives YYMM of 2505)
  export CURRENT_DATE_MOCK="2505"
  MOCK_LATEST_TAG_VALUE=""
  MOCK_COMMITS_VALUE=""
  current_major=$(date +"%y%m") # actual current date for test
  expected="$current_major.0.1"
  run_test "Initial CalVer version" "$expected" "" "" "false" "MK" "fix,hotfix,chore" "true" "1"

  # Test 3: SemVer patch increment
  MOCK_LATEST_TAG_VALUE="1.0.0"
  MOCK_COMMITS_VALUE="fix(api): Fix login issue"
  run_test "SemVer patch increment" "1.0.1" "" "" "false" "MK" "fix,hotfix,chore" "false" "1"

  # Test 4: SemVer minor increment
  MOCK_LATEST_TAG_VALUE="1.0.0"
  MOCK_COMMITS_VALUE="feat(api): Add new feature"
  run_test "SemVer minor increment" "1.1.0" "" "" "false" "MK" "fix,hotfix,chore" "false" "1"

  # Test 5: SemVer major increment
  MOCK_LATEST_TAG_VALUE="1.0.0"
  MOCK_COMMITS_VALUE="BREAKING CHANGE(api): Completely rebuild API"
  run_test "SemVer major increment" "2.0.0" "" "" "false" "MK" "fix,hotfix,chore" "false" "1"

  # Test 6: CalVer same month patch increment
  MOCK_LATEST_TAG_VALUE="$current_major.0.1"
  MOCK_COMMITS_VALUE="fix(api): Fix login issue"
  run_test "CalVer same month patch increment" "$current_major.0.2" "" "" "false" "MK" "fix,hotfix,chore" "true" "1"

  # Test 7: CalVer same month minor increment
  MOCK_LATEST_TAG_VALUE="$current_major.0.1"
  MOCK_COMMITS_VALUE="feat(api): Add new feature"
  run_test "CalVer same month minor increment" "$current_major.1.0" "" "" "false" "MK" "fix,hotfix,chore" "true" "1"

  # Test 8: CalVer new month reset
  MOCK_LATEST_TAG_VALUE="2504.1.2" # Previous month
  MOCK_COMMITS_VALUE="fix(api): Fix login issue"
  run_test "CalVer new month reset" "$current_major.0.1" "" "" "false" "MK" "fix,hotfix,chore" "true" "1"

  # Test 9: Version with suffix
  MOCK_LATEST_TAG_VALUE="1.0.0"
  MOCK_COMMITS_VALUE="fix(api): Fix login issue"
  run_test "Version with suffix" "1.0.1-beta" "" "beta" "false" "MK" "fix,hotfix,chore" "false" "1"

  # Test 10: Directly provided version
  MOCK_LATEST_TAG_VALUE=""
  MOCK_COMMITS_VALUE=""
  run_test "Directly provided version" "3.2.1" "3.2.1" "" "false" "MK" "fix,hotfix,chore" "false" "1"

  # Test 11: Directly provided version with suffix
  MOCK_LATEST_TAG_VALUE=""
  MOCK_COMMITS_VALUE=""
  run_test "Directly provided version with suffix" "3.2.1-rc1" "3.2.1" "rc1" "false" "MK" "fix,hotfix,chore" "false" "1"

  # Test 12: Non-main branch without metadata
  MOCK_LATEST_TAG_VALUE="1.0.0"
  MOCK_COMMITS_VALUE="fix(api): Fix login issue"
  run_test "Non-main branch without metadata" "1.0.1-feature-1234567" "" "" "false" "MK" "fix,hotfix,chore" "false" "1" "refs/heads/feature" "1234567890abcdef1234567890abcdef12345678"

  # Setup for PR tests
  export PR_NUMBER=123
  export PR_TITLE="fix(auth): MK-456 Implement login"
  local event_file=$(setup_pr_test)

  # Test 13: Version with PR metadata
  export PR_TITLE="fix(auth): MK-456 Implement login"
  MOCK_LATEST_TAG_VALUE="1.0.0"
  MOCK_COMMITS_VALUE="fix(api): Fix login issue"
  run_test "Version with PR metadata" "1.0.1-mk456-pr123.42-1234567" "" "" "true" "MK" "fix,hotfix,chore" "false" "1" "refs/heads/main" "1234567890abcdef1234567890abcdef12345678" "42" "$event_file"

  # Test 14: PR with JIRA ticket but no prefix
  export PR_TITLE="Implement MK456 login feature"
  event_file=$(setup_pr_test)
  MOCK_LATEST_TAG_VALUE="1.0.0"
  MOCK_COMMITS_VALUE="fix(api): Fix login issue"
  run_test "PR with JIRA ticket but no prefix" "1.0.1-mk456-pr123.42-1234567" "" "" "true" "MK" "fix,hotfix,chore" "false" "1" "refs/heads/main" "1234567890abcdef1234567890abcdef12345678" "42" "$event_file"

  # Test 15: PR with prefix but no JIRA ticket
  export PR_TITLE="fix: Implement login feature"
  event_file=$(setup_pr_test)
  MOCK_LATEST_TAG_VALUE="1.0.0"
  MOCK_COMMITS_VALUE="fix(api): Fix login issue"
  run_test "PR with prefix but no JIRA ticket" "1.0.1-fix-pr123.42-1234567" "" "" "true" "MK" "fix,hotfix,chore" "false" "1" "refs/heads/main" "1234567890abcdef1234567890abcdef12345678" "42" "$event_file"

  # Test 16: Custom JIRA prefix
  export PR_TITLE="FX-123: Implement new feature"
  event_file=$(setup_pr_test)
  MOCK_LATEST_TAG_VALUE="1.0.0"
  MOCK_COMMITS_VALUE="fix(api): Fix login issue"
  run_test "Custom JIRA prefix" "1.0.1-fx123-pr123.42-1234567" "" "" "true" "FX" "fix,hotfix,chore" "false" "1" "refs/heads/main" "1234567890abcdef1234567890abcdef12345678" "42" "$event_file"

  # Test 17: Custom alternate PR prefixes
  export PR_TITLE="build: Setup CI pipeline"
  event_file=$(setup_pr_test)
  MOCK_LATEST_TAG_VALUE="1.0.0"
  MOCK_COMMITS_VALUE="fix(api): Fix login issue"
  run_test "Custom alternate PR prefixes" "1.0.1-build-pr123.42-1234567" "" "" "true" "MK" "fix,build,chore" "false" "1" "refs/heads/main" "1234567890abcdef1234567890abcdef12345678" "42" "$event_file"

  # Test 18: JIRA prefix with space
  export PR_TITLE="Implement ABC 789 login feature"
  event_file=$(setup_pr_test)
  MOCK_LATEST_TAG_VALUE="1.0.0"
  MOCK_COMMITS_VALUE="fix(api): Fix login issue"
  run_test "JIRA prefix with space" "1.0.1-abc789-pr123.42-1234567" "" "" "true" "ABC" "fix,hotfix,chore" "false" "1" "refs/heads/main" "1234567890abcdef1234567890abcdef12345678" "42" "$event_file"

  # Test 19: JIRA prefix with space (2)
  export PR_TITLE="Implement ABC 9XX login feature"
  event_file=$(setup_pr_test)
  MOCK_LATEST_TAG_VALUE="1.0.0"
  MOCK_COMMITS_VALUE="fix(api): Fix login issue"
  run_test "JIRA prefix with space (2)" "1.0.1-abc9-pr123.42-1234567" "" "" "true" "ABC" "fix,hotfix,chore" "false" "1" "refs/heads/main" "1234567890abcdef1234567890abcdef12345678" "42" "$event_file"

  # Test 20: JIRA prefix with partial match is not used
  export PR_TITLE="Implement ABC XXX login feature"
  event_file=$(setup_pr_test)
  MOCK_LATEST_TAG_VALUE="1.0.0"
  MOCK_COMMITS_VALUE="fix(api): Fix login issue"
  run_test "JIRA prefix with partial match is not used" "1.0.1-pr123.42-1234567" "" "" "true" "ABC" "fix,hotfix,chore" "false" "1" "refs/heads/main" "1234567890abcdef1234567890abcdef12345678" "42" "$event_file"

  # Test 21: JIRA prefix with partial match is not used
  export PR_TITLE="Implement ABC-X9 login feature"
  event_file=$(setup_pr_test)
  MOCK_LATEST_TAG_VALUE="1.0.0"
  MOCK_COMMITS_VALUE="fix(api): Fix login issue"
  run_test "JIRA prefix with partial match is not used (2)" "1.0.1-pr123.42-1234567" "" "" "true" "ABC" "fix,hotfix,chore" "false" "1" "refs/heads/main" "1234567890abcdef1234567890abcdef12345678" "42" "$event_file"

  # Test 22: CalVer with suffix and metadata
  export PR_TITLE="feat: ABC-123 New feature"
  event_file=$(setup_pr_test)
  MOCK_LATEST_TAG_VALUE="$current_major.0.1"
  MOCK_COMMITS_VALUE="feat(api): Add new feature"
  run_test "CalVer with suffix and metadata" "$current_major.1.0-beta-abc123-pr123.42-1234567" "" "beta" "true" "ABC" "fix,hotfix,chore,feat" "true" "1" "refs/heads/main" "1234567890abcdef1234567890abcdef12345678" "42" "$event_file"

  # Test 23: PR title with multiple JIRA tickets (should use first)
  export PR_TITLE="ABC-123 Fix issue described in XYZ-456"
  event_file=$(setup_pr_test)
  MOCK_LATEST_TAG_VALUE="1.0.0"
  MOCK_COMMITS_VALUE="fix(api): Fix login issue"
  run_test "Multiple JIRA tickets in PR title" "1.0.1-abc123-pr123.42-1234567" "" "" "true" "ABC,XYZ" "fix,hotfix,chore" "false" "1" "refs/heads/main" "1234567890abcdef1234567890abcdef12345678" "42" "$event_file"

  # Test 24: Empty PR title
  export PR_TITLE=""
  event_file=$(setup_pr_test)
  MOCK_LATEST_TAG_VALUE="1.0.0"
  MOCK_COMMITS_VALUE="fix(api): Fix login issue"
  run_test "Empty PR title" "1.0.1-pr123.42-1234567" "" "" "true" "MK" "fix,hotfix,chore" "false" "1" "refs/heads/main" "1234567890abcdef1234567890abcdef12345678" "42" "$event_file"

  # Test 25: Multiple commit types (should use highest priority - major > minor > patch)
  MOCK_LATEST_TAG_VALUE="1.0.0"
  MOCK_COMMITS_VALUE="fix(api): Fix login issue\nfeat(ui): Add new feature\nBREAKING CHANGE(api): Change API structure"
  run_test "Multiple commit types (major wins)" "2.0.0" "" "" "false" "MK" "fix,hotfix,chore,feat" "false" "1" "refs/heads/main" "1234567890abcdef1234567890abcdef12345678" "42"

  # Test 26: Multiple commit types (minor wins)
  MOCK_LATEST_TAG_VALUE="1.0.0"
  MOCK_COMMITS_VALUE="fix(api): Fix login issue\nfeat(ui): Add new feature\nchore: Update dependencies"
  run_test "Multiple commit types (minor wins)" "1.1.0" "" "" "false" "MK" "fix,hotfix,chore,feat" "false" "1" "refs/heads/main" "1234567890abcdef1234567890abcdef12345678" "42"

  # Test 27: Version suffix on non-main branch
  MOCK_LATEST_TAG_VALUE="1.0.0"
  MOCK_COMMITS_VALUE="fix(api): Fix login issue"
  run_test "Version suffix on non-main branch" "1.0.1-alpha-feature-1234567" "" "alpha" "false" "MK" "fix,hotfix,chore" "false" "1" "refs/heads/feature" "1234567890abcdef1234567890abcdef12345678" "42"

  # Test 28: CalVer with multiple commit types
  MOCK_LATEST_TAG_VALUE="$current_major.0.1"
  MOCK_COMMITS_VALUE="fix(api): Fix login issue\nfeat(ui): Add new feature"
  run_test "CalVer with multiple commit types" "$current_major.1.0" "" "" "false" "MK" "fix,hotfix,chore,feat" "true" "1" "refs/heads/main" "1234567890abcdef1234567890abcdef12345678" "42"

  # Test 29: JIRA prefix with no space
  export PR_TITLE="Implement ABC99 login feature"
  event_file=$(setup_pr_test)
  MOCK_LATEST_TAG_VALUE="1.0.0"
  MOCK_COMMITS_VALUE="fix(api): Fix login issue"
  run_test "JIRA prefix with no space" "1.0.1-abc99-pr123.42-1234567" "" "" "true" "ABC" "fix,hotfix,chore" "false" "1" "refs/heads/main" "1234567890abcdef1234567890abcdef12345678" "42" "$event_file"

  # Test 30: JIRA prefix with no space (2)
  export PR_TITLE="Implement ABC99-XZY login feature"
  event_file=$(setup_pr_test)
  MOCK_LATEST_TAG_VALUE="1.0.0"
  MOCK_COMMITS_VALUE="fix(api): Fix login issue"
  run_test "JIRA prefix with no space (2)" "1.0.1-abc99-pr123.42-1234567" "" "" "true" "ABC" "fix,hotfix,chore" "false" "1" "refs/heads/main" "1234567890abcdef1234567890abcdef12345678" "42" "$event_file"

  # Test 31: JIRA prefix with no space (3)
  export PR_TITLE="Implement ABC99:XZY login feature"
  event_file=$(setup_pr_test)
  MOCK_LATEST_TAG_VALUE="1.0.0"
  MOCK_COMMITS_VALUE="fix(api): Fix login issue"
  event_file=$(setup_pr_test)
  MOCK_LATEST_TAG_VALUE="1.0.0"
  MOCK_COMMITS_VALUE="fix(api): Fix login issue"
  run_test "JIRA prefix with no space (2)" "1.0.1-abc99-pr123.42-1234567" "" "" "true" "ABC" "fix,hotfix,chore" "false" "1" "refs/heads/main" "1234567890abcdef1234567890abcdef12345678" "42" "$event_file"

  # Test 30: JIRA prefix with no space (4)
  export PR_TITLE="Implement ABC99|XZY login feature"
  event_file=$(setup_pr_test)
  MOCK_LATEST_TAG_VALUE="1.0.0"
  MOCK_COMMITS_VALUE="fix(api): Fix login issue"
  run_test "JIRA prefix with no space (4)" "1.0.1-abc99-pr123.42-1234567" "" "" "true" "ABC" "fix,hotfix,chore" "false" "1" "refs/heads/main" "1234567890abcdef1234567890abcdef12345678" "42" "$event_file"

  # Test summary
  echo ""
  if [ $FAILED_TESTS -eq 0 ]; then
    echo -e "${GREEN}All tests passed successfully!${NC}"
    exit 0
  else
    echo -e "${RED}$FAILED_TESTS test(s) failed!${NC}"
    exit 1
  fi
}

# Run all tests
run_tests
