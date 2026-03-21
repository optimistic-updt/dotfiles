#!/bin/bash

# Read JSON input from stdin
input=$(cat)

# Extract values from JSON
current_dir=$(echo "$input" | jq -r '.workspace.current_dir')
project_dir=$(echo "$input" | jq -r '.workspace.project_dir')
model=$(echo "$input" | jq -r '.model.display_name')

# Calculate relative path
rel_path=${current_dir#$project_dir}
rel_path=${rel_path#/}

# Determine directory display
if [ "$current_dir" = "$project_dir" ]; then
    dir_display=$(basename "$project_dir")
else
    dir_display="$(basename "$project_dir")/${rel_path}"
fi

# Get git information (skip locks for performance)
if git -C "$current_dir" rev-parse --git-dir > /dev/null 2>&1; then
    branch=$(git -C "$current_dir" --no-optional-locks branch --show-current 2>/dev/null)
    if [ -n "$branch" ]; then
        # Check for dirty status
        if git -C "$current_dir" --no-optional-locks diff --quiet 2>/dev/null && \
           git -C "$current_dir" --no-optional-locks diff --cached --quiet 2>/dev/null; then
            git_info=" ⎇ $branch"
        else
            git_info=" ⎇ $branch ±"
        fi
    else
        git_info=""
    fi
else
    git_info=""
fi

# Calculate context window percentage (current context, not cumulative)
usage=$(echo "$input" | jq '.context_window.current_usage')
if [ "$usage" != "null" ]; then
    # Sum input tokens, cache creation tokens, and cache read tokens
    current=$(echo "$usage" | jq '.input_tokens + .cache_creation_input_tokens + .cache_read_input_tokens')
    size=$(echo "$input" | jq '.context_window.context_window_size')
    # Calculate percentage of context window used
    pct=$((current * 100 / size))
    context_info=" ${pct}%"
else
    context_info=""
fi

# Agnoster-style status line with magenta background for directory
# Using printf for proper color handling
printf "\033[35m\033[40m %s \033[0m%s%s \033[2m%s\033[0m" "$dir_display" "$git_info" "$context_info" "$model"
