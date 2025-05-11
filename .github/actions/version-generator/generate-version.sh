#!/usr/bin/env bash
set -euo pipefail

# Function to create initial version based on versioning mode
create_initial_version() {
  local use_calver="$1"
  local current_major="$2"
  local semver_major="$3"

  if [ "$use_calver" = "true" ]; then
    echo "$current_major.0.1"
  else
    echo "$semver_major.0.0"
  fi
}

# Function to determine next version based on commits and versioning mode
calculate_next_version() {
  local current_version="$1"
  local commit_messages="$2"
  local use_calver="$3"
  local current_major="$4"

  # Extract version components
  local IFS='.'
  read -r major minor patch <<< "${current_version//[!0-9.]/}"

  if [ "$use_calver" = "true" ]; then
    # CalVer logic
    if [ "$major" != "$current_major" ]; then
      echo "$current_major.0.1"
      return
    fi

    if echo "$commit_messages" | grep -Eq "^(feat|refactor|docs|chore|style|ci)\([a-zA-Z0-9_-]+\):"; then
      echo "$major.$((minor + 1)).0"
    else
      echo "$major.$minor.$((patch + 1))"
    fi
  else
    # SemVer logic
    if echo "$commit_messages" | grep -Eq "^(BREAKING\sCHANGE)\([a-zA-Z0-9_-]+\):"; then
      echo "$((major + 1)).0.0"
    elif echo "$commit_messages" | grep -Eq "^(feat|refactor|docs|chore|style|ci)\([a-zA-Z0-9_-]+\):"; then
      echo "$major.$((minor + 1)).0"
    else
      echo "$major.$minor.$((patch + 1))"
    fi
  fi
}

# Function to extract metadata from PR title
extract_pr_metadata() {
  local pr_number="$1"
  local pr_title="$2"
  local jira_prefix="$3"
  local alternate_prefixes="$4"
  local metadata=""

  [ -n "$pr_number" ] && [ "$pr_number" != "null" ] && metadata="pr$pr_number-"

  if [ -n "$pr_title" ] && [ "$pr_title" != "null" ]; then
    # Extract JIRA ticket from anywhere in PR title
    # Support prefixes with spaces (e.g., "MK 123" or "MK-123")
    local jira_ticket=$(echo "$pr_title" | grep -oE "($jira_prefix[- ][0-9]+|$jira_prefix[0-9]+)" | head -n 1)
    if [ -n "$jira_ticket" ]; then
      # Normalize the JIRA ticket format to remove hyphens and spaces
      jira_ticket=$(echo "$jira_ticket" | sed -E "s/($jira_prefix)[- ]?([0-9]+)/\1\2/")
      # Convert to lowercase
      jira_ticket=$(echo "$jira_ticket" | tr '[:upper:]' '[:lower:]')
      metadata="$jira_ticket-$metadata"
    fi

    # Extract prefix from beginning of PR title if JIRA ticket is not found
    local prefix_regex=$(echo "$alternate_prefixes" | sed 's/,/\|/g')
    # Match prefix at the beginning of PR title with or without scope and colon
    local pr_prefix=$(echo "$pr_title" | grep -oiE "^($prefix_regex)(\([^)]*\))?:" | head -n 1)
    if [ -z "$jira_ticket" ] && [ -n "$pr_prefix" ]; then
      local base_prefix=$(echo "${pr_prefix%:}" | tr '[:upper:]' '[:lower:]' | sed -E 's/([a-z]+)(\([^)]*\))?/\1/')
      metadata="$base_prefix-$metadata"
    fi
  fi

  # Ensure all metadata is lowercase
  metadata=$(echo "$metadata" | tr '[:upper:]' '[:lower:]')
  echo "$metadata"
}

# Function to apply version suffix if provided
apply_version_suffix() {
  local version="$1"
  local suffix="$2"

  if [ -n "$suffix" ]; then
    echo "$version-$suffix"
  else
    echo "$version"
  fi
}

# Function to find latest version tag
find_latest_tag() {
  git tag -l --sort=-v:refname | grep -E '^[0-9]+\.[0-9]+\.[0-9]+$' | head -n 1 || echo ""
}

# Function to get commits since latest tag
get_commits_since_tag() {
  local latest_tag="$1"
  local latest_commit="$2"

  if [ -z "$latest_tag" ]; then
    echo ""
  else
    git log ${latest_tag}..${latest_commit} --pretty=format:"%s"
  fi
}

