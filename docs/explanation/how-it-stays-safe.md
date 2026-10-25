# How it stays safe

A cleaner deletes things for you, so the main design goal is not deleting the wrong thing.

**Short lists, not a blocklist.** MacPat doesn't ask "is this path dangerous?" because that list never ends. It asks "is this path in a zone I was given?" and "is this command on my list?" Anything else is refused. See [safe zones](../reference/safe-zones.md) and [commands](../reference/commands.md).

**Paths are resolved first.** `..` and control characters are rejected outright. Parent folders are resolved, so a symlink can't smuggle a path out of a zone. The last part isn't resolved, so a symlink inside a zone is moved as a link and its target is left alone.

**The preview is the plan.** A preview records a fingerprint of the exact steps, including each file's identity on disk. Run sends that fingerprint along. If the choice changed, or a file was swapped for a different one or a link, the run is refused before any step runs.

**Checked twice.** Every step is checked when found and again right before it runs. Each step in a sequence is checked before the first one runs.

**Trash, not delete.** MacPat never deletes a file itself. Root-owned files go into your Trash, too, under a name nobody can guess ahead of time. Two optional commands delete by design: removing unavailable simulators and deleting local snapshots. Their steps say so.

**One door for processes.** Only `Exec.swift` may start a process, and CI fails if anything else tries. It runs programs by absolute path with a fixed argument list and a clean environment. No shell, except the one macOS uses behind its own admin prompt. See [why admin uses the system prompt](why-admin-uses-the-system-prompt.md).

**Fail closed.** A bad rule, an odd path, or an error means skip. One failure never stops the others. Failures are listed with their reason.

**A record.** Every real run appends one line to `~/Library/Logs/MacPat/actions.jsonl`. It lists what ran and how it went. It stays on your Mac.

What this doesn't cover: a file can change in the instant between the last check and the move. The fingerprint narrows that window, and the Trash makes it recoverable.
