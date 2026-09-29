# Release operations

## Release command

Use `./scripts/release.sh MAJOR.MINOR.PATCH` after committing and pushing the
changes and matching changelog entry to `main`. This is the release entry point;
do not create tags or GitHub Releases by hand.

The tag supplies the release version. CI sets `MARKETING_VERSION` and
`CURRENT_PROJECT_VERSION` for the app and helper at build time, so there is no
separate version bump in `project.yml` or the Xcode project. After publishing
the artifacts, CI updates `appcast.xml`; the website workflow then rebuilds the
download links from that feed. No manual website or Graehl Arts edit is needed.

Wait for **Build and release** and the subsequent **Publish website** run to
succeed, verify that the live download points to the new DMG, then run
`git pull --ff-only` to pick up the generated feed commit. If publishing the
website fails, fix and rerun that workflow; do not create another release tag
just to refresh the site.

## Signing credentials

The release job uses a Developer ID Application certificate, an App Store Connect API key for notarization, and a Lid Awake-specific Sparkle EdDSA key. Keep private material outside this repository and provide it through GitHub Actions repository secrets. The required secret names are in [the release workflow](../.github/workflows/build.yml). Never print credential values in logs.

## Pipeline

- Push and PR: build and test without publishing.
- Before a stable release, validate the signed app on a stock macOS test environment, including Gatekeeper and helper approval, and complete the remaining [physical lid checks](VALIDATION.md). `v0.0.x` tags are prerelease test artifacts for exercising CI, installation, and Sparkle while acceptance work continues.
- Release: add a `## [VERSION]` entry to [CHANGELOG.md](../CHANGELOG.md), commit it on `main`, then run `./scripts/release.sh VERSION` without a leading `v`. The script requires a clean, current `main`, an unused version higher than the last tag, and a nonempty changelog entry before it pushes the tag.
- `v*` tag: require the matching changelog entry and all signing and notarization secrets; build with hardened runtime, run tests, verify signatures, notarize, staple, create DMG and Sparkle update ZIP, sign the update archive, stage a draft GitHub Release with those changelog notes, then publish it and the appcast after those checks pass.

The release job installs `dmgbuild==1.6.7` in a Python virtual environment. Its layout is in [`scripts/dmg-settings.py`](../scripts/dmg-settings.py), with the editable background in [`Resources/dmg-background.svg`](../Resources/dmg-background.svg) and its rendered PNG beside it. If the background changes, regenerate the PNG with `sips -s format png Resources/dmg-background.svg --out Resources/dmg-background.png` before packaging.

The appcast is served at a stable HTTPS URL from the default branch through `raw.githubusercontent.com`. CI publishes it only after the GitHub Release is public; archives remain GitHub Release assets. The updater public key is embedded in the app. A published version must never be replaced in place.

Tags use `vMAJOR.MINOR.PATCH`; CI maps them to monotonic Sparkle build numbers (`major * 1,000,000 + minor * 1,000 + patch`).

## Verify a downloaded release

Mount the DMG and copy `Lid Awake.app` to `/Applications`, then check its signature, Gatekeeper assessment, and stapled ticket:

```sh
codesign --verify --deep --strict --verbose=2 '/Applications/Lid Awake.app'
spctl -a -vvv -t exec '/Applications/Lid Awake.app'
xcrun stapler validate '/Applications/Lid Awake.app'
```

Sparkle replacement from 0.0.4 to 0.0.5 was tested in the VM with a previously approved helper. The new app detected that the registered helper was stale, **Repair Helper…** registered the new helper, and the helper toggled the sleep setting afterward without a new password prompt in that VM. Scheduled daily update discovery has not been observed through a full interval. CI success alone does not establish the behavior of an installed update.

## Website and download link

The landing page lives at `https://kzahel.github.io/lid-awake/`. Share
`https://kzahel.github.io/lid-awake/download/` for a permanent download address.
That page redirects to the exact published DMG and includes a clickable fallback.
The landing page's main button links directly to the DMG.

`python3 scripts/build-website.py` generates `build/website/` from `website/` and
`appcast.xml`, using only the Python standard library. Preview with
`python3 -m http.server 8000 --directory build/website`.
The highest Sparkle build number supplies the version and minimum macOS version;
the DMG and ZIP share the naming convention in `scripts/package-release.sh`.
The build fails if the feed's URL no longer follows that convention. Versions
`0.0.x` are labeled previews, matching the release workflow. The site follows
the same release pointer as the in-app updater, including these previews.

Enable GitHub Pages once under **Settings → Pages → Source → GitHub Actions**.
The `Publish website` workflow deploys changes to the website and feed, can be
run manually, and also runs after a successful push-triggered `Build and release`
workflow. This last trigger is needed because the release job's `GITHUB_TOKEN`
push of `appcast.xml` does not itself trigger a push workflow. The website job
always checks out `main`; it does not execute code from pull requests.

There is no visitor-side GitHub API call, API pagination, or update-server dependency.
A failed deployment leaves the previous website in place; rerun `Publish website`
after fixing the failure. Verify its download target against the published release
before sharing the site. Generated files remain under the ignored `build/` directory.
