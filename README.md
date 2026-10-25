# MacPat

Pat your Mac. A small, open-source cleaner for Apple silicon.

MacPat finds files your Mac can live without and moves them to the Trash. You see what it found before anything moves. It runs on your Mac, sends nothing anywhere, and is written in Swift and SwiftUI.

**Status:** v0.1, early. Only the Clean module exists so far.

## What it does

| Module | Does | State |
| --- | --- | --- |
| Clean | App caches, logs, Xcode build files, npm cache | Works |
| Uninstall | Apps and their leftovers | Planned |
| Analyze | Where your disk space went | Planned |
| Status | CPU, memory, disk, battery | Planned |
| Optimize | Routine maintenance tasks | Planned |

## Safety

- It can only touch a short list of folders under your home folder. Everything else is refused.
- Preview comes first. Moving anything is locked until you have run one.
- Files go to the Trash. MacPat has no permanent delete.

Read the [disclaimer](docs/explanation/disclaimer.md) before you use it. This tool deletes files.

## Install

Not released yet. Build it yourself:

```sh
brew install xcodegen
xcodegen generate
open MacPat.xcodeproj
```

You need macOS 26 or later, an Apple silicon Mac, and Xcode 26 or later. Details: [build from source](docs/how-to/build-from-source.md).

## Docs

[Tutorials, how-tos, reference, and explanation](docs/README.md). Also: [privacy](PRIVACY.md), [security](SECURITY.md), [accessibility](ACCESSIBILITY.md), [colophon](COLOPHON.md), [contributing](CONTRIBUTING.md).

## License

[MIT](LICENSE). Copyright (c) 2026 Patrick Saade. MacPat is not affiliated with or endorsed by Apple. Mac and macOS are trademarks of Apple Inc.
