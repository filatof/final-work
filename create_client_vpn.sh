#!/bin/bash

if [ $# -ne 1 ]; then
    echo «Usage: $0 --client-name»
    exit 1
fi

client_name=$1
password=«»
rm -r /tmp/keys
mkdir /tmp/keys
cd /etc/openvpn/easy-rsa
export EASYRSA_CERT_EXPIRE=1460
echo «$password» | ./easyrsa build-client-full $client_name nopass
cp pki/issued/client_name.key pki/ca.crt pki/ta.key /tmp/keys/
chmod -R a+r /tmp/keys

cat << EOF > /tmp/keys/$client_name.ovpn
client
resolv-retry infinite
nobind
remote 999.999.999.999 1194
proto udp
dev tun
comp-lzo
ca ca.crt
cert $client_name.crt
key $client_name.key
tls-client
tls-auth ta.key 1
float
keepalive 10 120
persist-key
persist-tun
tun-mtu 1500
mssfix 1620
cipher AES-256-GCM
verb 0

EOF

echo «OpenVPN client configuration file created: /tmp/keys/$client_name.ovpn»
