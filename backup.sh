#!/bin/bash
#------------------------------------------------------------------------
# Script to make backup local server and send remote server 
#
# Developed by Ivan Filatoff
#------------------------------------------------------------------------

# Настройки
SERVER="servername"
# Массив директорий с данными
SOURCE_DIR=("/home/fill/" "/etc/openvpn/server" "/opt/openvpn_exporter")                
REMOTE_USER="fill"                        # Пользователь на резервном сервере
REMOTE_SERVER="192.168.0.6"             # Имя или IP адрес резервного сервера
REMOTE_DIR="/tmp/backup"       # Директория на резервном сервере для временного хранения данных
ARCHIVE_DIR="/home/fill/backup_infra"            # Директория на резервном сервере для сохранения архивов


# Получение текущей даты и времени
CURRENT_DATE=$(date +"%Y%m%d_%H%M%S")

# Имя архива
ARCHIVE_NAME="backup_${SERVER}_${CURRENT_DATE}.tar.gz"

# Передача данных на резервный сервер
rsync -avz --delete ${SOURCE_DIR} ${REMOTE_USER}@${REMOTE_SERVER}:${REMOTE_DIR}

# Проверка успешности передачи данных
if [ $? -ne 0 ]; then
  echo "Передача данных на резервный сервер не удалась!"
  exit 1
fi

# Архивирование данных на резервном сервере
ssh ${REMOTE_USER}@${REMOTE_SERVER} "tar -cvzf ${ARCHIVE_DIR}/${ARCHIVE_NAME} -C ${REMOTE_DIR} . && rm -rf ${REMOTE_DIR}/*"

# Проверка успешности архивирования и очистки
if [ $? -ne 0 ]; then
  echo "Архивирование данных на резервном сервере не удалось!"
  exit 1
fi
echo "Резервное копирование завершено успешно!"
