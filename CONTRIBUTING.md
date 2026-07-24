# Contributing

Thanks for helping improve Paymenter Installer.

## Before opening an issue

Search existing issues first. Use the matching issue template and include the operating system, installer command, database type, Nginx/SSL selections, and complete redacted output.

Never post passwords, tokens, private keys, `.env` contents, database credentials, or unredacted logs.

## Pull requests

1. Create a focused branch from `main`.
2. Keep unrelated changes in separate pull requests.
3. Run the checks below.
4. Explain the user impact and how the change was tested.

```bash
bash -n install.sh
shellcheck install.sh
```

Changes to installation behavior should also be tested on a clean supported Ubuntu or Debian server. Include the exact distribution version and selected installer options in the pull request.

## Style

- Use Bash features consistently with the `#!/usr/bin/env bash` shebang.
- Preserve `set -Eeuo pipefail` compatibility.
- Quote variables unless intentional word splitting is required.
- Prefer existing logging, prompting, validation, and backup helpers.
- Fail with a clear actionable message.
- Do not silently overwrite an existing installation or configuration.
- Update README and CHANGELOG when behavior changes.
