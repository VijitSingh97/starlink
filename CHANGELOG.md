# Changelog

## 0.0.3 - 2026-10-06

- Rebuild grpcurl with Go 1.27.1 and patched crypto dependencies.
- Bundle the patched client with Homebrew and require the rebuilt APT package.
- Add strict vulnerability scans before publishing releases.
- Remove the legacy `get_clients.sh` wrapper.

## 0.0.2 - 2026-10-06

- Add signed APT packages for Ubuntu and Debian on amd64 and arm64.
- Publish `grpcurl` in the same feed for a complete package installation.

## 0.0.1 - 2026-10-06

- Add the `starlink` command with table and JSON output.
- Support hostname or IP sorting and configurable router endpoints.
- Add Homebrew installation with Bash and Zsh completions.
