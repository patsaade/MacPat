# Persistence locations

Where Startup Items looks, and what it can do there.

| Place | Path | MacPat can |
| --- | --- | --- |
| Your login agents | `~/Library/LaunchAgents` | Disable, remove |
| Login agents for every user | `/Library/LaunchAgents` | Disable, remove (admin) |
| System daemons | `/Library/LaunchDaemons` | Disable, remove (admin) |
| Inside apps | `<app>/Contents/Library/LaunchAgents`, `LaunchDaemons` | Show. Turn off in System Settings. |
| Part of macOS | `/System/Library/LaunchAgents`, `LaunchDaemons` | Show, with **Show Apple items** |
| Privileged helpers | `/Library/PrivilegedHelperTools` | Remove (admin) |
| Startup items | `/Library/StartupItems` | Remove (admin) |
| Spotlight importers | `~/Library/Spotlight`, `/Library/Spotlight` | Remove |
| Quick Look plugins | `~/Library/QuickLook`, `/Library/QuickLook` | Remove |
| Login and logout hooks | `com.apple.loginwindow` preferences | Show |
| Cron | `crontab -l` | Show |
| Configuration profiles | `profiles list` | Show |
| System extensions | `systemextensionsctl list` | Show |
| Kernel extensions | `/Library/Extensions` | Show |
| Authorization plugins | `/Library/Security/SecurityAgentPlugins` | Show |
| Directory service plugins | `/Library/DirectoryServices/PlugIns` | Show |
| Shell startup lines | `~/.zshrc`, `~/.zprofile`, `~/.zshenv`, `~/.zlogin`, `~/.bash_profile`, `~/.bashrc`, `~/.profile`, `~/.config/fish/config.fish` | Show odd lines |
| Login Items list | `sfltool dumpbtm` (Deep Scan) | Show |

"Show" places explain how to remove the item by hand. Those are places where a wrong move can lock you out or break an install.
