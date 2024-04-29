#!/bin/bash
#------------------------------------------------------------------------
# Script to Install easy-rsa and openvpn server on Linux Ubuntu or Debian
#
# Developed by Ivan Filatoff
#------------------------------------------------------------------------


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


# Проверим установлен easy-rs в сситему
if ! dpkg -s easy-rsa &> /dev/null; then
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

	# Проверяем, существует ли easy-rsa на сервере 
	if [ -d $EASYRSA_DIR ] && [ -d "$EASYRSA_DIR/pki" ] && [ -f "$EASYRSA_DIR/pki/ca.crt" ] ; then
        	echo "easy-rsa уже создан"
	else
    		# easy-rsa  не существует
    		# Создаем директорию от пользователя которым запущено sudo
    		sudo -u "$USERNAME" mkdir -p "$EASYRSA_DIR"
    
    		#ограничим доступ к папке 
    		sudo -u "$USERNAME" chmod 700 "$EASYRSA_DIR"
    
   		 #создаем символические ссылки в нашу созданную директорию
    	 	if ! sudo -u "$USERNAME" ln -s /usr/share/easy-rsa/* "$EASYRSA_DIR"; then  
     	 		echo "Символические ссылки не созданы"
         		echo "Проверте наличие директории /usr/share/easy-rsa"
	 		exit 1
    		fi

		# Переходим в папку easy-rsa
		cd "$EASYRSA_DIR" || exit 1

		# изменим файл vars заполним своими значениями
		sudo -u "$USERNAME" cp vars.example vars
		# Путь к файлу vars
		VARS_FILE="$EASYRSA_DIR/vars"

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

		# Запустим инициализацию PKI
		if ! sudo -u "$USERNAME" ./easyrsa init-pki ; then
			echo "Ошибка инициализации. Проверте наличие скрипата easyrsa"
 			exit 1
		fi

		# запускаем создание запроса на подпись сертификата
		if ! sudo -u "$USERNAME" ./easyrsa gen-req server nopass; then
			echo "Ошибка при создании запроса"
			exit 1
		fi
		echo "Приватный ключ сервера openvpn расположен: $EASYRSA_DIR/pki/private/server.key"
		echo "Запрос сертификата расположен: $EASYRSA_DIR/pki/reqs/server.req"
		
		#скопируем закрытый ключ в openvpn
		sudo cp /home/$USERNAME/easy-rsa/pki/private/server.key /etc/openvpn/server/
	
		#передадим файл запроса подписи на СА 
		scp /home/$USERNAME/easy-rsa/pki/reqs/server.req $USER_CA@$IP_SERV_CA:/tmp
		echo "Файл запроса подписи лежит на сервере СА $IP_SERV_CA в /tmp"
	fi
    	echo "Пакет Easy-RSA установлен, продолжим установку..."
fi

# проверим установку пакета openvpn 
if ! dpkg -s openvpn &> /dev/null; then
    echo "Пакет OpenVPN не установлен. Начинаем установку..."
    
    # Устанавливаем пакет openvpn
    sudo apt-get update
    sudo apt-get install -y openvpn
    
    # Проверяем успешность установки
    if [ $? -eq 0 ]; then
        echo "OpenVPN успешно установлен."
    else
        echo "Ошибка при установке OpenVPN. Пожалуйста, проверьте наличие подключения к интернету и повторите попытку."
        exit 1
    fi
else
    echo "Пакет OpenVPN уже установлен"
fi


sudo -u "$USERNAME" cd /home/$USERNAME/easy-rsa 
sudo -u "$USERNAME" openvpn --genkey --secret ta.key

cp /home/$USERNAME/easy-rsa/ta.key /etc/openvpn/server

cp /usr/share/doc/openvpn/examples/sample-config-files/server.conf /etc/openvpn/server/




