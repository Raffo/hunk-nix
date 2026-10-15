#!/usr/bin/env bash
# Requires curl, jq, and standard Unix utilities.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SOURCES_FILE="$ROOT/sources.json"
RELEASE_URL="https://api.github.com/repos/modem-dev/hunk/releases/latest"

curl_args=(--fail --silent --show-error --location --retry 3)
api_args=(--header "Accept: application/vnd.github+json")
if [[ -n "${GH_TOKEN:-}" ]]; then
  api_args+=(--header "Authorization: Bearer $GH_TOKEN")
fi

release="$(curl "${curl_args[@]}" "${api_args[@]}" "$RELEASE_URL")"
tag="$(jq -er '
  select(.draft == false and .prerelease == false)
  | .tag_name
  | select(type == "string" and test("^v[0-9]+\\.[0-9]+\\.[0-9]+$"))
' <<< "$release")" || {
  echo "Latest release does not have a stable vX.Y.Z tag." >&2
  exit 1
}
version="${tag#v}"
current="$(jq -er '.version | select(type == "string" and length > 0)' "$SOURCES_FILE")"

if [[ "$version" == "$current" ]]; then
  echo "Already up to date: $tag"
  exit 0
fi

require_asset() {
  if ! jq -e --arg name "$1" '
    [.assets[] | select(.name == $name and .state == "uploaded")] | length == 1
  ' <<< "$release" > /dev/null; then
    echo "Release $tag must contain exactly one uploaded $1 asset." >&2
    exit 1
  fi
}

require_asset SHA256SUMS
checksums="$(curl "${curl_args[@]}" \
  "https://github.com/modem-dev/hunk/releases/download/$tag/SHA256SUMS")"
updated="$(jq --arg version "$version" '.version = $version' "$SOURCES_FILE")"

for system in x86_64-linux aarch64-linux x86_64-darwin aarch64-darwin; do
  name="$(jq -er --arg system "$system" '
    .[$system].name | select(type == "string" and length > 0)
  ' "$SOURCES_FILE")"
  archive="$name.tar.gz"
  require_asset "$archive"
  hash="$(awk -v archive="$archive" '$2 == archive { print $1 }' <<< "$checksums")"
  if [[ ! "$hash" =~ ^[0-9a-fA-F]{64}$ ]]; then
    echo "Missing, duplicate, or invalid SHA-256 checksum for $archive." >&2
    exit 1
  fi
  updated="$(jq --arg system "$system" --arg hash "sha256:$hash" \
    '.[$system].hash = $hash' <<< "$updated")"
done

tmp_file="$(mktemp "$ROOT/.sources.json.XXXXXX")"
trap 'rm -f "$tmp_file"' EXIT
printf '%s\n' "$updated" > "$tmp_file"
chmod 644 "$tmp_file"
mv "$tmp_file" "$SOURCES_FILE"
echo "Updated sources.json from v$current to $tag"
