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
if [ "$1" = "-u" ]; then
    read -p "Вы уверены, что хотите удалить VPN и все файлы? (yes or no): " remove
    if [ "$remove" = 'yes' ]; then
	systemctl stop openvpn-server@server.service
	systemctl desable openvpn-server@server.service
        apt-get purge easy-rsa openvpn
	apt-get purge openvpn
	apt-get purge iptables-persistent
	rm -rf /etc/openvpn
        sudo -u "$USERNAME" rm -r /home/$USERNAME/easy-rsa /home/$USERNAME/client-configs
	echo -e "\n================\nСервер VPN удален\n================\n"
        exit 0
    fi
    exit 0
fi
#установим Московское время
echo -e "\n=======================\nSetting timezone Moscow\n======================="
timedatectl set-timezone Europe/Moscow

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
sudo -u "$USERNAME" cp /home/$USERNAME/nanocorpinfra/config/base.conf $CLIENT_CONF
sudo -u "$USERNAME" cp /home/$USERNAME/nanocorpinfra/client.sh $CLIENT_CONF
sudo -u "$USERNAME" cp /home/$USERNAME/nanocorpinfra/var.conf $CLIENT_CONF

# проверяем, что файл не пустой
if [ -s "$CLIENT_CONF/var.conf" ]; then
  # загружаем параметры из файла
  source "$CLIENT_CONF/var.conf"
else
  echo "Error: var.conf пустой. Заполните файл в соответсвии с Вашей конфигурацией"
  exit 1
fi
#заменим ip сервера ВПН на наш внешний адрес
sudo -u "$USERNAME" sed -i "s/remote [0-9]\+\.[0-9]\+\.[0-9]\+\.[0-9]\+ 1194/remote $EX_IP_VPN 1194/" $CLIENT_CONF/base.conf

# Проверим установлен easy-rs в сситему
if ! dpkg -s easy-rsa &> /dev/null; then
    	# Устанавливаем пакет easy-rsa
    	apt-get update
    	apt-get install -y easy-rsa
    
    	# Проверяем успешность установки
    	if [ $? -eq 0 ]; then
	 echo -e "\n============================\nEasy-RSA успешно установлен\n============================\n"
    	else
         echo -e "\n=================================\nОшибка при установке Easy-RSA.\nПожалуйста, проверьте наличие\nподключения к интернету и\nповторите попытку\n=================================\n"
	exit 1
    	fi

	# Проверяем, существует ли easy-rsa на сервере 
	if [ -d $EASYRSA_DIR ] && [ -d "$EASYRSA_DIR/pki" ] && [ -f "$EASYRSA_DIR/pki/ca.crt" ] ; then
        echo -e "\n=======================\nEasy-RSA уже создан\n=======================\n"
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
		echo
		echo "Запрос сертификата расположен: $EASYRSA_DIR/pki/reqs/server.req"
	
		#передадим файл запроса подписи на СА 
		if ! sudo -u "$USERNAME" scp $EASYRSA_DIR/pki/reqs/server.req $SERVER_CA:/home/$USER_CA; then
			echo "Файл запроса не удалось скопировать на сервер СА"
		fi
		
              sudo -u "$USERNAME" ssh -t $USER_CA@$IP_SERV_CA "/home/$USER_CA/bin/sign_req.sh server server.req"

        fi
        echo "Пакет Easy-RSA установлен, продолжим установку..."

fi

# проверим установку пакета openvpn 
if ! dpkg -s openvpn &> /dev/null; then
    echo -e "\n=============================\nПакет OpenVPN не установлен\nНачинаем установку...\n=============================\n"

    # Устанавливаем пакет openvpn
    apt-get update
    apt-get install -y openvpn
    apt-get install -y iptables-persistent
    echo "Пакет OpenVPN установлен"

    # Проверяем успешность установки
    if [ $? -eq 0 ]; then
        echo -e "\n===========================\nOpenVPN успешно установлен!\n===========================\n"
    else
        echo "Ошибка при установке OpenVPN. Пожалуйста, проверьте наличие подключения к интернету и повторите попытку."
        exit 1
    fi
else
    echo "Пакет OpenVPN уже установлен"
fi


