#!/bin/bash

USERNAME="$SUDO_USER"
HOME_DIR=$(eval echo ~"$USERNAME")
TARGET_DIR="$HOME_DIR/easy-rsa"

# Проверим установлен easy-rs в сситему
if ! dpkg -s easy-rsa &> /dev/null; then
    echo "Пакет Easy-RSA не установлен. Начинаем установку..."
    
    # Устанавливаем пакет easy-rsa
    sudo apt-get update
    sudo apt-get install -y easy-rsa
    
    # Проверяем успешность установки
    if [ $? -eq 0 ]; then
        echo "Easy-RSA успешно установлен."
    else
        echo "Ошибка при установке Easy-RSA. Пожалуйста, проверьте наличие подключения к интернету и повторите попытку."
        exit 1
    fi
else
    echo "Пакет Easy-RSA уже установлен."
fi


# Создаем директорию от имени этого пользователя
# Проверяем, существует ли целевая директория
if [ -d "$TARGET_DIR" ]; then
    echo "Директория $TARGET_DIR уже существует."
else
    # Создаем директорию
    mkdir -p "$TARGET_DIR"
fi

#создаем символические ссылки в нашу созданную директорию
if ! ln -s /usr/share/easy-rsa/* "$TARGET_DIR"; then  
     echo "Символические ссылки не созданы"
     echo "Проверте наличие директории /usr/share/easy-rsa"
fi

# Переходим в папку easy-rsa
cd "$TARGET_DIR" || exit 1

#ограничим доступ к папке 
chmod 700 "$TARGET_DIR"

# Запустим инициализацию PKI
if ! ./easyrsa init-pki ; then
	echo "Ошибка инициализации. Проверте наличие скрипата easyrsa"
fi

# изменим файл vars заполним своими значениями
#
cp vars.example vars
# Путь к файлу vars
VARS_FILE="$TARGET_DIR/vars"

# Заменяемые значения
NEW_COUNTRY="RU"
NEW_PROVINCE="Moscow"
NEW_CITY="Moscow"
NEW_ORG="EQ"
NEW_EMAIL="admin@example.com"
NEW_OU="LLC"
NEW_ALGO="ec"
NEW_DIGEST="sha512"

# Проверяем, существует ли файл vars
if [ ! -f "$VARS_FILE" ]; then
    echo "Файл $VARS_FILE не найден."
    exit 1
fi

# Заменяем строки в файле vars
sed -i "s/^#set_var EASYRSA_REQ_COUNTRY.*/set_var EASYRSA_REQ_COUNTRY    \"$NEW_COUNTRY\"/" "$VARS_FILE"
sed -i "s/^#set_var EASYRSA_REQ_PROVINCE.*/set_var EASYRSA_REQ_PROVINCE    \"$NEW_PROVINCE\"/" "$VARS_FILE"
sed -i "s/^#set_var EASYRSA_REQ_CITY.*/set_var EASYRSA_REQ_CITY    \"$NEW_CITY\"/" "$VARS_FILE"
sed -i "s/^#set_var EASYRSA_REQ_ORG.*/set_var EASYRSA_REQ_ORG    \"$NEW_ORG\"/" "$VARS_FILE"
sed -i "s/^#set_var EASYRSA_REQ_EMAIL.*/set_var EASYRSA_REQ_EMAIL    \"$NEW_EMAIL\"/" "$VARS_FILE"
sed -i "s/^#set_var EASYRSA_REQ_OU.*/set_var EASYRSA_REQ_OU    \"$NEW_OU\"/" "$VARS_FILE"
sed -i "s/^#set_var EASYRSA_ALGO.*/set_var EASYRSA_ALGO    \"$NEW_ALGO\"/" "$VARS_FILE"
sed -i "s/^#set_var EASYRSA_DIGEST.*/set_var EASYRSA_DIGEST    \"$NEW_DIGEST\"/" "$VARS_FILE"

# запускаем создание СА
if ! ./easyrsa build-ca; then
	echo "Ошибка при создании CA"
fi

