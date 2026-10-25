# What MacPat won't do

Some features are common in cleaners. MacPat leaves them out on purpose.

- **Empty the Trash.** That is the one permanent step, and it stays yours.
- **Strip language files or slim universal apps.** Both break the app's code signature. macOS may then refuse to open it, and the next update puts everything back anyway.
- **"Free up memory."** macOS uses spare memory as cache on purpose. Purging it makes the next few minutes slower.
- **Run the old maintenance scripts.** macOS schedules what it still needs.
- **Edit shell startup files or remove login window plugins.** A wrong line there can break your shell or your login. MacPat shows them and says how to fix them by hand.
- **Promise a faster Mac.** Cleaning mostly gets space back. Speed rarely changes.
