#!/bin/bash
#------------------------------------------------------------------------
# Script to make backup local server and send remote server 
#
# Developed by Ivan Filatoff
#------------------------------------------------------------------------

# Настройки
SERVER="monitor"
# Массив директорий с данными
SOURCE_DIRS=("/home/fill/" "/etc/prometheus" "/opt/node_exporter")                
REMOTE_USER="fill"                        # Пользователь на резервном сервере
REMOTE_SERVER="192.168.0.6"             # Имя или IP адрес резервного сервера
REMOTE_DIR="/tmp/backup"       # Директория на резервном сервере для временного хранения данных
ARCHIVE_DIR="/home/fill/backup_infra"            # Директория на резервном сервере для сохранения архивов


# Получение текущей даты и времени
CURRENT_DATE=$(date +"%Y%m%d_%H%M%S")

# Имя архива
ARCHIVE_NAME="backup_${SERVER}_${CURRENT_DATE}.tar.gz"


echo "Начало резервного копирования..."

# Передача данных на резервный сервер
for DIR in "${SOURCE_DIRS[@]}"; do
  BASENAME=$(basename ${DIR})
  REMOTE_PATH="${REMOTE_DIR}/${BASENAME}_${SERVER}"

  echo "Создание директории на удаленном сервере: ${REMOTE_PATH}"
  ssh ${REMOTE_USER}@${REMOTE_SERVER} "mkdir -p ${REMOTE_PATH}"
  if [ $? -ne 0 ]; then
    echo "Не удалось создать директорию на удаленном сервере: ${REMOTE_PATH}"
    exit 1
  fi

  echo "Передача данных из ${DIR} в ${REMOTE_PATH}"
  rsync -avz --delete "${DIR}/" "${REMOTE_USER}@${REMOTE_SERVER}:${REMOTE_PATH}"
  if [ $? -ne 0 ]; then
    echo "Передача данных из ${DIR} на резервный сервер не удалась!"
    exit 1
  fi
done

echo "Архивирование данных на резервном сервере в файл ${ARCHIVE_DIR}/${ARCHIVE_NAME}"
ssh ${REMOTE_USER}@${REMOTE_SERVER} "tar -cvzf ${ARCHIVE_DIR}/${ARCHIVE_NAME} -C ${REMOTE_DIR} ."

if [ $? -ne 0 ]; then
  echo "Архивирование данных на резервном сервере не удалось!"
  exit 1
fi

echo "Резервное копирование и архивирование завершено успешно!"
