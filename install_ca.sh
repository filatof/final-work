#!/bin/bash
#--------------------------------------------------------------------
# Script to Install CA easy-rsa  on Linux Ubuntu or Debian 
#
# Developed by Ivan Filatoff
#--------------------------------------------------------------------
# Директория, где будет располагаться Easy-RSA
TARGET_DIR="/home/$USERNAME/easy-rsa"

#Директория где будет находится скрипт для подписи запросов 
REQ_DIR="/home/$USERNAME/bin"

#Дириктория где будет находится файл с переменными настроек
REQ_DIR_ETC="/home/$USERNAME/etc"

# сохраним имя исходного пользователя
USERNAME="$SUDO_USER"
# Если имя пользователя не определено, выходим с ошибкой
if [ -z "$USERNAME" ]; then
    echo "Ошибка: не удалось определить имя пользователя."
    exit 1
fi

#если передан параметр uninstall то удаляем СА
if [ "$1" = "uninstall" ]; then
    read -p "Вы уверены, что хотите удалить СА и все файлы? (yes or no): " remove
    if [ "$remove" = 'yes' ]; then
        sudo apt-get remove easy-rsa
        sudo -u "$USERNAME" rm -r /home/$USERNAME/easy-rsa /home/$USERNAME/bin /home/$USERNAME/etc
        echo "Сервер СА удален"
        exit 0
    fi
    exit 0
fi

# Проверим установлен easy-rs в систему
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
    echo "Пакет Easy-RSA уже установлен"
fi


# Создаем директорию от имени этого пользователя
# Проверяем, существует ли СА
if [ -d $TARGET_DIR ] && [ -d "$TARGET_DIR/pki" ] && [ -f "$TARGET_DIR/pki/ca.crt" ] ; then
        echo "Центр сертификации уже создан"
        exit 0
else
    # СА не существует
    # Создаем директорию от пользователя которым запущено sudo
    sudo -u "$USERNAME" mkdir -p "$TARGET_DIR"
    
    sudo -u "$USERNAME" mkdir -p "$REQ_DIR"
    sudo -u "$USERNAME" mkdir -p "$REQ_DIR_ETC"
    #запускаем deb пакет для установки скрипта и настройки в директории
    # dpkg -i 
    #временное решение
    sudo -u "$USERNAME" cp /home/$USERNAME/nanocorpinfra/var.conf $REQ_DIR_ETC
    sudo -u "$USERNAME" cp /home/$USERNAME/nanocorpinfra/sign_req.sh $REQ_DIR

    #ограничим доступ к папке 
    sudo -u "$USERNAME" chmod 700 "$TARGET_DIR"
    
    #создаем символические ссылки в нашу созданную директорию
    if ! sudo -u "$USERNAME" ln -s /usr/share/easy-rsa/* "$TARGET_DIR"; then  
     	 echo "Символические ссылки не созданы"
         echo "Проверте наличие директории /usr/share/easy-rsa"
	 exit 1
    fi
fi

#Настроим файрвол
#
ufw enable
ufw allow ssh
ufw default deny incoming
ufw reload

# Переходим в папку easy-rsa
cd "$TARGET_DIR" || exit 1



# Запустим инициализацию PKI
if ! sudo -u "$USERNAME" ./easyrsa init-pki ; then
	echo "Ошибка инициализации. Проверте наличие скрипата easyrsa"
 	exit 1
fi

# изменим файл vars заполним своими значениями
#
sudo -u "$USERNAME" cp vars.example vars
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
if ! sudo -u "$USERNAME" ./easyrsa build-ca; then
	echo "Ошибка при создании CA"
	exit 1
fi

echo "Удостоверяющий центр успешно создан"
echo 
echo "Приватный ключ расположен: $TARGET_DIR/pki/private/ca.key"
echo "Публичный сертификат расположен: $TARGET_DIR/pki/ca.crt"
exit 0

