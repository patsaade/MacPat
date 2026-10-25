# How it stays safe

A cleaner is a tool that deletes things for you. So the main design goal is not deleting the wrong thing.

**A short list of zones.** MacPat does not ask "is this path dangerous?" because that list never ends. It asks "is this path in a zone I was given?" Anything else is refused.

**Paths are resolved first.** `..` is rejected outright. Parent folders are resolved, so a symlink cannot smuggle a path out of a zone. The last part of a path is not resolved, so a symlink inside a zone is moved as a link and its target is left alone.

**Checked twice.** Every item is checked when found and again right before it moves.

**Preview, then move.** The move button stays off until you have run a preview of the same selection.

**Trash, not delete.** Everything can be undone. There is no permanent delete in the code.

**Fail closed.** A bad rule, an odd path, or an error means skip. One failure never stops the others, and failures are counted and shown.

What this does not cover: a file can change between the last check and the move. That window is tiny, and the Trash makes it recoverable.
