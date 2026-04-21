#!/usr/bin/env bash
set -euo pipefail

API_BASE="https://repoclip.io/api/v1"
API_KEY="${REPOCLIP_API_KEY}"
REPO_URL="${REPOCLIP_GITHUB_URL:-${GITHUB_SERVER_URL}/${GITHUB_REPOSITORY}}"
MODE="${REPOCLIP_MODE:-image}"
PROMPT="${REPOCLIP_PROMPT:-}"
ASPECT_RATIO="${REPOCLIP_ASPECT_RATIO:-16:9}"
VISUAL_STYLE="${REPOCLIP_VISUAL_STYLE:-tech}"
BGM="${REPOCLIP_BGM:-false}"
POLL_INTERVAL="${REPOCLIP_POLL_INTERVAL:-30}"
TIMEOUT="${REPOCLIP_TIMEOUT:-1200}"

# Build JSON payload
PAYLOAD=$(jq -n \
  --arg url "$REPO_URL" \
  --arg mode "$MODE" \
  --arg ar "$ASPECT_RATIO" \
  --arg vs "$VISUAL_STYLE" \
  --argjson bgm "$BGM" \
  '{github_url: $url, mode: $mode, aspect_ratio: $ar, visual_style: $vs, bgm: $bgm}')

# Add prompt if provided
if [ -n "$PROMPT" ]; then
  PAYLOAD=$(echo "$PAYLOAD" | jq --arg p "$PROMPT" '. + {prompt: $p}')
fi

echo "::group::Starting video generation"
echo "Repository: $REPO_URL"
echo "Mode: $MODE"
echo "::endgroup::"

# Start generation
RESPONSE=$(curl -sf -X POST "${API_BASE}/generate" \
  -H "Authorization: Bearer ${API_KEY}" \
  -H "Content-Type: application/json" \
  -d "$PAYLOAD" 2>&1) || {
  ERROR_MSG=$(echo "$RESPONSE" | jq -r '.error.message // "Unknown error"' 2>/dev/null || echo "$RESPONSE")
  echo "::error::Failed to start generation: ${ERROR_MSG}"
  exit 1
}

PROJECT_ID=$(echo "$RESPONSE" | jq -r '.id')
CREDITS_USED=$(echo "$RESPONSE" | jq -r '.credits_used')
CREDITS_REMAINING=$(echo "$RESPONSE" | jq -r '.credits_remaining')

if [ "$PROJECT_ID" = "null" ] || [ -z "$PROJECT_ID" ]; then
  ERROR_MSG=$(echo "$RESPONSE" | jq -r '.error.message // "Unknown error"')
  echo "::error::Failed to start generation: ${ERROR_MSG}"
  exit 1
fi

echo "Project ID: ${PROJECT_ID}"
echo "Credits used: ${CREDITS_USED}, remaining: ${CREDITS_REMAINING}"

# Set project-id output early
echo "project-id=${PROJECT_ID}" >> "$GITHUB_OUTPUT"

# Poll for completion
ELAPSED=0
while [ "$ELAPSED" -lt "$TIMEOUT" ]; do
  sleep "$POLL_INTERVAL"
  ELAPSED=$((ELAPSED + POLL_INTERVAL))

  STATUS_RESPONSE=$(curl -sf "${API_BASE}/projects/${PROJECT_ID}" \
    -H "Authorization: Bearer ${API_KEY}" 2>&1) || {
    echo "::warning::Status check failed, retrying..."
    continue
  }

  CURRENT_STATUS=$(echo "$STATUS_RESPONSE" | jq -r '.status')
  echo "Status: ${CURRENT_STATUS} (${ELAPSED}s elapsed)"

  if [ "$CURRENT_STATUS" = "completed" ]; then
    VIDEO_URL=$(echo "$STATUS_RESPONSE" | jq -r '.video_url // empty')
    THUMBNAIL_URL=$(echo "$STATUS_RESPONSE" | jq -r '.thumbnail_url // empty')
    SHARE_URL=$(echo "$STATUS_RESPONSE" | jq -r '.share_url // empty')

    echo "video-url=${VIDEO_URL}" >> "$GITHUB_OUTPUT"
    echo "thumbnail-url=${THUMBNAIL_URL}" >> "$GITHUB_OUTPUT"
    echo "share-url=${SHARE_URL}" >> "$GITHUB_OUTPUT"
    echo "status=completed" >> "$GITHUB_OUTPUT"

    echo ""
    echo "Video generated successfully!"
    echo "  Video:     ${VIDEO_URL}"
    echo "  Share:     ${SHARE_URL}"
    echo "  Thumbnail: ${THUMBNAIL_URL}"
    exit 0
  fi

  if [ "$CURRENT_STATUS" = "failed" ]; then
    ERROR_MSG=$(echo "$STATUS_RESPONSE" | jq -r '.error_message // "Unknown error"')
    echo "status=failed" >> "$GITHUB_OUTPUT"
    echo "::error::Video generation failed: ${ERROR_MSG}"
    exit 1
  fi
done

echo "status=failed" >> "$GITHUB_OUTPUT"
echo "::error::Generation timed out after ${TIMEOUT} seconds"
exit 1
