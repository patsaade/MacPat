# Security

## Report a problem

Use GitHub's private vulnerability reporting on this repository: **Security**, then **Report a vulnerability**. Please do not open a public issue for a security bug.

I will reply within seven days. This is a one-person project, so a fix may take longer. I will say so.

## What counts

- Anything that lets MacPat delete or move a file outside its safe zones.
- Anything that makes it follow a symlink out of a safe zone.
- Anything that runs a command you did not approve.
- Any network traffic. There should be none.

## How it is built

- Deletion is limited to a short list of folders. See [how it stays safe](docs/explanation/how-it-stays-safe.md).
- Every path is checked again right before it is touched.
- Admin tasks (later) use fixed commands, never a shell string.
- No third-party code ships in the app.
- CI runs CodeQL, address and thread sanitizers, and a secrets scan on every change.

## Known limits

- A file can change between the last check and the move. The window is tiny, and the move goes to the Trash, so it can be undone.
- MacPat runs with your permissions and Full Disk Access. A bug here can touch anything you can.
