NAME_CLOUD="infracloud"
NAME_FOLDER="infra-folder"
NAME_NET="infra-net"
NAME_SUBNET="infra-subnet"
SG="nat-sg-infra-net"
NAME_NAT="nat-infra-route"
PRIVATE_SUBNET="priv-subnet"
PUBLIC_SUBNET="pub-subnet"
# Создание облака
#yc resource-manager cloud create --name $NAME_CLOUD
#yc config set cloud-id  < > 

# Создание каталога 
yc resource-manager folder create --name $NAME_FOLDER 
yc config set folder-name $NAME_FOLDER

# Создание сети 
yc vpc network create --name $NAME_NET --folder-name $NAME_FOLDER

#Создадим группу безопасности 
yc vpc security-group create  --name $SG --network-name $NAME_NET --folder-name $NAME_FOLDER

#напишем правила в группу безопасности
#Резрешен весь трафик во внутренней сети и весть исходящий трафик:
#Входящий трафик разрешен только на порты 22,80, 443, 1194
#все остальное запрещено
yc vpc security-group update-rules --name $SG --folder-name $NAME_FOLDER \
--add-rule direction=ingress,port=any,protocol=any,v4-cidrs=192.168.0.0/25

yc vpc security-group update-rules --name $SG --folder-name $NAME_FOLDER \
--add-rule direction=ingress,port=any,protocol=any,v4-cidrs=192.168.0.128/25
# port ssh
yc vpc security-group update-rules --name $SG --folder-name $NAME_FOLDER \
--add-rule direction=ingress,port=22,protocol=tcp,v4-cidrs=0.0.0.0/0
# http
yc vpc security-group update-rules --name $SG --folder-name $NAME_FOLDER \
--add-rule direction=ingress,port=80,protocol=tcp,v4-cidrs=0.0.0.0/0
# https
yc vpc security-group update-rules --name $SG --folder-name $NAME_FOLDER \
--add-rule direction=ingress,port=443,protocol=tcp,v4-cidrs=0.0.0.0/0
# openvpn
yc vpc security-group update-rules --name $SG --folder-name $NAME_FOLDER \
--add-rule direction=ingress,port=1194,protocol=udp,v4-cidrs=0.0.0.0/0
# monitoring prometheus
yc vpc security-group update-rules --name $SG --folder-name $NAME_FOLDER \
--add-rule direction=ingress,port=9090,protocol=udp,v4-cidrs=0.0.0.0/0
# node exporter
yc vpc security-group update-rules --name $SG --folder-name $NAME_FOLDER \
--add-rule direction=ingress,port=9100,protocol=udp,v4-cidrs=0.0.0.0/0
# openvpn exporter
yc vpc security-group update-rules --name $SG --folder-name $NAME_FOLDER \
--add-rule direction=ingress,port=9176,protocol=udp,v4-cidrs=0.0.0.0/0
# nginx exporter
yc vpc security-group update-rules --name $SG --folder-name $NAME_FOLDER \
--add-rule direction=ingress,port=9113,protocol=udp,v4-cidrs=0.0.0.0/0

yc vpc security-group update-rules --name $SG --folder-name $NAME_FOLDER \
--add-rule direction=egress,protocol=any,port=any,v4-cidrs=0.0.0.0/0

#Создадим две подсети. Назвал из public-subnet private-subnet
#В приватной будут сервер СА, сервер мониторинга, сервер репозитория
yc vpc subnet create \
        --name $PRIVATE_SUBNET \
        --network-name $NAME_NET \
        --zone ru-central1-a \
        --range 192.168.0.0/25 \
        --description "Private subnet "
#в публичной подсети будет сервер ВПН с публичным адресом, будет выступать NAT сервером, 
#за ним будет вся сеть инфраструктуры
yc vpc subnet create \
        --name $PUBLIC_SUBNET \
        --network-name $NAME_NET \
        --zone ru-central1-a \
        --range 192.168.0.128/25 \
        --description "Public subnet"
#Создадим таблицу маршрутизации
yc vpc route-table create --name $NAME_NAT --network-name $NAME_NET
#назначим ВПН сервер с внутренним ip  шлюзом по умолчанию
yc vpc route-table update $NAME_NAT --route destination=0.0.0.0/0,next-hop=192.168.0.131
#привяжем таблицу маршрутизации к приватной подсети
yc vpc subnet update $PRIVATE_SUBNET --route-table-name=$NAME_NAT
#сохраним в переменную ИД группы безопасности, чтобы потом передать его ВМ при создании
NAME_SG=$(yc vpc security-group get --name $SG | grep -m 1 'id:' | cut -d ' ' -f 2)
#файл с метаданными
META=$1
#Создаем однотипные ВМ, с самой минимальной конфигурацией, для выполнения итоговой работы. 
#Если нужно больше вычислений потом можно поправить 
#ВМ присваиваю сразу внутренние адреса
yc compute instance create \
  --name ca \
  --hostname  ca \
  --zone ru-central1-a \
  --network-interface subnet-name=$PRIVATE_SUBNET,security-group-ids=$NAME_SG,ipv4-address=192.168.0.3 \
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
  --network-interface subnet-name=$PUBLIC_SUBNET,security-group-ids=$NAME_SG,nat-ip-version=ipv4,ipv4-address=192.168.0.131 \
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
  --network-interface subnet-name=$PRIVATE_SUBNET,security-group-ids=$NAME_SG,ipv4-address=192.168.0.5 \
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
  --network-interface subnet-name=$PRIVATE_SUBNET,security-group-ids=$NAME_SG,ipv4-address=192.168.0.6 \
  --preemptible \
  --create-boot-disk image-folder-id=standard-images,image-family=ubuntu-2204-lts,size=10GB \
  --platform standard-v1 \
  --cores 2 \
  --core-fraction 5 \
  --memory 1GB \
  --metadata-from-file user-data=$META
