# Safe zones

MacPat may only act on items below these folders in your home folder. The folder itself is never touched, only what is inside it.

| Zone |
| --- |
| `~/Library/Caches` |
| `~/Library/Logs` |
| `~/Library/Developer/Xcode/DerivedData` |
| `~/.npm/_cacache` |

A zone that resolves outside your home folder, through a symlink for example, is dropped.

The list lives in `Zones.standardPaths` in `Sources/MacPatCore/Zones.swift`.
