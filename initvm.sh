#!/bin/bash
#--------------------------------------------------------------------
# Script to inicialising first run  VM   
#
# Developed by Ivan Filatoff
#--------------------------------------------------------------------
# сохраним имя исходного пользователя
USERNAME="$SUDO_USER"
# Если имя пользователя не определено, выходим с ошибкой
if [ -z "$USERNAME" ]; then
    echo "Ошибка: не удалось определить имя пользователя."
    exit 1
fi

#установим Московское время
echo -e "\n=======================\nSetting timezone Moscow\n======================="
timedatectl set-timezone Europe/Moscow

# проверяем, что файл не пустой
if [ -s "var.conf" ]; then
  # загружаем параметры из файла
  source var.conf
else
  echo "Error: var.conf пустой. Заполните файл в соответсвии с Вашей конфигурацией"
  exit 1
fi

# функция, которая проверяет наличие пакета в системе и в случае его отсутствия выполняет установку
command_check() {
  if ! command -v "$1" &>/dev/null; then
    echo -e "\n====================\n$2 could not be found!\nInstalling...\n====================\n"
    apt-get install -y "$3"
    echo -e "\nDONE\n"
  fi
}

# функция, которая проверяет наличие правила в iptables и в случае отсутствия применяет его
iptables_add() {
  if ! iptables -C "$@" &>/dev/null; then
    iptables -A "$@"
  fi
}

# функция, которая выполняет backup файла путем копирования его и модификации названия
bkp() {
  if [ -f "$1" ]; then
    cp "$1" "$1".bkp
  fi
}

# функция, которая восстанавливает файл из backup
restore_bkp() {
  if [ -f "$1".bkp ]; then
    if [ -f "$1" ]; then
      rm "$1" && mv "$1".bkp "$1"
    else
      mv "$1".bkp "$1"
    fi
  else
    echo -e "\nCan't find backup file!\n"
  fi
}

##########################################################
# Начало настройки системы

# установим все необходимые пакеты используя функцию command_check
apt-get update
command_check wget "Wget" wget
command_check iptables "Iptables" iptables
command_check netfilter-persistent "Netfilter-persistent" iptables-persistent
command_check openssl "Openssl" openssl
command_check update-ca-certificates "Ca-certificates" ca-certificates
command_check tee "Tee" coreutils



# проверим наличие конфигурационного файла ssh
if [ ! -f /etc/ssh/sshd_config ]; then
  echo -e "\n====================\nFile /etc/ssh/sshd_config not found!\n====================\n"
  exit 1
fi

# проверим наличие конфигурационного файла grub
if [ ! -f /etc/default/grub ]; then
  echo -e "\n====================\nFile /etc/default/grub not found!\n====================\n"
  exit 1
fi

# настроим ssh Изменим порт ssh , запретим рут логин, аутентификацию по паролю
echo -e "\n====================\nEdit sshd_config file\n===================="
echo -e "\nРедактировать настройки\n"
while true; do
  read -r -n 1 -p "Continue ? (y|n) " yn
  case $yn in
  [Yy]*)
    sed -i "s/#\?\(Port\s*\).*$/\1 $ssh_port/" /etc/ssh/sshd_config
    sed -i 's/#\?\(PermitRootLogin\s*\).*$/\1 no/' /etc/ssh/sshd_config
    sed -i 's/#\?\(PubkeyAuthentication\s*\).*$/\1 yes/' /etc/ssh/sshd_config
    sed -i 's/#\?\(PermitEmptyPasswords\s*\).*$/\1 no/' /etc/ssh/sshd_config
    sed -i 's/#\?\(PasswordAuthentication\s*\).*$/\1 no/' /etc/ssh/sshd_config
    echo -e "\n\n"
    /etc/init.d/ssh restart
    echo -e "\nDONE\n"
    break
    ;;

  [Nn]*)
    echo -e "\n"
    break
    ;;
  *) echo -e "\nPlease answer Y or N!\n" ;;
  esac
done

# выключим ipv6
echo -e "\n====================\nDisabling ipv6\n===================="
echo -e "\nОтключить ip версии 6\n"
echo
while true; do
  read -r -n 1 -p "Continue ? (y|n) " yn
  case $yn in
  [Yy]*)
    echo -e "\n\n"
    sed -i 's/^GRUB_CMDLINE_LINUX_DEFAULT="/&ipv6.disable=1 /' /etc/default/grub
    sed -i 's/^GRUB_CMDLINE_LINUX="/&ipv6.disable=1 /' /etc/default/grub
    update-grub
    echo -e "\nDONE\n"
    break
    ;;

  [Nn]*)
    echo -e "\nСработало нет"
    break
    ;;
  *) echo -e "\nPlease answer Y or N!\n" ;;
  esac
done

#запишем в файл hosts наши сервера с адресами.
echo "$IP_SERV_CA $CA.$DOMEN" >> /etc/hosts            
echo "$IP_SERV_VPN $VPN.$DOMEN" >> /etc/hosts
echo "$IP_SERV_MONITOR $MONITOR.$DOMEN" >> /etc/hosts
echo "$IP_SERV_REPO $REPO.$DOMEN" >> /etc/hosts

echo "$IP_SERV_CA $CA.$DOMEN" >> /etc/cloud/templates/hosts.debian.tmpl 
echo "$IP_SERV_VPN $VPN.$DOMEN" >> /etc/cloud/templates/hosts.debian.tmpl
echo "$IP_SERV_MONITOR $MONITOR.$DOMEN" >> /etc/cloud/templates/hosts.debian.tmpl
echo "$IP_SERV_REPO $REPO.$DOMEN" >> /etc/cloud/templates/hosts.debian.tmpl


