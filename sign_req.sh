#!/bin/bash
#------------------------------------------------------------------------
# Script to signing request *.req 
#
# Developed by Ivan Filatoff
#------------------------------------------------------------------------
#имя найденого и выбранного файла в /tmp
SELECTED_FILE=""

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
EASYRSA_DIR="/home/$USERNAME/easy-rsa"

# Переходим в папку easy-rsa
cd "$TARGET_DIR" || exit 1

# Функция для вывода списка файлов *.req в директории /tmp
list_req_files() {
    echo "Список файлов с расширением *.req в директории /tmp:"
    files=$(find /tmp -maxdepth 1 -name "*.req" -type f)
    if [ -z "$files" ]; then
        echo "Файлы с расширением *.req не найдены."
        exit 1
    else
        echo "$files"
    fi
}

# Функция для выбора файла пользователем
select_file() {
    read -p "Введите имя файла из списка выше: " SELECTED_FILE
    if [ ! -f "/tmp/$SELECTED_FILE" ]; then
        echo "Ошибка: Файл не найден."
        exit 1
    fi
}

# Функция для выбора параметра (server или client) и подписи запроса
sign_request() {
    read -p "Введите параметр (server или client): " param
    case $param in
        server)
            sudo -u "$USERNAME" ./easyrsa import-req /tmp/"$SELECT_FILE" server
            sudo -u "$USERNAME" ./easyrsa sign-req server server
            sudo -u "$USERNAME" scp /home/$USERNAME/easy-rsa/pki/issued/server.crt $USER_VPN@$IP_SERV_VPN:/tmp
            sudo -u "$USERNAME" scp /home/$USERNAME/easy-rsa/pki/ca.crt $USER_VPN@$IP_SERV_VPN:/tmp
            ;;
        client)
            sudo -u "$USERNAME" ./easyrsa sign-req client "$client_name"
            sudo -u "$USERNAME" scp /home/$USERNAME/easy-rsa/pki/issued/server.crt $USER_VPN@$IP_SERV_VPN:/tmp
            sudo -u "$USERNAME" scp /home/$USERNAME/easy-rsa/pki/ca.crt $USER_VPN@$IP_SERV_VPN:/tmp
            ;;
        *)
            echo "Ошибка: Неверный параметр. Допустимые значения: server или client."
            exit 1
            ;;
    esac
}

# Основная часть скрипта

list_req_files
select_file
sign_request



