#!/bin/bash
#--------------------------------------------------------------------
# Script to Install AlertManager  Ubuntu or Debian 
#
# Developed by Ivan Filatoff
#--------------------------------------------------------------------
# сохраним имя исходного пользователя
USERNAME="$SUDO_USER"
# Если имя пользователя не определено, выходим с ошибкой
if [ -z "$USERNAME" ]; then
    echo "Ошибка: не удалось определить имя пользователя."
    exit 1
fi

#если передан параметр -u то удаляем 
if [ "$1" = "-u" ]; then
    read -p "Вы уверены, что хотите удалить alertmanager  и все файлы? (yes or no): " remove
    if [ "$remove" = 'yes' ]; then
         systemctl stop prometheus-alertmanager.service
         systemctl disable prometheus-alertmanager.service
	 rm /usr/bin/alertmanager
	 rm /usr/local/bin/alertmanager
	 rm /usr/bin/amtool 
	 rm /usr/local/bin/amtool
	 rm /etc/promrtheus/alertmanager.yml
	 rm /etc/prometheus/rules.yml
         rm -rf /etc/prometheus/alertmanager_data
         rm /etc/systemd/system/prometheus-alertmanager.service
         iptables -D INPUT -p tcp --dport 9093 -j ACCEPT
         service netfilter-persistent save
         echo -e "\n================\nalertmanager удален\n================\n"
         exit 0
    fi
    exit 0
fi

NODE_DIR="alertmanager"
#проверим установлен ли node_exporter 
if  [ -f /usr/bin/alertmanager  ]; then
        echo "Alertmanager уже установлен"
        exit 0
fi

#создадим директорию и скачаем туда пакет
sudo -u "$USERNAME" mkdir /home/$USERNAME/$NODE_DIR
sudo -u "$USERNAME" wget -P /home/$USERNAME/$NODE_DIR https://github.com/prometheus/alertmanager/releases/download/v0.27.0/alertmanager-0.27.0.linux-amd64.tar.gz
sudo -u "$USERNAME" tar -xvf /home/$USERNAME/$NODE_DIR/alertmanager-0.27.0.linux-amd64.tar.gz -C /home/$USERNAME/$NODE_DIR

#копируем бинарник в систему
cp /home/$USERNAME/$NODE_DIR/alertmanager-0.27.0.linux-amd64/alertmanager /usr/bin/
cp /home/$USERNAME/$NODE_DIR/alertmanager-0.27.0.linux-amd64/amtool /usr/bin/
cp /home/$USERNAME/$NODE_DIR/alertmanager-0.27.0.linux-amd64/alertmanager.yml /etc/prometheus/
ln -s /usr/bin/amtool /usr/local/bin/amtool
ln -s /usr/bin/alertmanager /usr/local/bin/alertmanager

mkdir /etc/prometheus/alertmanager_data
touch /etc/prometheus/rules.yml

chown -R prometheus:prometheus /etc/prometheus/alertmanager_data
chmod -R 755 /etc/prometheus/alertmanager_data
chown prometheus:prometheus /usr/bin/amtool
chown -h prometheus:prometheus /usr/local/bin/amtool
chmod 755 /usr/bin/amtool
chown prometheus:prometheus /usr/bin/alertmanager
chown -h prometheus:prometheus /usr/local/bin/alertmanager
chmod 755 /usr/bin/alertmanager
chown prometheus:prometheus /etc/prometheus/alertmanager.yml 
chmod 755 /etc/prometheus/alertmanager.yml
chown prometheus:prometheus /etc/prometheus/rules.yml
chmod 755 /etc/prometheus/rules.yml

#создадим юнит
cat <<EOF> /etc/systemd/system/prometheus-alertmanager.service
[Unit]
Description=Alertmanager Service
After=network.target

