# Rule format

One JSON file per Target, in `Sources/CleanKit/Rules`.

| Field | Type | Rule |
| --- | --- | --- |
| `id` | string | 1 to 40 characters of `a-z`, `0-9`, `-`. Unique. |
| `name` | string | 1 to 60 characters. |
| `summary` | string | 1 to 120 characters. |
| `risk` | string | `safe` or `review`. |
| `paths` | array | One or more. Each starts with `~/` and sits in a [safe zone](safe-zones.md). No `..`. |

The loader fails closed. One bad rule rejects the whole set, and the Clean screen shows the reason.
