#!/bin/bash
# Скрипт создает виртуальную машину в Яндекс облаке
# передайте аргументы hostname и файл с метаданными
# файл с метаданными исправить под свои настройки и 
# висать открытый ключ
#
HOSTNAME=$1
META=$2

yc compute instance create \
  --name $HOSTNAME \
  --hostname  $HOSTNAME \
  --zone ru-central1-a \
  --network-interface subnet-name=my-subnet,nat-ip-version=ipv4 \
  --preemptible \
  --create-boot-disk image-folder-id=standard-images,image-family=ubuntu-2204-lts,size=10GB \
  --platform standard-v1 \
  --cores 2 \
  --memory 2GB \
  --metadata-from-file user-data=$META
