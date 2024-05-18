#!/bin/bash
#------------------------------------------------------------------------
# Script to Install openvpn exporter  on Linux Ubuntu or Debian
#
# Developed by Ivan Filatoff
#------------------------------------------------------------------------

# сохраним имя исходного пользователя
USERNAME="$SUDO_USER"

# Если имя пользователя не определено, выходим с ошибкой
if [ -z "$USERNAME" ]; then
    echo "Ошибка: не удалось определить имя пользователя."
    exit 1
fi

#если передан параметр uninstall то удаляем
if [ "$1" = "-u" ]; then
    read -p "Вы уверены, что хотите удалить openvpn_exporter и все файлы? (yes or no): " remove
    if [ "$remove" = 'yes' ]; then
	    systemctl stop openvpn_exporter.service
            systemctl disable openvpn_exporter.service
	    rm -f /usr/bin/openvpn_exporter
	    rm -f /etc/systemd/system/openvpn_exporter.service
	    iptables -D INPUT -p tcp --dport 9176 -j ACCEPT
	    service netfilter-persistent save
        echo -e "\n================\nexporter удален\n================\n"
        exit 0
    fi
    exit 0
fi

# Проверим установлен go  в сситему
if ! dpkg -s golang  &> /dev/null; then
	apt-get install -y golang
fi

sudo -u "$USERNAME" wget -P /home/$USERNAME/  https://github.com/kumina/openvpn_exporter/archive/refs/tags/v0.3.0.tar.gz
sudo -u "$USERNAME" tar xvf /home/$USERNAME/v0.3.0.tar.gz -C /home/$USERNAME

#В переменной openvpnStatusPaths конфигурационного файла main.go укажем путь до лога OpenVPN
sudo -u "$USERNAME" sed -i 's|examples/client.status,examples/server2.status,examples/server3.status|/var/log/openvpn/openvpn-status.log|' /home/$USERNAME/openvpn_exporter-0.3.0/main.go
#соберем программу 
go build /home/$USERNAME/openvpn_exporter-0.3.0/main.go

cp /home/$USERNAME/openvpn_exporter-0.3.0/main /usr/bin/openvpn_exporter

if ! getent group openvpn_exporter &>/dev/null; then
        addgroup --system "openvpn_exporter" --quiet
fi

if ! getent passwd openvpn_exporter &>/dev/null; then
        adduser --system --home /usr/share/openvpn_exporter --no-create-home --ingroup "openvpn_exporter" --disabled-password --shell /bin/false "openvpn_exporter"
fi

usermod -a -G openvpn_exporter root

chgrp openvpn_exporter /var/log/openvpn/openvpn-status.log
chmod 660 /var/log/openvpn/openvpn-status.log

chown openvpn_exporter:openvpn_exporter /usr/bin/openvpn_exporter
chmod 755 /usr/bin/openvpn_exporter

cat <<EOF> /etc/systemd/system/openvpn_exporter.service
[Unit]
Description=Prometheus OpenVPN Node Exporter
Wants=network-online.target
After=network-online.target

[Service]
User=openvpn_exporter
Group=openvpn_exporter
Type=simple
ExecStart=/usr/bin/openvpn_exporter

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl restart openvpn_exporter.service
systemctl enable openvpn_exporter.service

iptables -A INPUT -p tcp --dport 9176 -j ACCEPT
service netfilter-persistent save


echo -e "\n====================\nopenvpn_exporter listening on port 9176\n====================\n"
echo -e "\nOK\n"