# Main function to generate next version
generate_next_version() {
  # Required parameters
  local version_number="${1:-}"
  local version_suffix="${2:-}"
  local add_meta="${3:-false}"
  local jira_prefix="${4:-MK}"
  local alternate_prefixes="${5:-fix,hotfix,chore,feat,refactor,docs,style,ci}"
  local use_calver="${6:-false}"
  local semver_major="${7:-1}"
  local github_ref="${8:-}"
  local github_sha="${9:-}"
  local github_run_number="${10:-}"
  local github_event_path="${11:-}"

  # Derived parameters
  local branch=$(echo "$github_ref" | sed 's/refs\/heads\///')
  local short_sha=$(echo "$github_sha" | cut -c1-7)
  local run_number="$github_run_number"
  local current_major=$(date +"%y%m")

  # Check if version number was directly provided
  if [ -n "$version_number" ]; then
    local provided_version="$version_number"

    # Apply suffix to provided version if needed
    if [ -n "$version_suffix" ]; then
      provided_version=$(apply_version_suffix "$provided_version" "$version_suffix")
    fi

    echo "$provided_version"
    return
  fi

  # Find latest version tag
  local latest_tag=$(find_latest_tag)

  # Determine base version
  local new_version
  if [ -z "$latest_tag" ]; then
    # No tag exists, create initial version
    new_version=$(create_initial_version "$use_calver" "$current_major" "$semver_major")
  else
    # Get commits since latest tag
    local latest_commit="$github_sha"
    local commits=$(get_commits_since_tag "$latest_tag" "$latest_commit")

    if [ -z "$commits" ]; then
      # No commits since latest tag
      new_version="$latest_tag"
    else
      # Calculate next version based on commits
      new_version=$(calculate_next_version "$latest_tag" "$commits" "$use_calver" "$current_major")
    fi
  fi

  # Apply version suffix if provided
  if [ -n "$version_suffix" ]; then
    new_version=$(apply_version_suffix "$new_version" "$version_suffix")
  fi

  # Add metadata if requested
  if [ "$add_meta" = "true" ]; then
    # Extract PR info
    local prefix_metadata=""
    local pr_number_part=""
    local run_number_part=""
    
    if [ -n "$github_event_path" ] && [ -f "$github_event_path" ]; then
      local pr_number=$(jq --raw-output '.pull_request.number // .number // ""' "$github_event_path" 2>/dev/null || echo "")
      local pr_title=$(jq --raw-output '.pull_request.title // .title // ""' "$github_event_path" 2>/dev/null || echo "")
      prefix_metadata=$(extract_pr_metadata "$pr_number" "$pr_title" "$jira_prefix" "$alternate_prefixes")
      
      # Extract PR number part from the metadata
      if [ -n "$pr_number" ] && [ "$pr_number" != "null" ]; then
        # Remove the PR number from prefix_metadata to avoid duplication
        prefix_metadata=$(echo "$prefix_metadata" | sed "s/pr$pr_number-//")
        pr_number_part="pr$pr_number"
      fi
    fi
    
    # Add run number if available
    if [ -n "$run_number" ]; then
      run_number_part=".$run_number"
    fi
    
    # Construct the final version string
    local version_parts=""
    
    # Add prefix metadata (JIRA ticket or commit type) if available
    if [ -n "$prefix_metadata" ]; then
      # Remove trailing hyphen if present
      prefix_metadata=$(echo "$prefix_metadata" | sed 's/-$//')
      version_parts="$prefix_metadata"
    fi
    
    # Add PR number if available
    if [ -n "$pr_number_part" ]; then
      if [ -n "$version_parts" ]; then
        version_parts="$version_parts-$pr_number_part"
      else
        version_parts="$pr_number_part"
      fi
    fi
    
    # Add run number if available
    if [ -n "$run_number_part" ]; then
      version_parts="${version_parts}$run_number_part"
    fi
    
    # Add commit hash
    if [ -n "$short_sha" ]; then
      version_parts="${version_parts}-$short_sha"
    fi
    
    # Add the metadata to the version
    if [ -n "$version_parts" ]; then
      new_version="$new_version-$version_parts"
    fi
  elif [ "$branch" != "main" ] && [ "$branch" != "master" ]; then
    # For non-main branches without metadata flag
    new_version="$new_version-$branch-$short_sha"
  fi

  echo "$new_version"
}

# Run the function if this script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  # Script was executed directly (not sourced)
  generate_next_version "$@"
fi
