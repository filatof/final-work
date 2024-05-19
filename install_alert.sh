#!/bin/bash
#--------------------------------------------------------------------
# Script to Install AlertManager  Ubuntu or Debian 
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

#если передан параметр -u то удаляем 
if [ "$1" = "-u" ]; then
    read -p "Вы уверены, что хотите удалить node_exporter  и все файлы? (yes or no): " remove
    if [ "$remove" = 'yes' ]; then
         systemctl stop node_exporter.service
         systemctl disable node_exporter.service
	 rm /usr/bin/node_exporter
         rm -rf /opt/node_exporter/
         rm /etc/systemd/system/node_exporter.service
         sudo -u "$USERNAME" rm -rf ~/node-exporter/
         iptables -D INPUT -p tcp --dport 9100 -j ACCEPT
         service netfilter-persistent save
         echo -e "\n================\nexporter удален\n================\n"
         exit 0
    fi
    exit 0
fi

NODE_DIR="alertmanager"
#проверим установлен ли node_exporter 
if  [ -f /usr/bin/alertmanager  ]; then
        echo "Alertmanager уже установлен"
        exit 0
fi

#создадим директорию и скачаем туда пакет
sudo -u "$USERNAME" mkdir /home/$USERNAME/$NODE_DIR
sudo -u "$USERNAME" wget -P /home/$USERNAME/$NODE_DIR https://github.com/prometheus/alertmanager/releases/download/v0.27.0/alertmanager-0.27.0.linux-amd64.tar.gz
sudo -u "$USERNAME" tar -xvf /home/$USERNAME/$NODE_DIR/alertmanager-0.27.0.linux-amd64.tar.gz -C /home/$USERNAME/$NODE_DIR

#копируем бинарник в систему
cp /home/$USERNAME/$NODE_DIR/alertmanager-0.27.0.linux-amd64/alertmanager /usr/bin/
cp /home/$USERNAME/$NODE_DIR/alertmanager-0.27.0.linux-amd64/amtool /usr/bin/
cp /home/$USERNAME/$NODE_DIR/alertmanager-0.27.0.linux-amd64/alertmanager.yml /etc/prometheus/
ln -s /usr/bin/amtool /usr/local/bin/amtool
ln -s /usr/bin/alertmanager /usr/local/bin/alertmanager

mkdir /etc/prometheus/alertmanager_data
touch /etc/prometheus/rules.yml

chown -R prometheus:prometheus /etc/prometheus/alertmanager_data
chmod -R 755 /etc/prometheus/alertmanager_data
chown prometheus:prometheus /usr/bin/amtool
chown -h prometheus:prometheus /usr/local/bin/amtool
chmod 755 /usr/bin/amtool
chown prometheus:prometheus /usr/bin/alertmanager
chown -h prometheus:prometheus /usr/local/bin/alertmanager
chmod 755 /usr/bin/alertmanager
chown prometheus:prometheus /etc/prometheus/alertmanager.yml 
chmod 755 /etc/prometheus/alertmanager.yml
chown prometheus:prometheus /etc/prometheus/rules.yml
chmod 755 /etc/prometheus/rules.yml


cat <<EOF> /etc/systemd/system/prometheus-alertmanager.service
[Unit]
Description=Alertmanager Service
After=network.target

[Service]
EnvironmentFile=-/etc/default/alertmanager
User=prometheus
Group=prometheus
Type=simple
ExecStart=/usr/bin/alertmanager \$ARGS --config.file=/etc/prometheus/alertmanager.yml --web.config.file=/etc/prometheus/web.yml --storage.path=/etc/prometheus/alertmanager_data
ExecReload=/bin/kill -HUP \$MAINPID
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl restart prometheus-alertmanager.service
systemctl enable prometheus-alertmanager.service

#добавим правила для пропуска на порт 9093
iptables -A INPUT -p tcp --dport 9093 -j ACCEPT
#сохраним настройки iptables
service netfilter-persistent save


echo -e "\n====================\nNode Exporter listening on port 9100\n====================\n"
echo -e "\nOK\n"

