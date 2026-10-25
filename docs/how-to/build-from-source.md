# Build from source

You need an Apple silicon Mac on macOS 26 or later, and Xcode 26 or later.

```sh
brew install xcodegen
xcodegen generate
open MacPat.xcodeproj
```

Press Run. The project file is generated and not committed. Edit `project.yml`, not the project.

Run the tests:

```sh
swift test
scripts/check.sh
```

If code signing complains about "resource fork" or "Finder information", build outside iCloud-synced folders such as `~/Documents`, or pass `--scratch-path /tmp/macpat-build`.
