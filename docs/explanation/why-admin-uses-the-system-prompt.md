# Why admin uses the system prompt

Some steps need root, such as removing a system daemon or deleting a local snapshot. There are two common ways to get root from an app.

The first is a privileged helper: a small program installed once that runs as root and takes requests. It is convenient, and it sits there between runs as a standing target. For a tool you open a few times a year, I would say that trade is wrong.

The second is asking macOS each time. MacPat does this. It hands one fixed command to `osascript` with `with administrator privileges`, so macOS shows its own password prompt. macOS runs that line through `sh` as root. That is the one place a shell is involved, so the line is built carefully:

- The program and its arguments come from the allowlist, never from text you or a file typed.
- Every argument that varies has already matched a strict pattern, such as a label of letters, digits, dots, dashes, and underscores.
- Every argument is single-quoted for the shell, then escaped for AppleScript.

The prompt says `osascript` wants to make changes, not MacPat. That is how macOS labels it. macOS remembers your password for a few minutes, so a plan with several admin steps usually asks once.
