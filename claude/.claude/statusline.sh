#!/bin/bash
set -u

# Read JSON from stdin
json=$(cat)

# Extract fields using jq
model=$(echo "$json" | jq -r '.model.display_name')
current_dir=$(echo "$json" | jq -r '.workspace.current_dir')
context_pct=$(echo "$json" | jq -r '.context_window.used_percentage // 0')

# Extract rate limits (if present)
rate_pct=$(echo "$json" | jq -r '.rate_limits.five_hour.used_percentage // empty | round')
resets_at=$(echo "$json" | jq -r '.rate_limits.five_hour.resets_at // empty')

# Extract folder name
folder=$(basename "$current_dir")

# Extract git branch: prefer worktree info from JSON, fall back to git itself
branch=$(echo "$json" | jq -r '.worktree.branch // .workspace.git_worktree // empty')
if [[ -z "$branch" ]]; then
    branch=$(git -C "$current_dir" branch --show-current 2>/dev/null)
fi

branch_segment=""
if [[ -n "$branch" ]]; then
    branch_segment=" ($(printf '\033[38;5;183m%s\033[0m' "$branch"))"
fi

# Build time segment (only if rate limits are available)
time_segment=""
if [[ -n "$rate_pct" ]] && [[ -n "$resets_at" ]]; then
    now=$(date +%s)
    delta=$((resets_at - now))

    if [[ $delta -gt 0 ]]; then
        hours=$((delta / 3600))
        minutes=$(((delta % 3600) / 60))

        # Color rate_pct based on threshold
        colored_pct="$rate_pct%"
        if [[ $rate_pct -ge 90 ]]; then
            colored_pct=$'\033[31m'"${rate_pct}%"$'\033[0m'  # Red
        elif [[ $rate_pct -ge 70 ]]; then
            colored_pct=$'\033[38;5;214m'"${rate_pct}%"$'\033[0m'  # Orange
        fi

        time_segment=" | ⏱️ ${colored_pct} resets in ${hours}:$(printf "%02d" $minutes)"
    fi
fi

# Output
printf "📁 %s%s | 🤖 %s | 🧠 %s%%%s\n" "$folder" "$branch_segment" "$model" "$context_pct" "$time_segment"
