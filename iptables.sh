# функция, которая проверяет наличие правила в iptables и в случае отсутствия применяет его
#iptables_add() {
#  if ! iptables -C "$@" > /dev/null 2>&1; then
   # iptables -A "$@"
 # fi
#}

# Разрешить трафик для loopback интерфейса
sudo iptables -A INPUT -i lo -j ACCEPT
sudo iptables -A OUTPUT -o lo -j ACCEPT

# Разрешить ICMP для ping
sudo iptables -A INPUT -p icmp --icmp-type 8 -m state --state NEW,ESTABLISHED,RELATED -j ACCEPT
sudo iptables -A OUTPUT -p icmp -m state --state NEW,ESTABLISHED,RELATED -j ACCEPT

# Разрешить соединения, установленные или уже существующие
sudo iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
sudo iptables -A OUTPUT -m state --state ESTABLISHED,RELATED -j ACCEPT

# Разрешить DNS (порты 53 TCP и UDP)
sudo iptables -A OUTPUT -p udp --dport 53 -j ACCEPT
sudo iptables -A OUTPUT -p tcp --dport 53 -j ACCEPT
sudo iptables -A INPUT -p udp --sport 53 -j ACCEPT
sudo iptables -A INPUT -p tcp --sport 53 -j ACCEPT

# Разрешить соединения по SSH (порт 22)
sudo iptables -A INPUT -p tcp --dport 22 -j ACCEPT

# Разрешить HTTP (порт 80)
sudo iptables -A INPUT -p tcp --dport 80 -j ACCEPT

# Разрешить HTTPS (порт 443)
sudo iptables -A INPUT -p tcp --dport 443 -j ACCEPT

# Разрешить OpenVPN (порт 1194)
sudo iptables -A INPUT -p udp --dport 1194 -j ACCEPT

# Разрешить доступ к NTP (порты 123)
sudo iptables -A INPUT -p udp --dport 123 -j ACCEPT
sudo iptables -A OUTPUT -p udp --sport 123 -j ACCEPT

#трафик тунеля
sudo iptables -A INPUT -i tun+ -j ACCEPT
sudo iptables -A FORWARD -i tun+ -j ACCEPT
sudo iptables -A FORWARD -i tun+ -o eth0 -m state --state RELATED,ESTABLISHED -j ACCEPT
sudo iptables -A FORWARD -i eth0 -o tun+ -m state --state RELATED,ESTABLISHED -j ACCEPT
#iptables -t nat -A POSTROUTING -s 10.8.0.0/24 -o eth0 -j MASQUERADE

# Разрешить исходящий трафик (по умолчанию)
sudo iptables -P OUTPUT ACCEPT

# Запретить входящий трафик (по умолчанию)
sudo iptables -P INPUT DROP

# Применить правила NAT
sudo iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