[Service]
EnvironmentFile=-/etc/default/alertmanager
User=prometheus
Group=prometheus
Type=simple
ExecStart=/usr/bin/alertmanager \$ARGS --config.file=/etc/prometheus/alertmanager.yml --web.config.file=/etc/prometheus/web.yml --storage.path=/etc/prometheus/alertmanager_data
ExecReload=/bin/kill -HUP \$MAINPID
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF
#заполним файл rules алертами мониторинга
cat <<EOF> /etc/prometheus/rules.yml
groups:
- name: ca
  rules:
  - alert: CA_node_exporter_down
    expr: up{job="node-ca"} == 0
    for: 10s
    annotations:
      title: 'CA Node Exporter Down'
      description: 'CA Node Exporter Down'
    labels:
      severity: 'crit'

  - alert: CA_High_CPU_utiluzation
    expr: node_load1{job="node-ca"} > 0.9
    for: 1m
    annotations:
      title: 'High CPU utiluzation'
      description: 'High CPU utiluzation'
    labels:
      severity: 'crit'

  - alert: CA_High_memory_utiluzation
    expr: ((node_memory_MemAvailable_bytes{job="node-ca"} / node_memory_MemTotal_bytes{job="node-ca"}) * 100) < 10
    for: 1m
    annotations:
      title: 'High memory utiluzation'
      description: 'High memory utiluzation'
    labels:
      severity: 'crit'

  - alert: CA_Disc_space_problem
    expr: ((node_filesystem_avail_bytes{job="node-ca", mountpoint="/",fstype!="rootfs"} / node_filesystem_size_bytes{job="node-ca", mountpoint="/",fstype!="rootfs"}) * 100) < 10
    for: 10m
    annotations:
      title: 'Disk 90% full'
      description: 'Disk 90% full'
    labels:
      severity: 'crit'

  - alert: CA_High_port_incoming_utilization
    expr: (rate(node_network_receive_bytes_total{job="node-ca", device="eth0"}[5m]) / 1024 / 1024) > 150
    for: 5s
    annotations:
      title: 'High port input load'
      description: 'Incoming port load > 150 Mb/s'
    labels:
      severity: 'crit'

  - alert: CA_High_port_outcoming_utilization
    expr: (rate(node_network_transmit_bytes_total{ job="node-ca", device="eth0"}[5m]) / 1024 / 1024) > 150
    for: 5s
    annotations:
      title: High outbound port utilization
      description: 'Outcoming port load > 150 Mb/s'
    labels:
      severity: 'crit'

- name: vpn
  rules:
  - alert: Vpn_node_exporter_down
    expr: up{job="node-vpn"} == 0
    for: 10s
    annotations:
      title: 'Vpn Node Exporter Down'
      description: 'Vpn Node Exporter Down'
    labels:
      severity: 'crit'

  - alert: Vpn_exporter_down
    expr: up{job="openvpn"} == 0
    for: 10s
    annotations:
      title: 'Vpn Exporter Down'
      description: 'Vpn Exporter Down'
    labels:
      severity: 'crit'

  - alert: VpnDown
    expr: openvpn_up == 0
    for: 10s
    annotations:
      title: 'VPN Service down'
      description: 'VPN Service down'
    labels:
      severity: 'crit'

  - alert: Vpn_LimitClientConnected
    expr: openvpn_server_connected_clients == 100
    for: 10s
    annotations:
      title: 'Limit Client Connected'
      description: 'Limit Client Connected'
    labels:
      severity: 'crit'

  - alert: Vpn_High_CPU_utiluzation
    expr: node_load1{job="node-vpn"} > 0.9
    for: 1m
    annotations:
      title: 'High CPU utiluzation'
      description: 'High CPU utiluzation'
    labels:
      severity: 'crit'

  - alert: Vpn_High_memory_utiluzation
    expr: ((node_memory_MemAvailable_bytes{job="node-vpn"} / node_memory_MemTotal_bytes{job="node-vpn"}) * 100) < 10
    for: 1m
    annotations:
      title: 'High memory utiluzation'
      description: 'High memory utiluzation'
    labels:
      severity: 'crit'

  - alert: Vpn_Disc_space_problem
    expr: ((node_filesystem_avail_bytes{job="node-vpn", mountpoint="/",fstype!="rootfs"} / node_filesystem_size_bytes{job="node-vpn", mountpoint="/",fstype!="rootfs"}) * 100) < 10
    for: 10m
    annotations:
      title: 'Disk 90% full'
      description: 'Disk 90% full'
    labels:
      severity: 'crit'

  - alert: Vpn_High_port_incoming_utilization
    expr: (rate(node_network_receive_bytes_total{job="node-vpn", device="eth0"}[5m]) / 1024 / 1024) > 150
    for: 5s
    annotations:
      title: 'High port input load'
      description: 'Incoming port load > 150 Mb/s'
    labels:
      severity: 'crit'

  - alert: Vpn_High_port_outcoming_utilization
    expr: (rate(node_network_transmit_bytes_total{ job="node-vpn", device="eth0"}[5m]) / 1024 / 1024) > 150
    for: 5s
    annotations:
      title: High outbound port utilization
      description: 'Outcoming port load > 150 Mb/s'
    labels:
      severity: 'crit'

