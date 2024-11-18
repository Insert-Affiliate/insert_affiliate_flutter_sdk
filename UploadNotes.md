Internal Notes for the team for each release...a

1. Prepare release:
- Run flutter analyze and flutter test to ensure the codebase is clean and all tests pass.
- Update version in pubspec.yaml
- Update Changelog.md
- Tag & release tag in git
git tag -a v1.0.0 -m "..."
git push origin v1.0.0

- Validate the package
dart pub publish --dry-run

- Publish to pub.dev
dart pub publish

- Result visible at  https://pub.dev/packages/insert_affiliate_flutter_sdk

