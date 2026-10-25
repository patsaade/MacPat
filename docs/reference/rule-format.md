# Rule format

One JSON file per Target, in `Sources/CleanKit/Rules`. Files load in name order.

| Field | Type | Rule |
| --- | --- | --- |
| `id` | string | 1 to 40 characters of `a-z`, `0-9`, `-`. Unique. |
| `name` | string | 1 to 60 characters. |
| `summary` | string | 1 to 120 characters. |
| `risk` | string | `safe` or `review`. Never `locked`. |
| `paths` | array | Folders whose children are the items. `~/` paths must sit in a [safe zone](safe-zones.md). Empty only with `command`. |
| `group` | string | Optional. The heading in Clean. |
| `reason` | string | Optional. Why removing it is fine. Defaults to `summary`. |
| `regenerates` | string | Optional. What it costs to get back. |
| `match` | array | Optional. Filename globs such as `*.dmg`. Names only, no `/`. |
| `exclude` | array | Optional. Filename globs to skip. |
| `minAgeDays` | number | Optional. Only children unmodified this long. 0 to 3650. |
| `scope` | string | Optional. `user` (default) or `system`. System paths are absolute, sit in a system zone, and need admin. |
| `preselect` | bool | Optional. Ticked after a scan. Defaults to true for `safe`. |
| `command` | string | Optional. A named command instead of moving files. Only `simctl-delete-unavailable` exists. |

The loader fails closed. One bad rule rejects the whole set, and the Clean screen shows the reason.
