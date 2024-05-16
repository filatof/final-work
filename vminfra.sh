
# Создание облака
yc resource-manager cloud create --name infracloud

# Создание каталога 
yc resource-manager folder create --name infrafolder --cloud-name infracloud

# Создание сети 
yc vpc network create --name infra-net --folder-name infrafolder

#Создадим группу безопасности 
yc vpc security-group create --name nat-instance-sg --network-name infra-net

#напишем правила в группу безопасности
#Резрешен весь трафик во внутренней сети и весть исходящий трафик
#Входящий трафик разрешен только на порты 22,80, 443, 1194
#все остальное запрещено
yc vpc security-group update-rules nat-instance-sg \
--add-rule direction=ingress,port=any,protocol=any,v4-cidrs=192.168.0.0/24

yc vpc security-group update-rules nat-instance-sg \
--add-rule direction=ingress,port=any,protocol=any,v4-cidrs=10.1.0.0/24
# port ssh
yc vpc security-group update-rules nat-instance-sg \
--add-rule direction=ingress,port=22,protocol=tcp,v4-cidrs=0.0.0.0/0
# http
yc vpc security-group update-rules nat-instance-sg \
--add-rule direction=ingress,port=80,protocol=tcp,v4-cidrs=0.0.0.0/0
# https
yc vpc security-group update-rules nat-instance-sg \
--add-rule direction=ingress,port=443,protocol=tcp,v4-cidrs=0.0.0.0/0
# openvpn
yc vpc security-group update-rules nat-instance-sg \
--add-rule direction=ingress,port=1194,protocol=udp,v4-cidrs=0.0.0.0/0
# monitoring prometheus
yc vpc security-group update-rules nat-instance-sg \
--add-rule direction=ingress,port=9090,protocol=udp,v4-cidrs=0.0.0.0/0
# node exporter
yc vpc security-group update-rules nat-instance-sg \
--add-rule direction=ingress,port=9100,protocol=udp,v4-cidrs=0.0.0.0/0
# openvpn exporter
yc vpc security-group update-rules nat-instance-sg \
--add-rule direction=ingress,port=9176,protocol=udp,v4-cidrs=0.0.0.0/0
# nginx exporter
yc vpc security-group update-rules nat-instance-sg \
--add-rule direction=ingress,port=9113,protocol=udp,v4-cidrs=0.0.0.0/0

yc vpc security-group update-rules nat-instance-sg \
--add-rule direction=egress,protocol=any,port=any,v4-cidrs=0.0.0.0/0

#Создадим две подсети. Назвал из public-subnet private-subnet
#В приватной будут сервер СА, сервер мониторинга, сервер репозитория
yc vpc subnet create \
        --name private-subnet \
        --network-name infra-cloud \
        --zone ru-central1-a \
        --range 192.168.0.0/24 \
        --description "Private subnet"
#в публичной подсети будет сервер ВПН с публичным адресом, будет выступать NAT сервером, 
#за ним будет вся сеть инфраструктуры
yc vpc subnet create \
        --name public-subnet \
        --network-name infra-cloud \
        --zone ru-central1-a \
        --range 10.1.0.0/24 \
        --description "Public subnet"
#Создадим таблицу маршрутизации
yc vpc route-table create --name nat-instance-route --network-name infra-cloud
#назначим ВПН сервер с внутренним ip 10.1.0.3 шлюзом по умолчанию
yc vpc route-table update nat-instance-route --route destination=0.0.0.0/0,next-hop=10.1.0.3
#привяжем таблицу маршрутизации к приватной подсети
yc vpc subnet update private-subnet --route-table-name=nat-instance-route
#сохраним в переменную ИД группы безопасности, чтобы потом передать его ВМ при создании
NAME_SG=$(yc vpc security-group get --name nat-instance-sg | grep -m 1 'id:' | cut -d ' ' -f 2)
#файл с метаданными
META=$1
#Создаем однотипные ВМ, с самой минимальной конфигурацией, для выполнения итоговой работы. 
#Если нужно больше вычислений потом можно поправить 
#ВМ присваиваю сразу внутренние адреса
yc compute instance create \
  --name ca \
  --hostname  ca \
  --zone ru-central1-a \
  --network-interface subnet-name=private-subnet,security-group-ids=$NAME_SG,ipv4-address=192.168.0.3 \
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
  --network-interface subnet-name=public-subnet,security-group-ids=$NAME_SG,nat-ip-version=ipv4,ipv4-address=10.1.0.3 \
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
  --network-interface subnet-name=private-subnet,security-group-ids=$NAME_SG,ipv4-address=192.168.0.5 \
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
  --network-interface subnet-name=private-subnet,security-group-ids=$NAME_SG,ipv4-address=192.168.0.6 \
  --preemptible \
  --create-boot-disk image-folder-id=standard-images,image-family=ubuntu-2204-lts,size=10GB \
  --platform standard-v1 \
  --cores 2 \
  --core-fraction 5 \
  --memory 1GB \
  --metadata-from-file user-data=$META
