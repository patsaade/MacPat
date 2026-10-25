# Add a Clean rule

A rule is one JSON file. No Swift needed.

1. Check the folder is inside a [safe zone](../reference/safe-zones.md). If it is not, the rule is rejected. Adding a zone is a code change and needs a test and a review.
2. Create `Sources/CleanKit/Rules/<id>.json`:

   ```json
   {
     "id": "my-cache",
     "name": "My cache",
     "summary": "What it is, in one line.",
     "risk": "safe",
     "paths": ["~/Library/Caches/Example"]
   }
   ```

3. Run `swift test`. The `bundledRulesAreValid` test loads every rule.

The paths are folders. MacPat cleans their children, never the folder itself.
