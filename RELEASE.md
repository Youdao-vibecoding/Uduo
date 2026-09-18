# Release Uduo

The default release path creates an ad-hoc signed app and disk image on a Mac. It does not notarize them and does not publish to GitHub. Never describe this output as Developer ID signed or Apple-notarized.

## Prepare the version

Set `CFBundleShortVersionString` and `CFBundleVersion` in `Info.plist`. Keep the README and [release notes](docs/RELEASE_NOTES.md) consistent with the version, compatibility requirements, and actual signing status. Run the relevant checks in [CHECKS.md](CHECKS.md).

For 1.0.0, the release assets are:

- `Uduo-1.0.0-arm64.dmg`
- `Uduo-1.0.0-arm64.dmg.sha256`

## Build the artifacts

```sh
bash scripts/build.sh
bash scripts/package.sh --skip-build
```

The application is `dist/Uduo.app`. Packaging reads its version from `Info.plist` and places the DMG and SHA-256 file in `dist/`. Running `bash scripts/package.sh` builds first; `bash scripts/release.sh` uses the same packaging path. These scripts do not push commits, create releases, or accept `--publish`.

Inspect the packaged app, its installation instructions, and the Applications shortcut. Verify the final files:

```sh
codesign --verify --deep --strict dist/Uduo.app
hdiutil verify dist/Uduo-1.0.0-arm64.dmg
cd dist
shasum -a 256 -c Uduo-1.0.0-arm64.dmg.sha256
```

An ad-hoc signature can pass bundle verification while still being blocked by Gatekeeper. That is why the README and release notes state the signing limitation and link to Apple's normal Privacy & Security opening flow.

## Optional Developer ID release

A maintainer with their own Developer ID Application certificate and a saved `notarytool` credential profile can use the signed release path:

```sh
CODE_SIGN_IDENTITY='Developer ID Application: Your Name (TEAMID)' \
NOTARY_PROFILE='your-saved-notary-profile' \
bash scripts/release.sh
```

Use credentials owned by the publisher. Do not reuse upstream certificate names, team identifiers, update keys, or release destinations. Successful notarization must be verified for the final application and disk image before changing the public signing statement. Regenerate the checksum after the final stapling step.

Uduo 1.0.0 uses the default ad-hoc path. This optional procedure does not imply that the current release is notarized.

## Publish deliberately

Review the staged source and final artifacts for private paths, local logs, credentials, and unrelated files. Confirm that the interface previews in `docs/preview.png` and `docs/preview-en.png` match the shipped controls and are labeled as previews. Preserve [LICENSE](LICENSE) in the source and application.

Publishing is a separate maintainer action. After confirming that the Git remote points to the Uduo repository, create the version tag and upload the DMG and matching checksum with [docs/RELEASE_NOTES.md](docs/RELEASE_NOTES.md) as the release body. The repository description and topic suggestions are in [docs/GITHUB_METADATA.md](docs/GITHUB_METADATA.md).

Uduo has no automatic updater or appcast. A new GitHub release is a manual download, not an update pushed to installed applications.
