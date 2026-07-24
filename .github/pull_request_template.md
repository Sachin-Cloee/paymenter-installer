## Summary

Describe what changed and why.

## Impact

Explain how this affects installer users or maintainers.

## Validation

- [ ] `bash -n install.sh`
- [ ] `shellcheck install.sh`
- [ ] Tested on a clean supported server, when installer behavior changed
- [ ] Documentation updated, when needed

## Security checklist

- [ ] No credentials, tokens, private keys, `.env` contents, or personal data are included
- [ ] New downloads use HTTPS and fail safely
- [ ] Commands and user-provided values are quoted appropriately
