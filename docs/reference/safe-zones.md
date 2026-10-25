# Safe zones

MacPat may only act on items below these folders. The folder itself is never touched, only what is inside it.

## Clean, in your home folder

`~/Library/Caches`, `~/Library/Logs`, `~/Library/Developer/Xcode/DerivedData`, `~/Library/Developer/Xcode/Archives`, `~/Library/Developer/Xcode/iOS DeviceSupport`, `~/Library/Developer/Xcode/watchOS DeviceSupport`, `~/Library/Developer/Xcode/UserData/Previews`, `~/Library/Developer/CoreSimulator/Caches`, `~/Library/Application Support/MobileSync/Backup`, `~/Library/Containers/com.apple.mail/Data/Library/Mail Downloads`, `~/Downloads`, `~/.npm/_cacache`, `~/.bun/install/cache`, `~/.cargo/registry/cache`, `~/.gradle/caches`, `~/.m2/repository`.

A zone that is a symlink, or sits behind one, is dropped.

## Other modules

- **Startup Items:** `~/Library/LaunchAgents`, `~/Library/Spotlight`, `~/Library/QuickLook`.
- **Uninstall:** the Library folders it searches, `~/Applications`, and `/Applications`.
- **Analyze:** `~/Desktop`, `~/Documents`, `~/Downloads`, `~/Movies`, `~/Music`, `~/Pictures`, `~/Developer`, `~/Public`. Only files you pick or that are big and old, and never preselected.
- **Projects in Clean:** the folder you pick, if it isn't your home folder or a system folder.

## System zones, admin only

`/Library/Caches`, `/Library/Logs`, `/Library/LaunchAgents`, `/Library/LaunchDaemons`, `/Library/PrivilegedHelperTools`, `/Library/StartupItems`, `/Library/Spotlight`, `/Library/QuickLook`, `/Library/Application Support`, `/Library/Preferences`, `/Applications`. Anything named `com.apple.*` is refused there.

## Never, in any zone

`/System`, `/usr`, `/bin`, `/sbin`, `/private/etc`, `/private/var/db`, `/Library/Apple`, `/Library/Application Support/Apple`, `/Library/Preferences/SystemConfiguration`, `/Library/Security`, `/Library/Extensions`, `/Library/SystemExtensions`, `/Applications/Utilities`, `/Applications/Safari.app`. Too broad to be a zone: `/`, `/Users`, `/Library`, `/Volumes`, `/private`, `/private/var`, `/opt`, and your home folder itself.

The lists live in `Sources/MacPatCore/Zones.swift`.
