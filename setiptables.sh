

# функция, которая проверяет наличие правила в iptables и в случае отсутствия применяет его
iptables_add() {
  if ! iptables -C "$@" > /dev/null 2>&1; then
     iptables -A "$@"
  fi
}

# Разрешить трафик для loopback интерфейса
iptables_add  INPUT -i lo -j ACCEPT
iptables_add  OUTPUT -o lo -j ACCEPT

# Разрешить ICMP для ping
iptables_add INPUT -p icmp --icmp-type 8 -m state --state NEW,ESTABLISHED,RELATED -j ACCEPT
iptables_add OUTPUT -p icmp -m state --state NEW,ESTABLISHED,RELATED -j ACCEPT

# Разрешить соединения, установленные или уже существующие
iptables_add INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
iptables_add OUTPUT -m state --state ESTABLISHED,RELATED -j ACCEPT

# Разрешить DNS (порты 53 TCP и UDP)
iptables_add OUTPUT -p udp --dport 53 -j ACCEPT
iptables_add OUTPUT -p tcp --dport 53 -j ACCEPT
iptables_add INPUT -p udp --sport 53 -j ACCEPT
iptables_add INPUT -p tcp --sport 53 -j ACCEPT

# Разрешить соединения по SSH (порт 22)
iptables_add INPUT -p tcp --dport 22 -j ACCEPT

# Разрешить HTTP (порт 80)
iptables_add INPUT -p tcp --dport 80 -j ACCEPT

# Разрешить HTTPS (порт 443)
iptables_add INPUT -p tcp --dport 443 -j ACCEPT

# Разрешить OpenVPN (порт 1194)
iptables_add INPUT -p udp --dport 1194 -j ACCEPT

# Разрешить доступ к NTP (порты 123)
iptables_add INPUT -p udp --dport 123 -j ACCEPT
iptables_add OUTPUT -p udp --sport 123 -j ACCEPT

#трафик тунеля
iptables_add INPUT -i tun+ -j ACCEPT
iptables_add FORWARD -i tun+ -j ACCEPT
iptables_add FORWARD -i tun+ -o eth0 -m state --state RELATED,ESTABLISHED -j ACCEPT
iptables_add FORWARD -i eth0 -o tun+ -m state --state RELATED,ESTABLISHED -j ACCEPT

# Разрешить исходящий трафик (по умолчанию)
iptables -P OUTPUT ACCEPT

# Запретить входящий трафик (по умолчанию)
iptables -P INPUT DROP

# Применить правила NAT
iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE

#проброс к repo по http
iptables -t nat -A PREROUTING -i eth0 -p tcp --dport 4444 -j DNAT --to-destination 192.168.0.6:4444
iptables -A FORWARD -p tcp -d 192.168.0.6 --dport 4444 -j ACCEPT

# проброс к prometheus
iptables -t nat -A PREROUTING -i eth0 -p tcp --dport 9090 -j DNAT --to-destination 192.168.0.5:9090
iptables -A FORWARD -p tcp -d 192.168.0.5 --dport 9090 -j ACCEPT
# проброс node exporter
iptables -t nat -A PREROUTING -i eth0 -p tcp --dport 9100 -j DNAT --to-destination 192.168.0.5:9100
iptables -A FORWARD -p tcp -d 192.168.0.5 --dport 9100 -j ACCEPT
#проброс openvpn
iptables -t nat -A PREROUTING -i eth0 -p tcp --dport 9176 -j DNAT --to-destination 192.168.0.5:9176
iptables -A FORWARD -p tcp -d 192.168.0.5 --dport 9176 -j ACCEPT


