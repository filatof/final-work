#!/bin/bash
#------------------------------------------------------------------------
# Script to make connect to local repo 
#
# Developed by Ivan Filatoff
#------------------------------------------------------------------------

 #выполним backup файлов 
    cp /etc/apt/sources.list.d/own_repo.list /etc/apt/sources.list.d/own_repo.list.bkp
    cp /etc/apt/auth.conf.d/auth.conf /etc/apt/auth.conf.d/auth.conf.bkp

    # запросим логин и пароль для подключения к репозиторию
    read -r -p $'\n\n'"login for repo.nanocorpinfra.ru: " repo_login
    read -r -p "password for repo.nanocorpinfra.ru: " -s repo_pass

    # проверим файл /etc/apt/sources.list.d/own_repo.list на наличие записи о репозитории, и в случае ее отсутствия добавим
    if ! grep -Fxq "deb https://repo.nanocorpinfra.ru:4444/infra focal main" /etc/apt/sources.list.d/own_repo.list &>/dev/null; then
      echo "deb https://repo.nanocorpinfra.ru:4444/infra focal main" | tee -a /etc/apt/sources.list.d/own_repo.list >/dev/null
    fi

    # проверим файл /etc/apt/auth.conf.d/auth.conf на наличие записей о репозитории, и в случае их отсутствия добавим
    if ! grep -Fxq "machine repo.nanocorpinfra.ru:4444" /etc/apt/auth.conf.d/auth.conf &>/dev/null; then
      echo -e "machine repo.nanocorpinfra.ru:4444\nlogin $repo_login\npassword $repo_pass" | tee -a /etc/apt/auth.conf.d/auth.conf >/dev/null
    else
      # если в файле /etc/apt/auth.conf.d/auth.conf записи обнаружены, то попросим пользователя удалить их
      echo -e "\n\nrepo.nanocorpinfra.ru has been configured in /etc/apt/auth.conf.d/auth.conf!\nPlease manually clean configuration or skip this stage."
      exit 1
    fi

    # скачаем и установим gpg-ключ от репозитория
    if ! wget --no-check-certificate -P ~/ https://"$repo_login":"$repo_pass"@repo.nanocorpinfra.ru:4444/infra/labtest.asc; then
      echo "Не удалось скачать ключ gpg"
      exit 1
    else
      apt-key add ~/labtest.asc
    fi
     # скачаем и установим открытый ключ ca-сертификата от репозитория
    if ! wget --no-check-certificate -P /usr/local/share/ca-certificates/ https://"$repo_login":"$repo_pass"@repo.nanocorpinfra.ru:4444/infra/ca.crt; then
      echo "Не удалось скачать открытый сертификат СА"
      exit 1
    else
      update-ca-certificates
    fi

    apt update
    echo -e "\nDONE\n"
