
yc vpc network create --name infra-cloud

yc vpc security-group create --name nat-instance-sg --network-name infra-cloud 

yc vpc security-group update-rules nat-instance-sg \
--add-rule direction=ingress,port=22,protocol=tcp,v4-cidrs=0.0.0.0/0

yc vpc security-group update-rules nat-instance-sg \
--add-rule direction=ingress,port=80,protocol=tcp,v4-cidrs=0.0.0.0/0

yc vpc security-group update-rules nat-instance-sg \
--add-rule direction=ingress,port=443,protocol=tcp,v4-cidrs=0.0.0.0/0

yc vpc security-group update-rules nat-instance-sg \
--add-rule direction=ingress,port=1194,protocol=udp,v4-cidrs=0.0.0.0/0

yc vpc security-group update-rules nat-instance-sg \
--add-rule direction=egress,protocol=any,port=any,v4-cidrs=0.0.0.0/0

yc vpc security-group update-rules nat-instance-sg \
--add-rule direction=ingress,port=any,protocol=any,v4-cidrs=192.168.0.0/24
yc vpc security-group update-rules nat-instance-sg \
--add-rule direction=ingress,port=any,protocol=any,v4-cidrs=10.1.0.0/24


yc vpc subnet create \
        --name private-subnet \
        --network-name infra-cloud \
        --zone ru-central1-a \
        --range 192.168.0.0/24 \
        --description "Private subnet"

yc vpc subnet create \
        --name public-subnet \
        --network-name infra-cloud \
        --zone ru-central1-a \
        --range 10.1.0.0/24 \
        --description "Public subnet"
yc vpc route-table create --name nat-instance-route --network-name infra-cloud
yc vpc route-table update nat-instance-route --route destination=0.0.0.0/0,next-hop=10.1.0.3
yc vpc subnet update private-subnet --route-table-name=nat-instance-route

NAME_SG=$(yc vpc security-group get --name nat-instance-sg | grep -m 1 'id:' | cut -d ' ' -f 2)


META=$1


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
