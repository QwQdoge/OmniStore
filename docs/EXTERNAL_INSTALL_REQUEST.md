> 📚 [MeoArch 主文档 / Master Doc](https://github.com/QwQdoge/MeoArch-os-workspace/blob/main/docs/MEOARCH_MASTER.md)：全部仓库地图、操作手册、Cloudflare 清单、全部文档链接。<!-- meoarch-master -->

# External installation requests

`omnistore install <package-id> [--source <source>]` opens the current native
OmniStore details page for user review. Sources: native (default; pacman is an
alias), aur, flatpak, github, bitu. Native resolves to the current platform's
native source. GitHub/Bitu identifiers use owner/repository form.

Arguments are passed directly to the executable, never through a shell command.
Unknown sources, extra options and invalid identifiers fail with exit code 2.
Parsing and opening details never install anything. The user must request an
installation plan and separately confirm it in the existing review UI. Source
availability, capabilities and authorization remain backend responsibilities;
the background transaction service owns an accepted operation.

Each invocation opens a dedicated window; single-instance routing and URL-based
installation are not provided by this command. Existing desktop URL callbacks
are not interpreted as install commands.
