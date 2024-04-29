#!/bin/bash
#------------------------------------------------------------------------
# Script to generate *.req and *.key client on Linux 
#
# Developed by Ivan Filatoff
#------------------------------------------------------------------------

if [ $# -lt 1  ]; then
    echo "Предайте в парметре имя клиента"
    exit 1
fi
CLIENT=$1
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


# сохраним имя исходного пользователя
USERNAME="$SUDO_USER"

# Если имя пользователя не определено, выходим с ошибкой
if [ -z "$USERNAME" ]; then
    echo "Ошибка: не удалось определить имя пользователя."
    exit 1
fi

# Директория, где будет располагаться Easy-RSA
TARGET_DIR="/home/$USERNAME/easy-rsa"


cd $TARGET_DIR
sudo -u "$USERNAME" ./easyrsa gen-req $CLIENT nopass
sudo -u "$USERNAME" cp pki/private/$CLIENT.key /home/$USERNAME/client-configs/keys/
sudo -u "$USERNAME" scp /home/$USERNAME/easy-rsa/pki/reqs/$CLIENT.req $USER_CA@$IP_SERV_CA:/tmp


