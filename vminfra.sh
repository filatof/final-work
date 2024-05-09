#!/bin/bash
# Скрипт создает виртуальную машину в Яндекс облаке
# передайте аргументы hostname и файл с метаданными
# файл с метаданными исправить под свои настройки и 
# висать открытый ключ
#
#HOSTNAME=$1
META=$1

yc compute instance create \
  --name ca \
  --hostname  ca \
  --zone ru-central1-a \
  --network-interface subnet-name=my-subnet,nat-ip-version=ipv4,ip-address=192.168.0.3 \
  --preemptible \
  --create-boot-disk image-folder-id=standard-images,image-family=ubuntu-2204-lts,size=10GB \
  --platform standard-v1 \
  --cores 2 \
  --core-fraction 5 \
  --memory 1GB \
  --metadata-from-file user-data=$META

yc compute instance create \
  --name vpn \
  --hostname  vpn \
  --zone ru-central1-a \
  --network-interface subnet-name=my-subnet,nat-ip-version=ipv4,ip-address=192.168.0.4 \
  --preemptible \
  --create-boot-disk image-folder-id=standard-images,image-family=ubuntu-2204-lts,size=10GB \
  --platform standard-v1 \
  --cores 2 \
  --core-fraction 5 \
  --memory 1GB \
  --metadata-from-file user-data=$META

yc compute instance create \
  --name monitor \
  --hostname  monitor \
  --zone ru-central1-a \
  --network-interface subnet-name=my-subnet,nat-ip-version=ipv4,ip-address=192.168.0.5 \
  --preemptible \
  --create-boot-disk image-folder-id=standard-images,image-family=ubuntu-2204-lts,size=10GB \
  --platform standard-v1 \
  --cores 2 \
  --core-fraction 5 \
  --memory 1GB \
  --metadata-from-file user-data=$META

yc compute instance create \
  --name repo \
  --hostname  repo \
  --zone ru-central1-a \
  --network-interface subnet-name=my-subnet,nat-ip-version=ipv4,ip-address=192.168.0.6 \
  --preemptible \
  --create-boot-disk image-folder-id=standard-images,image-family=ubuntu-2204-lts,size=10GB \
  --platform standard-v1 \
  --cores 2 \
  --core-fraction 5 \
  --memory 1GB \
  --metadata-from-file user-data=$META
