#!/bin/bash

if [ $# -ne 3 ]; then
	echo "Ведите параметры: <интерфейс> <протокол> <порт>"
	exit 1
if
 
#передаем параметры в переменные
eth=$1
proto=$2
port=$3

#изменяем правила iptables 
iptables -A INPUT -i "$eth" -m state --state NEW -p "$proto" --dport "$port" -j ACCEPT
iptables -A INPUT -i tun+ -j ACCEPT
iptables -A FORWARD -i tun+ -j ACCEPT
iptables -A FORWARD -i tun+ -o "$eth" -m state --state RELATED,ESTABLISHED -j ACCEPT
iptables -A FORWARD -i "$eth" -o tun+ -m state --state RELATED,ESTABLISHED -j ACCEPT
iptables -t nat -A POSTROUTING -s 10.8.0.0/24 -o "$eth" -j MASQUERADE
