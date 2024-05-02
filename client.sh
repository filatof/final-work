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


# Директория, где будет располагаться Easy-RSA
TARGET_DIR="$HOME/easy-rsa"
cd $TARGET_DIR || exit 1

$TARGET_DIR/easyrsa gen-req $CLIENT nopass
cp $TARGET_DIR/pki/private/$CLIENT.key $HOME/client-configs/keys/
scp $TARGET_DIR/pki/reqs/$CLIENT.req $USER_CA@$IP_SERV_CA:/home/$USER_CA

ssh -t $USER_CA@$IP_SERV_CA "/home/$USER_CA/nanocorpinfra/sign_req.sh client $CLIENT.req"

$HOME/client-configs/make_config.sh $CLIENT

echo "Настройки клиента созданы"
echo "Файл лежит $HOME/client-configs/files/"


