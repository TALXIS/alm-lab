# Working in this repository

This is a hands-on Power Platform ALM lab. Attendees work through the checkpoint scripts in
`.lab-scripts/` (see README.md), and you may be asked to run them.

## Sign-in and merging stay with the person

- Never sign in on the person's behalf: no `gh auth login`, `txc config auth login` or
  `az login` from your own shell, and no workarounds for a command that refuses to sign in
  without a terminal. Signing in decides which accounts and environments the lab touches.
- When a script prints a line starting with `[LAB-ACTION]`, stop and relay it to the person
  word for word. For sign-in, ask them to run `.lab-scripts/lab-signin.ps1` in their own
  terminal, then re-run the checkpoint.
- When a checkpoint opens a PR and prints `[LAB-ACTION] Review and merge this PR`, the
  script waits until the person merges it on GitHub. Give them the link and keep it running
  (in the background if your command timeout is short); don't merge it yourself.
- Don't set `LAB_AUTO_MERGE` unless the person asks for unattended merging.

## Checking state

`.lab-scripts/lab-status.ps1` is read-only: it shows which checkpoints are done, whether the
sign-ins on this machine work, and which checkpoint is next. Run it before resuming.
