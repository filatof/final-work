#!/bin/bash
#------------------------------------------------------------------------
# Script to signing request *.req 
#
# Developed by Ivan Filatoff
#------------------------------------------------------------------------
#Скрипт подписывает запрос на подпись и возвращает файл на сервер VPN, monitor 
#
#выбираем для клиента или для сервера подпись
PARAM=$1

#имя файла с раширением который нужно подписать
FILE=$2

#Загрузим параметры для скриптов из файла настроек
# проверяем, что файл не пустой
if [ -s "$HOME/etc/var.conf" ]; then
  # загружаем параметры из файла
  source $HOME/etc/var.conf
else
  echo "Error: var.conf пустой. Заполните файл в соответсвии с Вашей конфигурацией"
  exit 1
fi

# Директория, где будет располагаться Easy-RSA
TARGET_DIR="$HOME/easy-rsa"

# Переходим в папку easy-rsa
cd "$TARGET_DIR" || exit 1

case $PARAM in
   server) #подпись для сервера
     # импортируем запрос на подписание
      $TARGET_DIR/easyrsa import-req /home/$USER_CA/$FILE server
      rm /home/$USER_CA/$FILE 
      # подписываем запрос
      $TARGET_DIR/easyrsa sign-req server server
      #возвращаем сертификат запросившему подпись серверу
      scp $TARGET_DIR/pki/issued/server.crt $USER_VPN@$IP_SERV_VPN:/home/$USER_VPN
      #передадим сертификат СА
      scp $TARGET_DIR/pki/ca.crt $USER_VPN@$IP_SERV_VPN:/home/$USER_VPN
      ;;
   client) #подпись для клиента
      client_name=$(basename "$FILE" .req)
      # импортируем запрос на подпись 
      $TARGET_DIR/easyrsa import-req /home/$USER_CA/$FILE "$client_name"
      rm /home/$USER_CA/$FILE
      #подписываем запрос
      $TARGET_DIR/easyrsa sign-req client "$client_name"
      #возвращаем подписаный сертификат
      scp $TARGET_DIR/pki/issued/$client_name.crt $USER_VPN@$IP_SERV_VPN:/home/$USER_VPN/client-configs/keys
      ;;
    *)
      echo "Ошибка: Неверный параметр. Допустимые значения: server или client."
      exit 1
      ;;
esac


