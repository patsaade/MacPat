# MacPat

A cleaner for Mac. These are the words the code and docs use.

## Language

**Module**:
One feature of the app, such as Clean. It owns a menu bar title and a screen.
_Avoid_: Plugin, feature, tool

**Target**:
A named group of folders to clean, defined by a rule file. Its children are the items.
_Avoid_: Category, job

**Rule**:
The JSON file that defines a Target.
_Avoid_: Config, preset

**Zone**:
A folder MacPat is allowed to delete from. Everything outside every Zone is refused.
_Avoid_: Allowlist, whitelist, scope

**System Zone**:
A Zone outside the home folder, such as `/Library/LaunchDaemons`. Only admin steps act there.
_Avoid_: Root zone

**Item**:
One file or folder found inside a Target, with its size.
_Avoid_: Entry, result

**Scan**:
Looking for Items. It reads. It never changes anything.
_Avoid_: Search, crawl

**Step**:
One thing a module would do, with its Verdict, reason, and facts. Moving a file, stopping a job, and running a Command are all Steps.
_Avoid_: Task, action, operation

**Plan**:
The chosen Steps, frozen, with a fingerprint.
_Avoid_: Job, batch, queue

**Verdict**:
How sure MacPat is that a Step is harmless: safe, review, or locked. Locked Steps never run.
_Avoid_: Score, rating, severity

**Command**:
One program from the allowlist, with fixed arguments.
_Avoid_: Script, shell command

**Preview**:
A dry run of a Plan. It checks every Step and runs none. A real run must match it.
_Avoid_: Simulate, test run

**Persistence item**:
Anything that starts on its own: a launch job, a helper, a cron line, a hook, a plugin, and so forth.
_Avoid_: Startup item, autorun, login item

**Orphan**:
A Persistence item whose program is gone, or a Library file named for an app that is no longer installed.
_Avoid_: Leftover, junk

**Leftover**:
A file outside an app's bundle that belongs to that app.
_Avoid_: Remnant, residue, junk

**Unusual**:
A Persistence item with traits worth a look, such as being unsigned or running from a hidden folder. Not a finding of harm.
_Avoid_: Suspicious, malicious, threat

**Clean**:
Moving the chosen Items to the Trash.
_Avoid_: Delete, wipe, purge
