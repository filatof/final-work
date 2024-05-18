#!/bin/bash
#--------------------------------------------------------------------
# Script to Install CA easy-rsa  on Linux Ubuntu or Debian 
#
# Developed by Ivan Filatoff
#--------------------------------------------------------------------
# сохраним имя исходного пользователя
USERNAME="$SUDO_USER"
# Если имя пользователя не определено, выходим с ошибкой
if [ -z "$USERNAME" ]; then
    echo "Ошибка: не удалось определить имя пользователя."
    exit 1
fi

#если передан параметр -u то удаляем СА
if [ "$1" = "-u" ]; then
    read -p "Вы уверены, что хотите удалить СА и все файлы? (yes or no): " remove
    if [ "$remove" = 'yes' ]; then
        sudo apt-get remove easy-rsa
        sudo -u "$USERNAME" rm -r /home/$USERNAME/easy-rsa /home/$USERNAME/bin /home/$USERNAME/etc
	echo -e "\n================\nСервер СА удален\n================\n"
        exit 0
    fi
    exit 0
fi
sudo -u "$USERNAME" wget https://github.com/prometheus/node_exporter/releases/download/v1.8.0/node_exporter-1.8.0.linux-amd64.tar.gz
sudo -u "$USERNAME" tar -xvf ~/node_exporter-1.8.0.linux-amd64.tar.gz
sudo -u "$USERNAME" cd ~/node_exporter-1.8.0.linux-amd64
cp node_exporter /usr/bin/
mkdir /opt/node_exporter
cp ~/vpn.nanocorpinfra.ru.crt /opt/node_exporter/
cp ~/vpn.nanocorpinfra.ru.key /opt/node_exporter/

apt-get install -y apache2-utils
hash=$(htpasswd -nbB -C 10 admin "abkfnjd")
two=$(echo "$hash" | cut -d ':' -f 2)

cat <<EOF> /opt/node_exporter/web.yml
tls_server_config:
  # Certificate and key files for server to use to authenticate to client.
  cert_file: vpn.nanocorpinfra.ru.crt
  key_file: vpn.nanocorpinfra.ru.key
basic_auth_users:
  admin: '$two'
EOF

addgroup --system "node_exporter" --quiet
adduser --system --home /usr/share/prometheus --no-create-home --ingroup "node_exporter" --disabled-password --shell /bin/false "node_exporter"

chmod 755 /usr/bin/node_exporter
chown node_exporter:node_exporter /usr/bin/node_exporter
chmod -R 755 /opt/node_exporter/
chmod 640 /opt/node_exporter/*.crt
chmod 640 /opt/node_exporter/*.key
chown -R node_exporter:node_exporter /opt/node_exporter/

cat <<EOF> /etc/systemd/system/node_exporter.service
[Unit]
Description=Prometheus Node Exporter
Wants=network-online.target
After=network-online.target

[Service]
User=node_exporter
Group=node_exporter
Type=simple
ExecStart=/usr/bin/node_exporter --web.config.file=/opt/node_exporter/web.yml

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl restart node_exporter.service
systemctl enable node_exporter.service

iptables -A INPUT -p tcp -s monitor.nanocorpinfra.ru --dport 9100 -j ACCEPT 


