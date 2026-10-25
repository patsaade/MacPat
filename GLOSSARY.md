# MacPat

A cleaner for Mac. These are the words the code and docs use.

## Language

**Module**:
One feature of the app, such as Clean. It owns a sidebar entry and a screen.
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

**Item**:
One file or folder found inside a Target, with its size.
_Avoid_: Entry, result

**Scan**:
Looking for Items. It reads. It never changes anything.
_Avoid_: Search, crawl

**Preview**:
A dry run of the cleanup. It checks every Item and moves none.
_Avoid_: Simulate, test run

**Clean**:
Moving the chosen Items to the Trash.
_Avoid_: Delete, wipe, purge
