#!/bin/bash
#--------------------------------------------------------------------
# Script to Install node_exporter  Ubuntu or Debian 
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

NODE_DIR="node-exporter"
#проверим установлен ли node_exporter 
if [ -d /opt/node_exporter  ] && [ -f /usr/bin/node_exporter  ]; then
        echo "node_exporter уже установлен"
        exit 0
fi

#создадим директорию и скачаем туда пакет
sudo -u "$USERNAME" mkdir /home/$USERNAME/$NODE_DIR
sudo -u "$USERNAME" wget -P /home/$USERNAME/$NODE_DIR  https://github.com/prometheus/node_exporter/releases/download/v1.8.0/node_exporter-1.8.0.linux-amd64.tar.gz
sudo -u "$USERNAME" tar -xvf /home/$USERNAME/$NODE_DIR/node_exporter-1.8.0.linux-amd64.tar.gz -C /home/$USERNAME/$NODE_DIR

#копируем бинарник в систему
cp /home/$USERNAME/$NODE_DIR/node_exporter-1.8.0.linux-amd64/node_exporter /usr/bin/
mkdir /opt/node_exporter

#напишем название ключей и сертификата
echo -e "\n====================\nНазвание ключей\n===================="
echo
read  -p "Введите имя файла сертификата: " crt
echo
read  -p "Введите имя файла ключа: " key

#копируем ключи и сертификат
cp /home/$USERNAME/$crt /opt/node_exporter/
cp /home/$USERNAME/$key /opt/node_exporter/

# сделаем хеш пароля
if ! dpkg -s apache2-utils  &> /dev/null; then
        apt-get install -y apache2-utils
fi

# запросим логин и пароль для нового репозитория
read -r -p $'\n\n'"login for Node-exporter: " node_login
read -r -p "password for Node-exporter: " -s node_pass
hash=$(htpasswd -nbB -C 10 "$node_login" "$node_pass")
two=$(echo "$hash" | cut -d ':' -f 2)

#создадим файл для настроек https
cat <<EOF> /opt/node_exporter/web.yml
tls_server_config:
  # Certificate and key files for server to use to authenticate to client.
  cert_file: $crt
  key_file: $key
basic_auth_users:
  admin: '$two'
EOF

if ! getent group node_exporter &>/dev/null; then
        addgroup --system "node_exporter" --quiet
fi

if ! getent passwd node_exporter &>/dev/null; then
        adduser --system --home /usr/share/prometheus --no-create-home --ingroup "node_exporter" --disabled-password --shell /bin/false "node_exporter"
fi

#установим права на файлы
chmod 755 /usr/bin/node_exporter
chown node_exporter:node_exporter /usr/bin/node_exporter
chmod -R 755 /opt/node_exporter/
chmod 640 /opt/node_exporter/*.crt
chmod 640 /opt/node_exporter/*.key
chown -R node_exporter:node_exporter /opt/node_exporter/

#создадим юнит для службы
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

#запустим наш экспортер
systemctl daemon-reload
systemctl restart node_exporter.service
systemctl enable node_exporter.service
#добавим правила для пропуска на порт 9100
iptables -A INPUT -p tcp --dport 9100 -j ACCEPT
#сохраним настройки iptables
service netfilter-persistent save


echo -e "\n====================\nNode Exporter listening on port 9100\n====================\n"
echo -e "\nOK\n"

