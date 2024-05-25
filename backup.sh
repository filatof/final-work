#!/bin/bash
#------------------------------------------------------------------------
# Script to make backup local server and send remote server 
#
# Developed by Ivan Filatoff
#------------------------------------------------------------------------


# Настройки
SOURCE_DIR="/home/fill/"                # Путь к директории с данными
BACKUP_DIR="/home/fill/backup"        # Локальная директория для сохранения архивов
REMOTE_DIR="/home/fill/backup_infra"       # Директория на резервном сервере
REMOTE_SERVER="192.168.0.6"             # Имя или IP адрес резервного сервера

# Удаление локальных архивов старше одного месяца
find ${BACKUP_DIR} -type f -name "backup_*.tar.gz" -mtime +30 -exec rm -f {} \;

# Проверка успешности удаления старых архивов
if [ $? -ne 0 ]; then
  echo "Удаление старых архивов не удалось!"
  exit 1
fi

# Получение текущей даты и времени
CURRENT_DATE=$(date +"%Y%m%d_%H%M%S")

# Имя архива
ARCHIVE_NAME="backup_${CURRENT_DATE}.tar.gz"

# Архивирование данных
tar -cvzf ${BACKUP_DIR}/${ARCHIVE_NAME} -C ${SOURCE_DIR} .

# Проверка успешности архивирования
if [ $? -ne 0 ]; then
  echo "Архивирование не удалось!"
  exit 1
fi

# Отправка архива на резервный сервер
rsync -avz --delete ${BACKUP_DIR}/${ARCHIVE_NAME} ${REMOTE_SERVER}:${REMOTE_DIR}

# Проверка успешности передачи данных
if [ $? -ne 0 ]; then
  echo "Передача данных на резервный сервер не удалась!"
  exit 1
fi

echo "Резервное копирование завершено успешно!"


