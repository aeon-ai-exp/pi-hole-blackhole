#!/bin/bash

set -e

echo "Updating system..."
sudo apt update && sudo apt upgrade -y

echo "Installing Pi-hole..."
curl -sSL https://install.pi-hole.net | bash

echo "Installing Unbound (local recursive DNS)..."
sudo apt install unbound -y

cat <<EOF | sudo tee /etc/unbound/unbound.conf.d/pi-hole.conf
server:
    verbosity: 0
    interface: 127.0.0.1
    port: 5335
    do-ip4: yes
    do-udp: yes
    do-tcp: yes
    root-hints: "/var/lib/unbound/root.hints"
    hide-identity: yes
    hide-version: yes
    harden-glue: yes
    harden-dnssec-stripped: yes
    use-caps-for-id: no
    edns-buffer-size: 1232
    prefetch: yes
    cache-min-ttl: 3600
    cache-max-ttl: 86400
    num-threads: 1
EOF

echo "Fetching root DNS servers..."
sudo curl -o /var/lib/unbound/root.hints https://www.internic.net/domain/named.root
sudo systemctl enable unbound
sudo systemctl restart unbound

echo "Configuring Pi-hole to use Unbound..."
PIHOLE_DNS_SETTING="127.0.0.1#5335"
pihole -a setdns "$PIHOLE_DNS_SETTING"

echo "Adding curated blocklists..."
curl -sSL https://raw.githubusercontent.com/StevenBlack/hosts/master/hosts | sudo tee -a /etc/pihole/adlists.list > /dev/null
echo "https://dbl.oisd.nl/" | sudo tee -a /etc/pihole/adlists.list
echo "https://raw.githubusercontent.com/Perflyst/PiHoleBlocklist/master/SmartTV.txt" | sudo tee -a /etc/pihole/adlists.list
echo "https://raw.githubusercontent.com/hl2guide/Filterlist-for-AdGuard/master/streaming.txt" | sudo tee -a /etc/pihole/adlists.list

pihole -g

echo "Setting up weekly blocklist updates..."
(crontab -l ; echo "0 3 * * 0 /usr/local/bin/pihole updateGravity") | crontab -

echo "✅ Setup Complete!"
echo "Visit your admin dashboard at: http://$(hostname -I | awk '{print $1}')/admin"
