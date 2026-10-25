# Add a Clean rule

A rule is one JSON file. No Swift needed.

1. Check the folder is inside a [safe zone](../reference/safe-zones.md). If it is not, the rule is rejected. Adding a zone is a code change and needs a test and a review.
2. Create `Sources/CleanKit/Rules/<id>.json`:

   ```json
   {
     "id": "my-cache",
     "group": "Package caches",
     "name": "My cache",
     "summary": "What it is, in one line.",
     "risk": "safe",
     "paths": ["~/Library/Caches/Example"],
     "reason": "Why removing it is fine.",
     "regenerates": "What it costs to get back."
   }
   ```

3. Run `swift test`. The `bundledRulesAreValid` test loads every rule.

All fields are in the [rule format](../reference/rule-format.md). The reason and the cost to get it back are what people read in the preview, so write them plainly.

The paths are folders. MacPat cleans their children, never the folder itself.
