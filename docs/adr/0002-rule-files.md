# Clean targets are JSON files

Targets are data, not Swift, so contributors can add one without touching code. The loader validates every rule against the zones and fails closed. JSON was chosen over TOML or YAML because Foundation reads it and we add no dependency. Rules are bundled with the app. Loading rules from the user's disk is out for v1 because it would let a file widen what gets cleaned.