- name: monitor
  rules:
  - alert: Monitor_node_exporter_down
    expr: up{job="node-monitor"} == 0
    for: 10s
    annotations:
      title: 'Monitor Node Exporter Down'
      description: 'Monitor Node Exporter Down'
    labels:
      severity: 'crit'

  - alert: Monitor_prometheus_exporter_down
    expr: up{job="prometheus-monitor"} == 0
    for: 10s
    annotations:
      title: 'Monitor Node Exporter Down'
      description: 'Monitor Node Exporter Down'
    labels:
      severity: 'crit'

  - alert: Monitor_High_CPU_utiluzation
    expr: node_load1{job="node-monitor"} > 0.9
    for: 1m
    annotations:
      title: 'High CPU utiluzation'
      description: 'High CPU utiluzation'
    labels:
      severity: 'crit'

  - alert: Monitor_High_memory_utiluzation
    expr: ((node_memory_MemAvailable_bytes{job="node-monitor"} / node_memory_MemTotal_bytes{job="node-monitor"}) * 100) < 10
    for: 1m
    annotations:
      title: 'High memory utiluzation'
      description: 'High memory utiluzation'
    labels:
      severity: 'crit'

  - alert: Monitor_Disc_space_problem
    expr: ((node_filesystem_avail_bytes{job="node-monitor", mountpoint="/",fstype!="rootfs"} / node_filesystem_size_bytes{job="node-monitor", mountpoint="/",fstype!="rootfs"}) * 100) < 10
    for: 10m
    annotations:
      title: 'Disk 90% full'
      description: 'Disk 90% full'
    labels:
      severity: 'crit'

  - alert: Monitor_High_port_incoming_utilization
    expr: (rate(node_network_receive_bytes_total{job="node-monitor", device="eth0"}[5m]) / 1024 / 1024) > 150
    for: 5s
    annotations:
      title: 'High port input load'
      description: 'Incoming port load > 150 Mb/s'
    labels:
      severity: 'crit'

  - alert: Monitor_High_port_outcoming_utilization
    expr: (rate(node_network_transmit_bytes_total{ job="node-monitor", device="eth0"}[5m]) / 1024 / 1024) > 150
    for: 5s
    annotations:
      title: High outbound port utilization
      description: 'Outcoming port load > 150 Mb/s'
    labels:
      severity: 'crit'

- name: repo
  rules:
  - alert: Repo_node_exporter_down
    expr: up{job="node-repo"} == 0
    for: 10s
    annotations:
      title: 'Repo Node Exporter Down'
      description: 'Repo Node Exporter Down'
    labels:
      severity: 'crit'

  - alert: Repo_nginx_exporter_down
    expr: up{job="nginx-repo"} == 0
    for: 10s
    annotations:
      title: 'Repo Nginx Exporter Down'
      description: 'Repo Nginx Exporter Down'
    labels:
      severity: 'crit'

  - alert: Repo_NginxDown
    expr: nginx_up == 0
    for: 10s
    annotations:
      title: 'Nginx Service down'
      description: 'Nginx Service down'
    labels:
      severity: 'crit'

  - alert: Repo_NoActiveClientConnections
    expr: nginx_connections_active == 1
    for: 10s
    annotations:
      title: 'No active connections'
      description: 'No active connections except nginx exporter'
    labels:
      severity: 'crit'

  - alert: Repo_NoActiveConnections
    expr: nginx_connections_active == 0
    for: 10s
    annotations:
      title: 'No active connections'
      description: 'No active connections'
    labels:
      severity: 'crit'

  - alert: Repo_High_CPU_utiluzation
    expr: node_load1{job="node-repo"} > 0.9
    for: 1m
    annotations:
      title: 'High CPU utiluzation'
      description: 'High CPU utiluzation'
    labels:
      severity: 'crit'

  - alert: Repo_High_memory_utiluzation
    expr: ((node_memory_MemAvailable_bytes{job="node-repo"} / node_memory_MemTotal_bytes{job="node-repo"}) * 100) < 10
    for: 1m
    annotations:
      title: 'High memory utiluzation'
      description: 'High memory utiluzation'
    labels:
      severity: 'crit'

  - alert: Repo_Disc_space_problem
    expr: ((node_filesystem_avail_bytes{job="node-repo", mountpoint="/",fstype!="rootfs"} / node_filesystem_size_bytes{job="node-repo", mountpoint="/",fstype!="rootfs"}) * 100) < 10
    for: 10m
    annotations:
      title: 'Disk 90% full'
      description: 'Disk 90% full'
    labels:
      severity: 'crit'

  - alert: Repo_High_port_incoming_utilization
    expr: (rate(node_network_receive_bytes_total{job="node-repo", device="eth0"}[5m]) / 1024 / 1024) > 150
    for: 5s
    annotations:
      title: 'High port input load'
      description: 'Incoming port load > 150 Mb/s'
    labels:
      severity: 'crit'

  - alert: Repo_High_port_outcoming_utilization
    expr: (rate(node_network_transmit_bytes_total{ job="node-repo", device="eth0"}[5m]) / 1024 / 1024) > 150
    for: 5s
    annotations:
      title: High outbound port utilization
      description: 'Outcoming port load > 150 Mb/s'
    labels:
      severity: 'crit'
EOF

systemctl daemon-reload
systemctl restart prometheus-alertmanager.service
systemctl enable prometheus-alertmanager.service

#добавим правила для пропуска на порт 9093
iptables -A INPUT -p tcp --dport 9093 -j ACCEPT
#сохраним настройки iptables
service netfilter-persistent save


echo -e "\n====================\nNode Exporter listening on port 9100\n====================\n"
echo -e "\nOK\n"