# подключим репозиторий
# здесь мы подключим наш локальный репозиторий
# это нужно сделать после настройки сервера репо, при начальной настройке простить
echo -e "\n====================\nRepo config\n===================="
echo -e "\nЭто лучше сделать после настройки\nсервера репозитория в Вашей инфраструктуре\n"
while true; do
  read -r -n 1 -p "Continue ? (y|n) " yn
  echo -e "\n"
  case $yn in
  [Yy]*)
    #проверим существование файлов если да то сделаем бэкап иначе создадим файлы  
    if [ ! -f /etc/apt/sources.list.d/own_repo.list  ];then
	    touch /etc/apt/sources.list.d/own_repo.list
    else 
	    bkp /etc/apt/sources.list.d/own_repo.list
    fi

    if [ ! -f /etc/apt/auth.conf.d/auth.conf  ];then
	    touch /etc/apt/auth.conf.d/auth.conf
    else
	    bkp /etc/apt/auth.conf.d/auth.conf
    fi


    # запросим логин и пароль для подключения к репозиторию
    read -r -p $'\n\n'"login for $REPO.$DOMEN: " repo_login
    read -r -p "password for $REPO.$DOMEN: " -s repo_pass

    # проверим файл /etc/apt/sources.list.d/own_repo.list на наличие записи о репозитории, и в случае ее отсутствия добавим
    if ! grep -Fxq "deb https://$REPO.$DOMEN:$repo_port/infra focal main" /etc/apt/sources.list.d/own_repo.list &>/dev/null; then
      echo "deb https://$REPO.$DOMEN:$repo_port/infra focal main" | tee -a /etc/apt/sources.list.d/own_repo.list >/dev/null
    fi

    # проверим файл /etc/apt/auth.conf на наличие записей о репозитории, и в случае их отсутствия добавим
    if ! grep -Fxq "machine $REPO.$DOMEN:$repo_port" /etc/apt/auth.conf &>/dev/null; then
      echo -e "machine $REPO.$DOMEN:$repo_port\nlogin $repo_login\npassword $repo_pass" | tee -a /etc/apt/auth.conf >/dev/null
    else
      # если в файле /etc/apt/auth.conf записи обнаружены, то попросим пользователя удалить их
      echo -e "\n\nrepo.justnikobird.ru has been configured in /etc/apt/auth.conf!\nPlease manually clean configuration or skip this stage."
      restore_bkp /etc/apt/sources.list.d/own_repo.list
      restore_bkp /etc/apt/auth.conf.d/auth.conf
      exit 1
    fi

    # скачаем и установим gpg-ключ от репозитория
    if ! sudo -u "$USERNAME" wget --no-check-certificate -P /home/$USERNAME/  https://"$repo_login":"$repo_pass"@$REPO.$DOMEN:$repo_port/infra/infra.asc; then
      restore_bkp /etc/apt/sources.list.d/own_repo.list
      restore_bkp /etc/apt/auth.conf.d/auth.conf
      exit 1
    else
      gpg --dearmour -o /etc/apt/trusted.gpg.d/infra.gpg /home/$USERNAME/infra.asc
    fi

  # скачаем и установим открытый ключ ca-сертификата от репозитория
    if ! wget --no-check-certificate -P /usr/local/share/ca-certificates/ https://"$repo_login":"$repo_pass"@$REPO.$DOMEN:$repo_port/infra/ca.crt; then
      restore_bkp /etc/apt/sources.list.d/own_repo.list
      restore_bkp /etc/apt/auth.conf
      exit 1
    else
      update-ca-certificates
    fi

    # выполним синхронизацию списков пакетов в системе
    if ! apt update; then
      restore_bkp /etc/apt/sources.list.d/own_repo.list
      restore_bkp /etc/apt/auth.conf
      exit 1
    fi
    echo -e "\nDONE\n"
    break
    ;;

  [Nn]*)
    echo -e "\n"
    break
    ;;
  *) echo -e "\nPlease answer Y or N!\n" ;;
  esac
done

# настроим iptables
echo -e "\n====================\nIptables config\n===================="
echo -e "\nДобавим правила в iptables\n"
while true; do
  read -r -n 1 -p "Current ssh session may drop! To continue you have to relogin to this host via $ssh_port ssh-port and run this script again. Are you ready? (y|n) " yn
  case $yn in
  [Yy]*) #---DNS---
    iptables_add INPUT -p udp --sport 53 -j ACCEPT 
    iptables_add INPUT -p tcp --sport 53 -j ACCEPT 
    #---NTP---
    iptables_add INPUT -p udp --dport 123 -j ACCEPT
    #---ICMP---
    iptables_add OUTPUT -p icmp -m state --state NEW,ESTABLISHED,RELATED -j ACCEPT
    iptables_add INPUT -p icmp -m state --state NEW,ESTABLISHED,RELATED -j ACCEPT
    #---loopback---
    iptables_add OUTPUT -o lo -j ACCEPT
    iptables_add INPUT -i lo -j ACCEPT
    #---Input-SSH---
    iptables_add INPUT -p tcp --dport $ssh_port -j ACCEPT 
    #---ESTABLISHED---
    iptables_add INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
    iptables_add OUTPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
    #---INVALID---
    iptables_add OUTPUT -m state --state INVALID -j DROP
    iptables_add INPUT -m state --state INVALID -j DROP
    #---Defaul-
    iptables -P OUTPUT ACCEPT
    iptables -P INPUT DROP
    # save iptables config
    echo -e "\n====================\nSaving iptables config\n====================\n"
    service netfilter-persistent save
    echo -e "DONE\n"
    break
    ;;
  [Nn]*)
    echo -e "\n"
    exit
    ;;
  *) echo -e "\nPlease answer Y or N!\n" ;;
  esac
done

echo -e "\nOK\n"
exit 0
