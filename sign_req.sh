#!/bin/bash
#------------------------------------------------------------------------
# Script to signing request *.req 
#
# Developed by Ivan Filatoff
#------------------------------------------------------------------------
#имя найденого и выбранного файла в /tmp
SELECTED_FILE=""
PARAM=$1
FILE=$2

#Загрузим параметры для скриптов из файла настроек
#
# проверяем, что файл не пустой
if [ -s "param.conf" ]; then
  # загружаем параметры из файла
  source param.conf
else
  echo "Error: param.conf пустой. Заполните файл в соответсвии с Вашей конфигурацией"
  exit 1
fi

# Директория, где будет располагаться Easy-RSA
TARGET_DIR="$HOME/easy-rsa"

# Переходим в папку easy-rsa
cd "$TARGET_DIR" || exit 1

    case $PARAM in
        server)
            $TARGET_DIR/easyrsa import-req /home/$USER_CA/$FILE server
            $TARGET_DIR/easyrsa sign-req server server
            scp $TARGET_DIR/pki/issued/server.crt $USER_VPN@$IP_SERV_VPN:/home/$USER_VPN
            scp $TARGET_DIR/pki/ca.crt $USER_VPN@$IP_SERV_VPN:/home/$USER_VPN
            ;;
        client)
            client_name=$(basename "$FILE" .req)
            $TARGET_DIR/easyrsa import-req /home/$USER_CA/$FILE "$client_name"
            $TARGET_DIR/easyrsa sign-req client "$client_name"
            scp $TARGET_DIR/pki/issued/$client_name.crt $USER_VPN@$IP_SERV_VPN:/home/$USER_VPN/client-configs/keys
            ;;
        *)
            echo "Ошибка: Неверный параметр. Допустимые значения: server или client."
            exit 1
            ;;
    esac


