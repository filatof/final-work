#!/bin/bash
#--------------------------------------------------------------------
# Script to Install CA easy-rsa  on Linux Ubuntu or Debian 
#
# Developed by Ivan Filatoff
#--------------------------------------------------------------------
#установим Московское время
echo -e "\n=======================\nSetting timezone Moscow\n======================="
timedatectl set-timezone Europe/Moscow

# сохраним имя исходного пользователя
USERNAME="$SUDO_USER"
# Если имя пользователя не определено, выходим с ошибкой
if [ -z "$USERNAME" ]; then
    echo "Ошибка: не удалось определить имя пользователя."
    exit 1
fi

# Директория, где будет располагаться Easy-RSA
TARGET_DIR="/home/$USERNAME/easy-rsa"

#Директория где будет находится скрипт для подписи запросов 
REQ_DIR="/home/$USERNAME/bin"

#Дириктория где будет находится файл с переменными настроек
REQ_DIR_ETC="/home/$USERNAME/etc"

sudo -u "$USERNAME" mkdir -p "$REQ_DIR"
sudo -u "$USERNAME" mkdir -p "$REQ_DIR_ETC"
#запускаем deb пакет для установки скрипта и настройки в директории
    # dpkg -i 
    #временное решение
    sudo -u "$USERNAME" cp /home/$USERNAME/nanocorpinfra/var.conf $REQ_DIR_ETC
    sudo -u "$USERNAME" cp /home/$USERNAME/nanocorpinfra/sign_req.sh $REQ_DIR

# проверяем, что файл не пустой
if [ -s "$REQ_DIR_ETC/var.conf" ]; then
  # загружаем параметры из файла
  source $REQ_DIR_ETC/var.conf
else
  echo "Error: var.conf пустой. Заполните файл в соответсвии с Вашей конфигурацией"
  exit 1
fi

#если передан параметр uninstall то удаляем СА
if [ "$1" = "-u" ]; then
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
    echo -e "\n=============================\nПакет Easy-RSA не установлен\nНачинаем установку...\n=============================\n"
    
    # Устанавливаем пакет easy-rsa
    sudo apt-get update
    sudo apt-get install -y easy-rsa
    
    # Проверяем успешность установки
    if [ $? -eq 0 ]; then
       echo -e "\n============================\nEasy-RSA успешно установлен\n============================\n"
    else
	echo -e "\n=================================\nОшибка при установке Easy-RSA.\nПожалуйста, проверьте наличие\nподключения к интернету и\nповторите попытку\n=================================\n"
	exit 1
    fi
else
    echo -e "\n============================\nПакет Easy-RSA уже установлен\n============================\n"
    exit 1
fi


# Создаем директорию от имени этого пользователя
# Проверяем, существует ли СА
if [ -d $TARGET_DIR ] && [ -d "$TARGET_DIR/pki" ] && [ -f "$TARGET_DIR/pki/ca.crt" ] ; then
        echo -e "\n============================\nЦентр сертификации уже создан\n============================\n"
        exit 0
else
    # СА не существует
    # Создаем директорию от пользователя которым запущено sudo
    sudo -u "$USERNAME" mkdir -p "$TARGET_DIR"

    #ограничим доступ к папке 
    sudo -u "$USERNAME" chmod 700 "$TARGET_DIR"
    
    #создаем символические ссылки в нашу созданную директорию
    if ! sudo -u "$USERNAME" ln -s /usr/share/easy-rsa/* "$TARGET_DIR"; then  
     	 echo "Символические ссылки не созданы"
         echo "Проверте наличие директории /usr/share/easy-rsa"
	 exit 1
    fi
fi

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

#Настроим файрвол
#запретим все входящие соединения кроме ssh
ufw enable
ufw allow ssh
ufw default deny incoming
ufw reload

echo -e "\n===============================================\nУдостоверяющий центр успешно создан\n"
echo "Приватный ключ расположен: $TARGET_DIR/pki/private/ca.key"
echo "Публичный сертификат расположен: $TARGET_DIR/pki/ca.crt"
echo "==============================================="
exit 0

