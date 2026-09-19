# External install request

OmniStore exposes one public desktop command for applications that need to ask
the user to install a package:

```text
omnistore install <package-id> [--source <source>]
```

`source` is optional and defaults to `native`. Accepted values are `native`
(or `pacman`), `aur`, `flatpak`, `github`, and `bitu`.

The command is a UI handoff, not an unattended installation interface.
OmniStore validates the source and package identifier, opens its own modal
confirmation with **Download** and **Cancel**, and starts the existing package
task only after the user selects **Download**. Any administrator authentication
continues through the operating-system authorization flow used by the package
backend. Callers must pass arguments directly to the executable; they must not
construct a shell command.

Each invocation currently opens a dedicated OmniStore window. Routing a request
into an already-running window requires a future single-instance IPC contract
and is not implied by this command.
