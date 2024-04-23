#!/bin/bash

# easy-rs
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

