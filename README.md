# starlink

[![CI](https://github.com/VijitSingh97/starlink/actions/workflows/ci.yml/badge.svg)](https://github.com/VijitSingh97/starlink/actions/workflows/ci.yml)
[![Release](https://img.shields.io/github/v/release/VijitSingh97/starlink)](https://github.com/VijitSingh97/starlink/releases)

`starlink` lists devices connected to a Starlink router from the command line.
It makes a read-only request to the router's local gRPC API and prints a table or
normalized JSON.

## Install

With [Homebrew](https://brew.sh/):

```sh
brew tap vijitsingh97/starlink https://github.com/VijitSingh97/starlink.git
brew install vijitsingh97/starlink/starlink
```

On Homebrew versions that require tap trust, run
`brew trust --formula vijitsingh97/starlink/starlink` after tapping and before
installing.

Homebrew installs `grpcurl` and `jq` automatically. The command supports macOS
and Linux with Bash 3.2 or newer. Homebrew is the supported installation method.

## Usage

Connect to the Starlink router's Wi-Fi or wired network, then run:

```sh
starlink
```

The default router is `192.168.1.1:9000`, and clients are sorted by hostname.

```text
Usage: starlink [options]

List Starlink router clients with hostname, IP address, and MAC address.

Options:
  -s, --sort hostname|ip   Sort clients (default: hostname)
      --router HOST:PORT  Router gRPC endpoint (default: 192.168.1.1:9000)
      --json              Print a sorted JSON array of hostname/ip/mac objects
  -h, --help              Show this help
  -V, --version           Show the version

STARLINK_ROUTER sets the default endpoint. --router takes precedence.
```

Set a different router for one command or as an environment default:

```sh
starlink --router router.local:9000 --sort ip
STARLINK_ROUTER=router.local:9000 starlink --json
```

`--router` accepts `HOST:PORT` or `[IPv6]:PORT`, with a port from 1 to 65535.
The command-line option takes precedence over `STARLINK_ROUTER`.

JSON output is a sorted array whose objects contain `hostname`, `ip`, and `mac`:

```json
[
  {
    "hostname": "laptop",
    "ip": "192.168.1.24",
    "mac": "00:11:22:33:44:55"
  }
]
```

Missing, null, or empty client fields become `(Unknown)`, `(No IP)`, and
`(No MAC)`. An omitted, null, or empty client list succeeds and reports zero
clients. Malformed response shapes and non-string client fields fail with an
error.

## Shell completion

Completions suggest options and sort values. Homebrew installs both Bash and Zsh
completion files. If your shell does not already load them, add the following
to its configuration and open a new terminal.

For Bash, in `~/.bashrc` (or the startup file your Bash shell loads):

```sh
source "$(brew --prefix)/etc/bash_completion.d/starlink"
```

For Zsh, in `~/.zshrc`, put the completion directory before your existing
`compinit` call, or add these lines if completion is not enabled yet:

```sh
fpath=("$(brew --prefix)/share/zsh/site-functions" $fpath)
autoload -Uz compinit
compinit
```

## Router compatibility

`starlink` uses gRPC server reflection to call
`SpaceX.API.Device.Device/Handle` with `{"getStatus":{}}`, then reads
`wifiGetStatus.clients`. Compatibility depends on the router's local API and
server reflection; firmware updates may change or remove them. This command
lists clients reported by the Starlink router, so it cannot list devices managed
by a third-party router in [bypass mode](https://starlink.com/ai/support/article/a0fe8d51-32f7-d2b9-d74a-801e31ad9f6a).

The request is sent in plaintext to the selected local router and has a
10-second timeout. It reads status only; it does not change router settings or
send client data to an external service.

## Project

The original `star-link-hostnames` repository was renamed to `starlink`.
Existing source checkouts can still use `get_clients.sh`, which forwards to the
new command. Homebrew installs the `starlink` command.

This independent project is not affiliated with, endorsed by, or supported by
Starlink or SpaceX. Licensed under the [MIT License](LICENSE).

## Development

Tests use a fake `grpcurl` in an isolated `PATH`; they never contact a router.
With `jq` and Python 3 available, run `make check test`. CI also runs ShellCheck
and verifies installation and completion on macOS and Linux.