cd /home/$USERNAME/easy-rsa
#генереруем ключ дополнительной защиты и копируем его в директорию сервера и клиентов
sudo -u "$USERNAME" openvpn --genkey --secret ta.key
sudo -u "$USERNAME" chmod -R 700 /home/$USERNAME/client-configs
cp /home/$USERNAME/easy-rsa/ta.key /etc/openvpn/server
sudo -u "$USERNAME" cp /home/$USERNAME/easy-rsa/ta.key $CLIENT_KEYS
#копируем подписанный ключ сервера 
cp /home/$USERNAME/easy-rsa/pki/private/server.key /etc/openvpn/server/
sudo -u "$USERNAME" cp /home/$USERNAME/ca.crt $CLIENT_KEYS
cp /home/$USERNAME/{server.crt,ca.crt} /etc/openvpn/server
rm /home/$USERNAME/{server.crt,ca.crt}

#####################################################################
#это потом должен сделать deb пакет
cp /home/$USERNAME/nanocorpinfra/config/server.conf /etc/openvpn/server/
#создадим группу nobody
groupadd nobody
#запустим сервер
systemctl -f enable openvpn-server@server.service
systemctl start openvpn-server@server.service
if [ $? -eq 0  ]; then
       echo -e "\n================================\nСервер OpenVPN запущен успешно\n================================\n"
else
       echo "Error: Сервер OpenVPN не запущен"
fi 

# Меняем значение параметра net.ipv4.ip_forward в файле /etc/sysctl.conf
sed -i "s/^#net.ipv4.ip_forward.*/net.ipv4.ip_forward = 1/" /etc/sysctl.conf
sysctl -p

#настраиваем iptables
#------------------------------------------------------------------------------------------------------
# функция, которая проверяет наличие правила в iptables и в случае отсутствия применяет его
iptables_add() {
  if ! iptables -C "$@" > /dev/null 2>&1; then
     iptables -A "$@"
  fi
}

# Разрешить трафик для loopback интерфейса
iptables_add  INPUT -i lo -j ACCEPT
iptables_add  OUTPUT -o lo -j ACCEPT

# Разрешить ICMP для ping
iptables_add INPUT -p icmp --icmp-type 8 -m state --state NEW,ESTABLISHED,RELATED -j ACCEPT
iptables_add OUTPUT -p icmp -m state --state NEW,ESTABLISHED,RELATED -j ACCEPT

# Разрешить соединения, установленные или уже существующие
iptables_add INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
iptables_add OUTPUT -m state --state ESTABLISHED,RELATED -j ACCEPT

# Разрешить DNS (порты 53 TCP и UDP)
iptables_add OUTPUT -p udp --dport 53 -j ACCEPT
iptables_add OUTPUT -p tcp --dport 53 -j ACCEPT
iptables_add INPUT -p udp --sport 53 -j ACCEPT
iptables_add INPUT -p tcp --sport 53 -j ACCEPT

# Разрешить соединения по SSH (порт 22)
iptables_add INPUT -p tcp --dport 22 -j ACCEPT

# Разрешить HTTP (порт 80)
iptables_add INPUT -p tcp --dport 80 -j ACCEPT

# Разрешить HTTPS (порт 443)
iptables_add INPUT -p tcp --dport 443 -j ACCEPT

# Разрешить OpenVPN (порт 1194)
iptables_add INPUT -p udp --dport 1194 -j ACCEPT

# Разрешить доступ к NTP (порты 123)
iptables_add INPUT -p udp --dport 123 -j ACCEPT
iptables_add OUTPUT -p udp --sport 123 -j ACCEPT

#трафик тунеля
iptables_add INPUT -i tun+ -j ACCEPT
iptables_add FORWARD -i tun+ -j ACCEPT
iptables_add FORWARD -i tun+ -o "$ETH" -m state --state RELATED,ESTABLISHED -j ACCEPT
iptables_add FORWARD -i "$ETH" -o tun+ -m state --state RELATED,ESTABLISHED -j ACCEPT

# Разрешить исходящий трафик (по умолчанию)
iptables -P OUTPUT ACCEPT

# Запретить входящий трафик (по умолчанию)
iptables -P INPUT DROP

# Применить правила NAT
iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
#--------------------------------------------------------------------------------------------------------

# сохраним правила iptables
netfilter-persistent save

echo -e "\n======================================\nOpenVPN успешно установлен!\n"
echo -e "Для создания клинта запустите скрипт: \n$CLIENT_CONF/client.sh\n"
echo -e "Готовые файлы настроек здесь:\n$CLIENT_FILES"
echo "======================================"
exit 0

