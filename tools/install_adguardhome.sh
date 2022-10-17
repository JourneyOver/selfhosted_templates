# Set adguard service as default 53 DNS service on host
sudo mkdir -vf /etc/systemd/resolved.conf.d
echo "[Resolve]
DNS=127.0.0.1
DNSStubListener=no" > /etc/systemd/resolved.conf.d/adguardhome.conf

sudo mv /etc/resolv.conf /etc/resolv.conf.backup
sudo ln -s /run/systemd/resolve/resolv.conf /etc/resolv.conf

sudo systemctl reload-or-restart systemd-resolved
