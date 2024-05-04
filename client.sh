#!/bin/bash
#------------------------------------------------------------------------
# Script to generate client config for OpenVPN server 
#
# Developed by Ivan Filatoff
#------------------------------------------------------------------------

if [ $# -lt 1  ]; then
    echo "Предайте в парметре имя клиента"
    exit 1
fi

CLIENT=$1

#Загрузим параметры для скриптов из файла настроек
# проверяем, что файл не пустой
if [ -s "$CLIENT_CONF/var.conf" ]; then
  # загружаем параметры из файла
  source $CLIENT/var.conf
else            
  echo "Error: var.conf пустой. Заполните файл в соответсвии с Вашей конфигурацией"
  exit 1
fi              

# Директория, где будет располагаться Easy-RSA
TARGET_DIR="$HOME/easy-rsa"
cd $TARGET_DIR || exit 1

$TARGET_DIR/easyrsa gen-req $CLIENT nopass
cp $TARGET_DIR/pki/private/$CLIENT.key $HOME/client-configs/keys/
scp $TARGET_DIR/pki/reqs/$CLIENT.req $USER_CA@$IP_SERV_CA:/home/$USER_CA

ssh -t $USER_CA@$IP_SERV_CA "/home/$USER_CA/bin/sign_req.sh client $CLIENT.req"

cd $HOME/client-configs/ || exit 1

KEY_DIR=$HOME/client-configs/keys
OUTPUT_DIR=$HOME/client-configs/files
BASE_CONFIG=$HOME/client-configs/base.conf

cat ${BASE_CONFIG} \
    <(echo -e '<ca>') \
    ${KEY_DIR}/ca.crt \
    <(echo -e '</ca>\n<cert>') \
    ${KEY_DIR}/${1}.crt \
    <(echo -e '</cert>\n<key>') \
    ${KEY_DIR}/${1}.key \
    <(echo -e '</key>\n<tls-crypt>') \
    ${KEY_DIR}/ta.key \
    <(echo -e '</tls-crypt>') \
    > ${OUTPUT_DIR}/${1}.ovpn


echo "Настройки клиента созданы"
echo "Файл лежит $HOME/client-configs/files/$CLIENT.ovpn"
exit 0

