# Changelog

## 0.1.0 (2026-10-25)

First public release. Early. It works on my Mac.

### Features

* Six modules: Clean, Startup Items, Uninstall, Analyze, Status, and Optimize.
* A preview for every change. Each item shows a verdict, a reason, the facts behind it, and the exact command. Run stays locked until you preview that exact choice.
* Everything MacPat moves goes to the Trash, including root-owned files. Admin steps use the macOS password prompt each time. Every move is logged.
* Clean reads 28 JSON rule files and can scan a folder of projects for build leftovers.
* Startup Items covers launch agents and daemons, helpers, cron, login hooks, profiles, extensions, and shell startup lines. Disable, remove, or re-enable.
* Uninstall ranks leftovers by how sure the match is and finds orphaned files.
* A grid with sortable columns, a detail pane, and keyboard control. A drawn 1-bit scrollbar, motion that stops under Reduce Motion, and a Plan menu.
* Scans stream in and can be stopped. Runs report each item and can be stopped between items. A folder macOS won't let MacPat read shows as "Needs access", never as empty.
* A vector icon, a hand patting a square Mac, and a banner drawn from scratch.

### Notes

* No network code. No telemetry. No third-party code in the app.
* Not signed with a developer certificate and not notarized. Build from source.
