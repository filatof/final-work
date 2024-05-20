#!/bin/bash
#------------------------------------------------------------------------
# Script to Install Prometheus  on Linux Ubuntu or Debian
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
    read -p "Вы уверены, что хотите удалить prometheus  и все файлы? (yes or no): " remove
    if [ "$remove" = 'yes' ]; then
        systemctl stop prometheus.service
        systemctl desable prometheus.service
        rm -rf /etc/prometheus/
	rm -rf /etc/systemd/system/prometheus.service
	iptables -D INPUT -p tcp --dport 9090 -j ACCEPT
	# сохраним правила iptables
        netfilter-persistent save
        echo -e "\n================\nPrometheus удален\n================\n"
        exit 0
    fi
    exit 0
fi


sudo -u "$USERNAME" wget -P /home/$USERNAME https://github.com/prometheus/prometheus/releases/download/v2.52.0/prometheus-2.52.0.linux-amd64.tar.gz
sudo -u "$USERNAME" tar xvf /home/$USERNAME/prometheus-2.52.0.linux-amd64.tar.gz -C /home/$USERNAME 
sudo -u "$USERNAME" cd /home/fill/prometheus-2.52.0.linux-amd64
cp prometheus /usr/bin/
cp promtool /usr/bin/
ln -s /usr/bin/prometheus /usr/local/bin/prometheus
ln -s /usr/bin/promtool /usr/local/bin/promtool
mkdir /etc/prometheus
cp prometheus.yml /etc/prometheus
cp -r consoles /etc/prometheus
cp -r console_libraries /etc/prometheus
mkdir /var/lib/prometheus

################
#напишем название ключей и сертификата
echo -e "\n====================\nНазвание ключей\n===================="
echo
read  -p "Введите имя файла сертификата: " crt
echo
read  -p "Введите имя файла ключа: " key

#копируем ключи и сертификат
cp /home/$USERNAME/$crt /opt/prometheus/
cp /home/$USERNAME/$key /opt/prometheus/

# сделаем хеш пароля
if ! dpkg -s apache2-utils  &> /dev/null; then
        apt-get install -y apache2-utils
fi
hash=$(htpasswd -nbB -C 10 admin "abkfnjd")
two=$(echo "$hash" | cut -d ':' -f 2)

#создадим файл для настроек https
cat <<EOF> /opt/prometheus/web.yml
tls_server_config:
  # Certificate and key files for server to use to authenticate to client.
  cert_file: $crt
  key_file: $key
basic_auth_users:
  admin: '$two'
EOF

if ! getent group node_exporter &>/dev/null; then
        addgroup --system "prometheus" --quiet
fi

if ! getent passwd node_exporter &>/dev/null; then
        adduser --system --home /usr/share/prometheus --no-create-home --ingroup "prometheus" --disabled-password --shell /bin/false "prometheus"
fi

#становим права на файлы
chown -R prometheus:prometheus /var/lib/prometheus/
chmod -R 755 /var/lib/prometheus/
chown -R prometheus:prometheus /etc/prometheus/
chmod -R 755 /etc/prometheus/
chmod 640 /etc/prometheus/*.crt
chmod 640 /etc/prometheus/*.key
chown prometheus:prometheus /usr/bin/prometheus
chown -h prometheus:prometheus /usr/local/bin/prometheus
chmod 755 /usr/bin/prometheus
chown prometheus:prometheus /usr/bin/promtool
chown -h prometheus:prometheus /usr/local/bin/promtool
chmod 755 /usr/bin/promtool

#создадим юнит 
cat <<EOF> /etc/systemd/system/prometheus.service
[Unit]
Description=Prometheus
Wants=network-online.target
After=network-online.target
[Service]
User=prometheus
Group=prometheus
Type=simple
ExecStart=/usr/bin/prometheus \
--config.file /etc/prometheus/prometheus.yml \
--storage.tsdb.path /var/lib/prometheus/ \
--web.console.templates=/etc/prometheus/consoles \
--web.console.libraries=/etc/prometheus/console_libraries \
--web.config.file=/etc/prometheus/web.yml
[Install]
WantedBy=multi-user.target
EOF

#перезапустим сервис
systemctl daemon-reload
systemctl restart prometheus.service
systemctl enable prometheus.service

iptables -A INPUT -p tcp --dport 9090 -j ACCEPT -m comment --comment prometheus
# сохраним правила iptables
netfilter-persistent save

echo -e "\n====================\nPrometheus listening on port 9090\n====================\n"
echo -e "\nOK\n"

