# Release checklist

## Before tagging

- [ ] Confirm `main` contains only intended changes
- [ ] Run `bash -n install.sh`
- [ ] Run `shellcheck install.sh`
- [ ] Complete a clean-server installation on at least one supported Ubuntu release
- [ ] Complete a clean-server installation on at least one supported Debian release
- [ ] Test local and remote database setup
- [ ] Test Nginx with and without SSL
- [ ] Test the domain-change command
- [ ] Confirm backups are created before replacement
- [ ] Update README and CHANGELOG

## Release format

Use semantic tags such as `v1.0.0`.

Document the main changes, tested operating systems, known limitations, upgrade notes, and a SHA-256 checksum for `install.sh`.

```bash
sha256sum install.sh
```

Users who need reproducible deployments should download a tagged version rather than executing the moving `main` branch.
