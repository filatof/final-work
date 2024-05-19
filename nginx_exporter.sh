!/bin/bash
#--------------------------------------------------------------------
# Script to Install nginx_exporter  Ubuntu or Debian 
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
    read -p "Вы уверены, что хотите удалить nginx_exporter  и все файлы? (yes or no): " remove
    if [ "$remove" = 'yes' ]; then
         systemctl stop nginx_exporter.service
         systemctl disable nginx_exporter.service
	 rm /usr/bin/prometheus-nginx-exporter
         rm -rf /opt/nginx_exporter/
         rm /etc/systemd/system/nginx_exporter.service
         sudo -u "$USERNAME" rm -rf /home/$USERNAME/node-exporter/
         iptables -D INPUT -p tcp --dport 9113 -j ACCEPT
         service netfilter-persistent save
         echo -e "\n================\nexporter удален\n================\n"
         exit 0
    fi
    exit 0
fi

NODE_DIR="nginx-exporter"
#проверим установлен ли nginx_exporter 
if [ -d /opt/nginx_exporter  ] && [ -f /usr/bin/nginx-prometheus-exporter  ]; then
        echo "nginx_exporter уже установлен"
        exit 0
fi


#создадим директорию и скачаем туда пакет
sudo -u "$USERNAME" mkdir /home/$USERNAME/$NODE_DIR
sudo -u "$USERNAME" wget -P /home/$USERNAME/$NODE_DIR https://github.com/nginxinc/nginx-prometheus-exporter/releases/download/v1.1.0/nginx-prometheus-exporter_1.1.0_linux_amd64.tar.gz
sudo -u "$USERNAME" tar -xvf /home/$USERNAME/$NODE_DIR/nginx-prometheus-exporter_1.1.0_linux_amd64.tar.gz -C /home/$USERNAME/$NODE_DIR

#копируем бинарник в систему
cp /home/$USERNAME/$NODE_DIR/nginx-prometheus-exporter /usr/bin/
mkdir /opt/nginx_exporter

#напишем название ключей и сертификата
echo -e "\n====================\nНазвание ключей\n===================="
echo
read  -p "Введите имя файла сертификата: " crt
echo
read  -p "Введите имя файла ключа: " key

#копируем ключи и сертификат
cp /home/$USERNAME/$crt /opt/nginx_exporter/
cp /home/$USERNAME/$key /opt/nginx_exporter/

#создадим файл для настроек https
cat <<EOF> /opt/nginx_exporter/prometheus-nginx-exporter
# Set the command-line arguments to pass to the server.
# Due to shell scaping, to pass backslashes for regexes, you need to double
# them (\\d for \d). If running under systemd, you need to double them again
# (\\\\d to mean \d), and escape newlines too.
ARGS="-web.secured-metrics -web.ssl-server-cert /opt/nginx_exporter/repo.nanocorpinfra.ru.crt -web.ssl-server-key /opt/nginx_exporter/repo.nanocorpinfra.ru.key"
EOF

if ! getent group nginx_exporter &>/dev/null; then
        addgroup --system "nginx_exporter" --quiet
fi

if ! getent passwd nginx_exporter &>/dev/null; then
        adduser --system --home /usr/share/nginx_exporter --no-create-home --ingroup "nginx_exporter" --disabled-password --shell /bin/false "nginx_exporter"
fi

#установим права и владельцев файла
chown -R nginx_exporter:nginx_exporter /opt/nginx_exporter
chmod -R 755 /opt/nginx_exporter/
chmod 640 /opt/nginx_exporter/*.crt
chmod 640 /opt/nginx_exporter/*.key
chown nginx_exporter:nginx_exporter /usr/bin/nginx-prometheus-exporter
chmod 755 /usr/bin/nginx-prometheus-exporter

#создадим юнит
cat <<EOF> /etc/systemd/system/nginx_exporter.service
[Unit]
Description=NGINX Prometheus Exporter
Documentation=https://github.com/nginxinc/nginx-prometheus-exporter
After=network.target nginx.service

[Service]
Restart=on-failure
User=nginx_exporter
EnvironmentFile=/opt/nginx_exporter/prometheus-nginx-exporter
ExecStart=/usr/bin/nginx-prometheus-exporter $ARGS

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl restart nginx_exporter.service
systemctl enable nginx_exporter.service

#добавим правила для пропуска на порт 9100
iptables -A INPUT -p tcp --dport 9113 -j ACCEPT
#сохраним настройки iptables
service netfilter-persistent save


echo -e "\n====================\nNGINX Exporter listening on port 9113\n====================\n"
echo -e "\nOK\n"

