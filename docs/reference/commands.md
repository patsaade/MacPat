# Commands

These are the only programs MacPat runs. Each has a fixed path and fixed arguments. The parts that vary (a label, a snapshot date, a path) must pass a strict check first. The list lives in `Command` in `Sources/MacPatCore/Exec.swift`. A test fails if a program there is missing from this page.

## Read, while scanning

| Command | Why |
| --- | --- |
| `/bin/launchctl list` | Which of your jobs are loaded. |
| `/bin/launchctl print system/<label>` | Whether a system daemon is loaded. |
| `/bin/launchctl print-disabled gui/<uid>` and `system` | Which jobs are disabled. |
| `/usr/sbin/pkgutil --pkgs`, `--files <id>` | Installer receipts for an app. |
| `/usr/bin/systemextensionsctl list` | System extensions. |
| `/usr/bin/profiles list` | Configuration profiles. |
| `/usr/bin/tmutil listlocalsnapshots /` | Local Time Machine snapshots. |
| `/usr/bin/crontab -l` | Your cron jobs. |
| `sudo /usr/bin/sfltool dumpbtm` | Login Items list. Deep Scan only, with your password. |

## Act, as plan steps

| Command | Admin |
| --- | --- |
| `/bin/launchctl bootout`, `disable`, `enable` with `gui/<uid>/<label>` | No |
| The same with `system/<label>` | Yes |
| `/bin/mv -n <file> "~/.Trash/<name> <time>-<random>"` for root-owned files | Yes |
| `/usr/bin/tmutil deletelocalsnapshots <date>` | Yes |
| `/usr/bin/dscacheutil -flushcache`, `/usr/bin/killall -HUP mDNSResponder` | Yes |
| `/usr/bin/mdutil -E /` | Yes |
| `/usr/bin/xcrun simctl delete unavailable` | No |
| `/usr/bin/qlmanage -r cache` | No |
| `/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -kill -r -domain local -domain system -domain user` | No |

Files you own go to the Trash through the system's own Trash call, not `mv`. `simctl delete unavailable` and `tmutil deletelocalsnapshots` delete for good. Nothing else does.
