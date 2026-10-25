# Delete only inside fixed zones, only to the Trash

Cleaners fail by deleting the wrong thing. MacPat checks every item against a short, hard-coded list of zones, and moves items to the Trash instead of deleting them. A blocklist was rejected because it can never be complete. Rule files can narrow what is cleaned but never widen the zones. Cost: new targets outside the zones need a code change and a test.
