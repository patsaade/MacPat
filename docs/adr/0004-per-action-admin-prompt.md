# Admin tasks use a prompt per action, not a helper

Optimize tasks that need admin rights will ask macOS for authorization each time and run a fixed list of commands. A resident privileged helper was rejected: it is a standing attack surface for a tool that runs rarely. Built as described in [0006](0006-command-allowlist-and-osascript-admin.md).
