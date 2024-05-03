#!/bin/bash
#------------------------------------------------------------------------
# Script to Install easy-rsa and openvpn server on Linux Ubuntu or Debian
#
# Developed by Ivan Filatoff
#------------------------------------------------------------------------

# сохраним имя исходного пользователя
USERNAME="$SUDO_USER"

# Если имя пользователя не определено, выходим с ошибкой
if [ -z "$USERNAME" ]; then
    echo "Ошибка: не удалось определить имя пользователя."
    exit 1
fi

#если передан параметр uninstall то удаляем VPN
if [ "$1" = "uninstall" ]; then
    read -p "Вы уверены, что хотите удалить VPN и все файлы? (yes or no): " remove
    if [ "$remove" = 'yes' ]; then
        sudo apt-get remove easy-rsa openvpn
        sudo -u "$USERNAME" rm -r /home/$USERNAME/easy-rsa /home/$USERNAME/client-configs 
        echo "Сервер VPN удален"
        exit 0
    fi
    exit 0
fi

# Директория, где будет располагаться Easy-RSA
EASYRSA_DIR="/home/$USERNAME/easy-rsa"

#будут лежать готовые конфиги для юзеров
CLIENT_FILES="/home/$USERNAME/client-configs/files"

#будут лежать ключи клиентов
CLIENT_KEYS="/home/$USERNAME/client-configs/keys"

#
CLIENT_CONF="/home/$USERNAME/client-configs"
#CLIENT_BIN="/home/$USERNAME/client-configs/bin"

#создадим директории
sudo -u "$USERNAME" mkdir -p $CLIENT_FILES
sudo -u "$USERNAME" mkdir -p $CLIENT_KEYS


#инсталирую deb пакет который ставит конфиги и скрипты
#dpkg -i
#временное решение
sudo -u "$USERNAME" cp ~/nanocorpinfra/config/base.conf $CLIENT_CONF
sudo -u "$USERNAME" cp ~/nanocorpinfra/client.sh $CLIENT_CONF
sudo -u "$USERNAME" cp ~/nanocorpinfra/var.conf $CLIENT_CONF

# проверяем, что файл не пустой
if [ -s "param.conf" ]; then
  # загружаем параметры из файла
  source param.conf
else
  echo "Error: param.conf пустой. Заполните файл в соответсвии с Вашей конфигурацией"
  exit 1
fi

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
	
		#передадим файл запроса подписи на СА 
		if ! sudo -u "$USERNAME" scp $EASYRSA_DIR/pki/reqs/server.req $SERVER_CA:/home/$USER_CA; then
			echo "Файл запроса не удалось скопировать на сервер СА"
		fi
		
		ssh -t $USER_CA@$IP_SERV_CA "/home/$USER_CA/nanocorpinfra/sign_req.sh server server.req"
                
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


cd /home/$USERNAME/easy-rsa 
sudo -u "$USERNAME" openvpn --genkey --secret ta.key
sudo -u "$USERNAME" chmod -R 700 /home/$USERNAME/client-configs
cp /home/$USERNAME/easy-rsa/ta.key /etc/openvpn/server
cp /home/$USERNAME/easy-rsa/pki/private/server.key /etc/openvpn/server/
cp $HOME/{server.crt,ca.crt} /etc/openvpn/server
sudo -u "$USERNAME" cp /home/$USERNAME/easy-rsa/ta.key $CLIENT_KEYS

#####################################################################
#это потом должен сделать deb пакет
cp /home/$USERNAME/nanocorpinfra/config/server.conf /etc/openvpn/server/





