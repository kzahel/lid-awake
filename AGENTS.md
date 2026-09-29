# Lid Awake

## Releases

- Use `./scripts/release.sh MAJOR.MINOR.PATCH` for releases, without a leading
  `v`. Do not create release tags or GitHub Releases by hand.
- Read [docs/RELEASE.md](docs/RELEASE.md) before releasing. Add a matching
  `## [MAJOR.MINOR.PATCH]` section with release notes to `CHANGELOG.md`, then
  commit and push the intended changes to `main`. The script requires a clean
  working tree, `main` matching `origin/main`, and a new version above prior tags.
- The tag is the release version source. CI sets the app and helper versions
  and Sparkle build number from it; do not bump `project.yml` or the Xcode
  project just to make a release.
- CI builds, tests, signs, notarizes, publishes the DMG and update ZIP, then
  commits the generated `appcast.xml`. Do not hand-edit the feed or download
  URLs. The website workflow reads that feed and automatically updates both
  the landing-page button and `/lid-awake/download/` after the release workflow
  succeeds. No per-release change to the Graehl Arts site is needed.
- Before reporting a release complete, verify that both `Build and release`
  and the subsequent `Publish website` run succeeded, and that the live site's
  download points to that release's DMG. Pull the CI-generated feed commit with
  `git pull --ff-only` before starting the next release.
- `0.0.x` versions are previews. Complete the acceptance checks in
  [docs/VALIDATION.md](docs/VALIDATION.md) before a stable release. Never replace
  a published version in place.
