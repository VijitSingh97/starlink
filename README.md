# Starlink Hostnames

A small shell script to list devices connected to a Starlink router using its gRPC API.

## Requirements

- `bash`
- `grpcurl`
- `jq`
- Access to the Starlink router on the local network

## Usage

Run the script from the repository directory:

```bash
./get_clients.sh
```

### Sort options

- `-s hostname` (default) — sort by device hostname
- `-s ip` — sort by IP address

Example:

```bash
./get_clients.sh -s ip
```

## Configuration

By default, the script connects to `192.168.1.1:9000`. If your router uses a different address, update the `ROUTER_IP` variable inside `get_clients.sh`.

## Output

The script prints a table of connected clients with:

- Hostname
- IP address
- MAC address

## Notes

- If the router does not respond or the `grpcurl` request fails, the script will show an error.
- The script assumes the `SpaceX.API.Device.Device/Handle` gRPC service is available on the router.
