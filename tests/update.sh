#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FIXTURE="$(mktemp -d)"
export FIXTURE
cleanup() {
  rm -f "$FIXTURE/repo/update.sh" "$FIXTURE/repo/sources.json" \
    "$FIXTURE/original.json" "$FIXTURE/release.json" "$FIXTURE/checksums" \
    "$FIXTURE/bin/curl" "$FIXTURE/output"
  rmdir "$FIXTURE/repo" "$FIXTURE/bin" "$FIXTURE"
}
trap cleanup EXIT
mkdir "$FIXTURE/repo" "$FIXTURE/bin"
cp "$ROOT/update.sh" "$FIXTURE/repo/update.sh"
cp "$ROOT/sources.json" "$FIXTURE/original.json"

cat > "$FIXTURE/bin/curl" <<'MOCK'
#!/usr/bin/env bash
set -euo pipefail
for url; do :; done
if [[ -n "${MOCK_CURL_FAIL:-}" && "$url" == *"$MOCK_CURL_FAIL" ]]; then
  echo "Mock HTTP failure" >&2
  exit 22
fi
case "$url" in
  https://api.github.com/repos/modem-dev/hunk/releases/latest)
    cat "$FIXTURE/release.json"
    ;;
  https://github.com/modem-dev/hunk/releases/download/*/SHA256SUMS)
    cat "$FIXTURE/checksums"
    ;;
  *)
    echo "Unexpected URL: $url" >&2
    exit 1
    ;;
esac
MOCK
chmod +x "$FIXTURE/bin/curl"
export PATH="$FIXTURE/bin:$PATH"

reset_fixture() {
  cp "$FIXTURE/original.json" "$FIXTURE/repo/sources.json"
  jq --arg tag "$1" '{
    tag_name: $tag,
    draft: false,
    prerelease: false,
    assets: (
      [to_entries[] | select(.key != "version") |
        {name: (.value.name + ".tar.gz"), state: "uploaded"}]
      + [{name: "SHA256SUMS", state: "uploaded"}]
    )
  }' "$FIXTURE/original.json" > "$FIXTURE/release.json"
  local index=1 system name
  : > "$FIXTURE/checksums"
  for system in x86_64-linux aarch64-linux x86_64-darwin aarch64-darwin; do
    name="$(jq -r --arg system "$system" '.[$system].name' "$FIXTURE/original.json")"
    printf '%064d  %s.tar.gz\n' "$index" "$name" >> "$FIXTURE/checksums"
    index=$((index + 1))
  done
}

expect_failure() {
  if bash "$FIXTURE/repo/update.sh" > "$FIXTURE/output" 2>&1; then
    echo "Updater unexpectedly succeeded: $1" >&2
    cat "$FIXTURE/output" >&2
    exit 1
  fi
  cmp "$FIXTURE/original.json" "$FIXTURE/repo/sources.json"
  grep -F "$1" "$FIXTURE/output"
}

current="$(jq -r .version "$FIXTURE/original.json")"
reset_fixture "v$current"
rm "$FIXTURE/checksums"
bash "$FIXTURE/repo/update.sh"
cmp "$FIXTURE/original.json" "$FIXTURE/repo/sources.json"
echo "PASS: current release is a no-op without fetching checksums"

reset_fixture v99.0.0
bash "$FIXTURE/repo/update.sh"
jq -e '.version == "99.0.0"' "$FIXTURE/repo/sources.json" > /dev/null
index=1
for system in x86_64-linux aarch64-linux x86_64-darwin aarch64-darwin; do
  hash="$(printf '%064d' "$index")"
  jq -e --arg system "$system" --arg hash "sha256:$hash" --slurpfile original "$FIXTURE/original.json" '
    .[$system].hash == $hash and .[$system].name == $original[0][$system].name
  ' "$FIXTURE/repo/sources.json" > /dev/null
  index=$((index + 1))
done
echo "PASS: all four release pins update"

reset_fixture invalid-tag
expect_failure "stable vX.Y.Z tag"

reset_fixture v99.0.0
release="$(jq '.prerelease = true' "$FIXTURE/release.json")"
printf '%s\n' "$release" > "$FIXTURE/release.json"
expect_failure "stable vX.Y.Z tag"

reset_fixture v99.0.0
release="$(jq '.assets |= map(select(.name != "hunkdiff-linux-x64.tar.gz"))' "$FIXTURE/release.json")"
printf '%s\n' "$release" > "$FIXTURE/release.json"
expect_failure "exactly one uploaded hunkdiff-linux-x64.tar.gz asset"

reset_fixture v99.0.0
checksums="$(head -n 3 "$FIXTURE/checksums")"
printf '%s\n' "$checksums" > "$FIXTURE/checksums"
expect_failure "Missing, duplicate, or invalid SHA-256 checksum"

reset_fixture v99.0.0
first="$(head -n 1 "$FIXTURE/checksums")"
printf '%s\n' "$first" >> "$FIXTURE/checksums"
expect_failure "Missing, duplicate, or invalid SHA-256 checksum"

reset_fixture v99.0.0
printf 'not-a-hash  hunkdiff-linux-x64.tar.gz\n' > "$FIXTURE/checksums"
expect_failure "Missing, duplicate, or invalid SHA-256 checksum"

reset_fixture v99.0.0
MOCK_CURL_FAIL=/latest expect_failure "Mock HTTP failure"
MOCK_CURL_FAIL=/SHA256SUMS expect_failure "Mock HTTP failure"
echo "PASS: invalid releases and failed downloads leave sources.json unchanged"
