#!/bin/bash
#
#--------------------------------------------------------------------
# Script to signing sertificate CA
#
# Developed by Ivan Filatoff
#
# dep install jd 
#--------------------------------------------------------------------

# Путь к вашему запросу на подписание сертификата (CSR)
csr_path="/home/fill/practice-csr/vpn-server.req"

# Адрес сервера СА
ca_server_url="https://ca-server/sign_certificate"

# Авторизация пользователя (замените на соответствующие значения)
username="your_username"
password="your_password"

# Чтение CSR-файла
csr=$(cat "$csr_path")

# Отправка запроса на подписание сертификата
response=$(curl -s -X POST -u "$username:$password" -d "csr=$csr" "$ca_server_url")

# Проверка статуса ответа
if [[ "$response" == *"Error"* ]]; then
    echo "Error: Failed to sign certificate."
    echo "Error message: $(echo "$response" | jq -r '.error')"
    exit 1
fi

# Извлечение подписанного сертификата и сертификата сервера СА
signed_cert=$(echo "$response" | jq -r '.signed_cert')
ca_cert=$(echo "$response" | jq -r '.ca_cert')

# Сохранение подписанного сертификата
echo "$signed_cert" > "/home/fill/signed_certificate.crt"

# Сохранение сертификата сервера СА
echo "$ca_cert" > "/home/fill/ca_certificate.crt"

echo "Certificate signed and saved successfully."
