#!/usr/bin/env bash

# Exit if there is an error
set -e

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# If there is an .env file use it
# to set the variables
if [ -f "$SCRIPT_DIR/.env" ]; then
    source "$SCRIPT_DIR/.env"
fi

# If an IP is not set, use the machine's first IP
if [ -z "$LANCACHE_IP" ]; then
   export LANCACHE_IP=$(hostname -I | cut -d' ' -f1)
fi

# Check all required variables are set
: "${LANCACHE_IP:?must be set}"

# Get domains from `uklans/cache-domains` GitHub repo
rm -rf /tmp/lancache-cache-domains
git clone https://github.com/uklans/cache-domains.git /tmp/lancache-cache-domains

# Set the upstreams we want to create unbound config files from
declare -a UPSTREAMS=("steam")

# Create the config file
mkdir -p /tmp/lancache-dns-pfsense
CONFIG_FILE="/tmp/lancache-dns-pfsense/lancache-dns-pfsense.conf"
echo "server:" > "$CONFIG_FILE"

# Loop through each upstream file in turn
for UPSTREAM in "${UPSTREAMS[@]}"
do
    echo >> $CONFIG_FILE
    echo "# Configuration for $UPSTREAM" >> $CONFIG_FILE

    # Read the upstream file line by line
    while read -r LINE;
    do
        # Skip line if it is a comment
        if [[ ${LINE:0:1} == '#' ]]; then
            continue
        fi

        # Check if hostname is a wildcard
        if [[ $LINE == *"*"* ]]; then

            # Remove the asterix and the dot from the start of the hostname
            LINE=${LINE/#\*./}

            # Add a wildcard config line
            echo "local-zone: \"${LINE}.\" redirect" >> $CONFIG_FILE
        fi

        # Add a standard A record config line
        echo "local-data: \"${LINE}. A $LANCACHE_IP\"" >> $CONFIG_FILE

    done < /var/git/lancache-cache-domains/$UPSTREAM.txt

done

echo
echo
echo "Done!"
echo "Paste the following into Services > DNS Resolver > Custom options in pfSense:"
echo
echo
cat "$CONFIG_FILE"
echo
