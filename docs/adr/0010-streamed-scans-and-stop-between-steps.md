# Scans stream and runs stop between steps

A scan reports each target as it finishes and can be stopped. A real run reports each step and can be stopped before the next one. Rows appear in the order of the rules, whatever order the targets finish in. Folders macOS guards, such as Mail and Downloads, are scanned last, so a permission prompt never holds up the rest. A folder that exists but can't be read is shown as a locked "Needs access" row, never as empty.

A step that has started always finishes. Stop never interrupts a move, and a stopped run says how many items did not run. The plan fingerprint and the per-step checks are unchanged. Rejected: killing a running step, which could leave a half-moved folder. Cost: stopping can lag by one step.
