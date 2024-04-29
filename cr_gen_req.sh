#!/bin/bash

#--------------------------------------------------------------------
# Script to create request signing  easy-rsa  on Linux
#
# Developed by Ivan Filatoff
#--------------------------------------------------------------------

# сохраним имя исходного пользователя
USERNAME="$SUDO_USER"
SERVER=vpnserver

# Если имя пользователя не определено, выходим с ошибкой
if [ -z "$USERNAME" ]; then
    echo "Ошибка: не удалось определить имя пользователя."
    exit 1
fi

# Директория, где будет располагаться Easy-RSA
TARGET_DIR="/home/$USERNAME/easy-rsa"

cd $TARGET_DIR || exit 1

sudo -u "$USERNAME" ./easyrsa gen-req $SERVER nopass

cp /home/sammy/easy-rsa/pki/private/server.key /etc/openvpn/server/



