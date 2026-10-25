# Privacy

MacPat collects nothing and sends nothing. It has no network code, no analytics, no crash reporter, and no account.

What it reads, all on your Mac:

- File names, sizes, and dates in the folders it scans.
- Launch job files, code signatures, and the output of a few system tools. See [commands](docs/reference/commands.md).
- For Status: CPU, memory, battery, and your own processes' names and usage, every two seconds while that screen or the menu is open.

What it keeps, all on your Mac:

- `~/Library/Logs/MacPat/actions.jsonl`: one line per real run, listing what ran and how it went. Delete it whenever you like.
- Its preferences: your "Never touch" list and the projects folder you picked.

Plans you export go where you put them.

Full Disk Access is needed to see every folder. macOS asks you for it, and you can take it back at any time in System Settings. Updates will come from Homebrew, not from the app.
