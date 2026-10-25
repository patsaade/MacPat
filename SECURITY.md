# Security

## Report a problem

Use GitHub's private vulnerability reporting on this repository: **Security**, then **Report a vulnerability**. Please do not open a public issue for a security bug.

I will reply within seven days. This is a one-person project, so a fix may take longer. I will say so.

## What counts

- Anything that lets MacPat delete or move a file outside its safe zones.
- Anything that makes it follow a symlink out of a safe zone.
- Anything that runs a command you did not approve, or one not on the [command list](docs/reference/commands.md).
- Anything that gets text from a file name, plist, or tool output into an admin command.
- A real run that does something its preview did not show.
- Any network traffic. There should be none.

## How it is built

- Deletion is limited to a short list of folders. See [how it stays safe](docs/explanation/how-it-stays-safe.md).
- Every path is checked again right before it is touched.
- A real run must match the fingerprint of its preview.
- Only one file may start processes. Commands are fixed programs with checked arguments.
- Admin steps use the macOS password prompt each time. There is no privileged helper.
- No third-party code ships in the app.
- CI runs CodeQL, address and thread sanitizers, and a secrets scan on every change.

## Known limits

- A file can change between the last check and the move. The window is tiny, and the move goes to the Trash, so it can be undone.
- MacPat runs with your permissions and Full Disk Access. A bug here can touch anything you can.
- Admin steps run through `osascript`, which uses `sh`. Arguments are pattern-checked and quoted. See [why admin uses the system prompt](docs/explanation/why-admin-uses-the-system-prompt.md).
