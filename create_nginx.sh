#!/bin/bash
#--------------------------------------------------------------------
# Script to Install nginx server  on Linux Ubuntu or Debian 
# Developed by Ivan Filatoff
#--------------------------------------------------------------------

# сохраним имя исходного пользователя
USERNAME="$SUDO_USER"

# Проверим установлен ли в систему nginx
if ! dpkg -s nginx &> /dev/null; then
    echo "Пакет nginx не установлен. Начинаем установку..."
    
    # Устанавливаем пакет easy-rsa
    sudo apt-get update
    sudo apt-get install -y nginx
    
    # Проверяем успешность установки
    if [ $? -eq 0 ]; then
        echo "nginx  успешно установлен."
    else
        echo "Ошибка при установке nginx. Пожалуйста, проверьте наличие подключения к интернету и повторите попытку."
        exit 1
    fi
else
    echo "Сервер nginx уже установлен"
fi
# Создадим самоподписной сертификат 
if [ ! -d /etc/nginx/ssl  ]; then 
	mkdir -p /etc/nginx/ssl || exit 1
	openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout /etc/nginx/ssl/ca.key -out /etc/nginx/ssl/ca.crt
	htpasswd -c /etc/nginx/.htpasswd $USERNAME
fi	
