#!/bin/bash
#------------------------------------------------------------------------
# Script to Install repo server on Linux Ubuntu or Debian
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

#если передан параметр -u то удаляем
if [ "$1" = "-u" ]; then
    read -p "Вы уверены, что хотите удалить VPN и все файлы? (yes or no): " remove
    if [ "$remove" = 'yes' ]; then
	      systemctl stop nginx
	      systemctl desable nginx
        apt-get purge nginx
	      apt-get purge apache2-utils
	      apt-get purge bzip2
	      rm -f /usr/local/bin/aptly
        rm -f /etc/aptly.conf
	      echo -e "\n================\nСервер Repo удален\n================\n"
        exit 0
    fi
    exit 0
fi
#установим Московское время
echo -e "\n=======================\nSetting timezone Moscow\n======================="
timedatectl set-timezone Europe/Moscow

# функция, которая проверяет наличие пакета в системе и в случае его отсутствия выполняет установку
command_check() {
  if ! command -v "$1" &>/dev/null; then
    echo -e "\n====================\n$2 could not be found!\nInstalling...\n====================\n"
    apt-get install -y "$3"
    echo -e "\nDONE\n"
  fi
}

# функция, которая запрашивает путь до файла и проверяет его валидность
path_request() {
  while true; do
    read -r -e -p $'\n'"Please input full valid path to ${1}: " path
    if [ -f "$path" ]; then
      echo "$path"
      break
    fi
  done
}
# функция, которая проверяет наличие правила в iptables и в случае отсутствия применяет его
iptables_add() {
  if ! iptables -C "$@" &>/dev/null; then
    iptables -A "$@"
  fi
}

# установим все необходимые пакеты используя функцию command_check
systemctl restart systemd-timesyncd.service
apt-get update
command_check wget "Wget" wget
command_check iptables "Iptables" iptables
command_check netfilter-persistent "Netfilter-persistent" iptables-persistent
command_check rngd "Rng-tools" rng-tools
command_check nginx "Nginx" nginx
command_check htpasswd "Htpasswd" apache2-utils
command_check basename "Basename" coreutils
command_check bzip2 "Bzip2" bzip2

# настроим aptly
echo -e "\n====================\nAptly Configuration...\n====================\n"

# проверим на наличие старых файлов aptly (полезно при переустановке)
if [ -f /tmp/aptly_1.5.0_linux_amd64.tar.gz ] || [ -d /tmp/aptly_1.5.0_linux_amd64 ]; then
  rm -rf /tmp/aptly_1.5.0_linux_amd64*
fi

# скачаем исходники aptly с распакуем их
if wget -P /tmp/ https://github.com/aptly-dev/aptly/releases/download/v1.5.0/aptly_1.5.0_linux_amd64.tar.gz; then
  tar -xvf /tmp/aptly_1.5.0_linux_amd64.tar.gz -C /tmp/
  mv -f /tmp/aptly_1.5.0_linux_amd64/aptly /usr/local/bin/
else
  exit 1
fi
rm -rf /opt/aptly
rm -rf /var/www/aptly
# создадим конфигурационный файл aptly
echo '{
  "rootDir": "/opt/aptly",
  "downloadConcurrency": 4,
  "downloadSpeedLimit": 0,
  "architectures": ["all","amd64"],
  "dependencyFollowSuggests": false,
  "dependencyFollowRecommends": false,
  "dependencyFollowAllVariants": false,
  "dependencyFollowSource": false,
  "dependencyVerboseResolve": false,
  "gpgDisableSign": false,
  "gpgDisableVerify": false,
  "gpgProvider": "gpg",
  "downloadSourcePackages": true,
  "skipLegacyPool": true,
  "ppaDistributorID": "ubuntu",
  "ppaCodename": "",
  "FileSystemPublishEndpoints": {
    "lab": {
      "rootDir": "/var/www/aptly",
      "linkMethod": "symlink",
      "verifyMethod": "md5"
    }
  },
  "enableMetricsEndpoint": false
}' >/etc/aptly.conf

# создадим репозиторий lab
if aptly repo create -comment="infra repo" -component="main" -distribution="focal" infra; then
  # запросим путь до первого deb-пакета
  package_path=$(path_request "first package (architecture is all or amd64)")
  # загрузим пакет в новый репозиторий
  if ! aptly repo add infra "$package_path"; then
    exit 1
  fi
else
  exit 1
fi
echo -e "\n====================\nLab Repo Successfully Created\n====================\n"

# сгенерируем gpg-ключи
echo -e "\n====================\nGPG Key Generating...\n====================\n"
rngd -r /dev/urandom
rngd_check=$?
if [ $rngd_check -eq 0 ] || [ $rngd_check -eq 10 ]; then
  gpg --default-new-key-algo rsa4096 --gen-key --keyring pubring
  gen_key_check=$?
  if [ $gen_key_check -eq 0 ] || [ $gen_key_check -eq 2 ]; then
    gpg --list-keys
  fi
else
  exit 1
fi
echo -e "\nDONE\n"

# опубликуем репозиторий
aptly publish repo infra filesystem:infra:infra

# экспортируем открытый gpg-ключ на web-страницу репозитория
gpg --export --armor | tee /var/www/aptly/infra/labtest.asc >/dev/null

# экспортируем открытый ключ ca на web-страницу репозитория
cp "$(path_request "ca certificate")" /var/www/aptly/infra/ca.crt

echo -e "\n====================\nLab Repo Successfully Published\n====================\n"

# настроим nginx
echo -e "\n====================\nNginx Configuration...\n====================\n"

# запросим доменное имя репозитория
read -r -p $'\n'"repo domain name (example repo.nanocorprepo.ru): " repo_name
# запросим путь до сертификата с помощью функции path_request и перенес файл в рабочую директорию nginx
server_crt=$(path_request certificate)
cp "$server_crt" /etc/nginx/
cert_file=$(basename "$server_crt")

# запросим путь до приватного ключа с помощью функции path_request и перенес файл в рабочую директорию nginx
server_key=$(path_request key)
cp "$server_key" /etc/nginx/
key_file=$(basename "$server_key")

# запросим логин и пароль для нового репозитория
read -r -p $'\n\n'"login for ${repo_name}: " repo_login
read -r -p "password for ${repo_name}: " -s repo_pass

# сгенерируем хэш пароля
htpasswd -nbB -C 10 "$repo_login" "$repo_pass" >>/etc/nginx/conf.d/.htpasswd
# создадим конфигурационный файл nginx
echo '
server {
        listen 1111 ssl default_server;
        server_name '"$repo_name"';
        auth_basic              "Restricted Access!";
        auth_basic_user_file    /etc/nginx/conf.d/.htpasswd;
        ssl_certificate     '"$cert_file"';
        ssl_certificate_key '"$key_file"';
        ssl_protocols       TLSv1 TLSv1.1 TLSv1.2 TLSv1.3;
        ssl_ciphers         HIGH:!aNULL:!MD5;

        root /var/www/aptly;

        location / {
                autoindex on;
        }
}

# nginx prometheus exporter
server {
        listen 8080;

        location /stub_status {
                stub_status;
                allow 127.0.0.1;
                deny all;
        }
}' >/etc/nginx/sites-available/default
echo -e "\nDONE\n"
# перезагрузим nginx-сервис
systemctl restart nginx.service
systemctl enable nginx.service

echo -e "\n====================\nRepo listening on port 1111\n====================\n"
echo -e "\nOK\n"
exit 0
