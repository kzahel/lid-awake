#!/usr/bin/env bash
set -euo pipefail

: "${RELEASE_TAG:?Set RELEASE_TAG, for example v0.1.0}"
: "${ASC_API_KEY_FILE:?Set ASC_API_KEY_FILE to a private .p8 path}"
: "${ASC_API_KEY_ID:?Set ASC_API_KEY_ID}"
: "${ASC_API_ISSUER_ID:?Set ASC_API_ISSUER_ID}"
: "${SPARKLE_PRIVATE_KEY_FILE:?Set SPARKLE_PRIVATE_KEY_FILE to a private seed file}"

repo_dir="$(cd "$(dirname "$0")/.." && pwd)"
cd "$repo_dir"
version="${RELEASE_TAG#v}"
configured_version="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' build/export/LidAwake.app/Contents/Info.plist 2>/dev/null || true)"
if [[ "$configured_version" != "$version" ]]; then
  echo "Built version '$configured_version' does not match tag '$RELEASE_TAG'." >&2
  exit 1
fi

app="$repo_dir/build/export/LidAwake.app"
sparkle_bin="$repo_dir/build/DerivedData/SourcePackages/artifacts/sparkle/Sparkle/bin"
artifacts="$repo_dir/build/release/$RELEASE_TAG"
mkdir -p "$artifacts" "$artifacts/appcast-input"

codesign --verify --deep --strict --verbose=2 "$app"
codesign --verify --strict --verbose=2 "$app/Contents/MacOS/LidAwakeHelper"

submission="$artifacts/notarization.zip"
ditto -c -k --keepParent "$app" "$submission"
xcrun notarytool submit "$submission" --key "$ASC_API_KEY_FILE" \
  --key-id "$ASC_API_KEY_ID" --issuer "$ASC_API_ISSUER_ID" --wait
xcrun stapler staple "$app"
xcrun stapler validate "$app"
spctl --assess --type execute --verbose=2 "$app"

update_zip="$artifacts/appcast-input/LidAwake-$RELEASE_TAG.zip"
ditto -c -k --keepParent "$app" "$update_zip"

staging="$(mktemp -d "$artifacts/dmg-staging.XXXXXX")"
ditto "$app" "$staging/Lid Awake.app"
ln -s /Applications "$staging/Applications"
dmg="$artifacts/LidAwake-$RELEASE_TAG.dmg"
hdiutil create -quiet -volname "Lid Awake" -srcfolder "$staging" -ov -format UDZO "$dmg"
codesign --force --sign 'Developer ID Application: Kyle Graehl (VD7BYQ6ABM)' "$dmg"
xcrun notarytool submit "$dmg" --key "$ASC_API_KEY_FILE" \
  --key-id "$ASC_API_KEY_ID" --issuer "$ASC_API_ISSUER_ID" --wait
xcrun stapler staple "$dmg"
xcrun stapler validate "$dmg"

"$sparkle_bin/generate_appcast" --ed-key-file "$SPARKLE_PRIVATE_KEY_FILE" \
  --download-url-prefix "https://github.com/kzahel/lid-awake/releases/download/$RELEASE_TAG/" \
  "$artifacts/appcast-input"
cp "$artifacts/appcast-input/appcast.xml" "$artifacts/appcast.xml"

echo "Release artifacts: $artifacts"
