#!/bin/bash

ROUTER_IP="192.168.1.1:9000"
SORT_BY="hostname" # Default sort method

# Parse command line arguments
while [[ "$#" -gt 0 ]]; do
    case $1 in
        -s|--sort)
            SORT_BY=$(echo "$2" | tr '[:upper:]' '[:lower:]')
            shift
            ;;
        -h|--help)
            echo "Usage: $0 [-s|--sort <hostname|ip>]"
            exit 0
            ;;
        *)
            echo "Unknown parameter: $1"
            echo "Usage: $0 [-s|--sort <hostname|ip>]"
            exit 1
            ;;
    esac
    shift
done

# Validate sort argument
if [[ "$SORT_BY" != "hostname" && "$SORT_BY" != "ip" ]]; then
    echo "Error: Sort parameter must be 'hostname' or 'ip'."
    exit 1
fi

# Fetch and parse the raw tab-separated data
RAW_DATA=$(grpcurl -plaintext -d '{"getStatus": {}}' "$ROUTER_IP" SpaceX.API.Device.Device/Handle 2>/dev/null \
  | jq -r '.wifiGetStatus.clients[]? | [(.name // "(Unknown)"), (.ipAddress // "(No IP)"), (.macAddress // "(No MAC)")] | @tsv')

if [ -z "$RAW_DATA" ]; then
    echo "Error: No data returned or unable to connect to router at $ROUTER_IP."
    exit 1
fi

# Sort the data based on the chosen column
if [ "$SORT_BY" = "ip" ]; then
    # -k2,2 sorts by the 2nd column (IP). -V ensures natural/version sorting.
    SORTED_DATA=$(echo "$RAW_DATA" | sort -t $'\t' -k2,2 -V)
else
    # Default: sort by 1st column (hostname). -f makes it case-insensitive.
    SORTED_DATA=$(echo "$RAW_DATA" | sort -t $'\t' -k1,1 -f)
fi

# Output formatting
echo "Fetching connected clients from Starlink Router ($ROUTER_IP)..."
echo "Sorted by: $SORT_BY"
echo "------------------------------------------------------------------"
printf "%-30s | %-15s | %-17s\n" "Hostname" "IP Address" "MAC Address"
echo "------------------------------------------------------------------"

echo "$SORTED_DATA" | while IFS=$'\t' read -r name ip mac; do
    # Skip empty lines
    [ -z "$name" ] && continue
    printf "%-30s | %-15s | %-17s\n" "$name" "$ip" "$mac"
done