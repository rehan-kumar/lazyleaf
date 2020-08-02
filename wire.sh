#!/bin/sh
IPV4=$(curl -4 icanhazip.com)
IPV6=$(curl -6 icanhazip.com)
echo "Enter number of Wireguard clients: "
read CLIENTS
if ! [ "$CLIENTS" -gt 0 ]  && ! [ "$CLIENTS" =~ ^[0-9]+$ ] && ! [ "$CLIENTS" -lt 101 ]
then
  echo "Enter a valid integer from 1 to 100."
  read CLIENTS
fi
if ! [ "$CLIENTS" -gt 0 ]  && ! [ "$CLIENTS" =~ ^[0-9]+$ ] && ! [ "$CLIENTS" -lt 101 ]
then
  CLIENTS=1
fi
sudo apt-get update && apt-get upgrade -y
sudo apt-get install software-properties-common iptables ufw resolvconf  -y
sudo add-apt-repository ppa:wireguard/wireguard -y
sudo apt-get install wireguard -y
umask 077
wg genkey > privatekey
wg pubkey < privatekey > publickey
PRIVATEKEY=$(cat privatekey)
PUBLICKEY=$(cat publickey)
cat << WG > /etc/wireguard/wg0.conf
[Interface]
PrivateKey = $PRIVATEKEY
Address = 10.0.0.1/24, fd86:ea04:1115::1/64
ListenPort = 51820
PostUp = iptables -A FORWARD -i wg0 -j ACCEPT; iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE; ip6tables -A FORWARD -i wg0 -j ACCEPT; ip6tables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
PostDown = iptables -D FORWARD -i wg0 -j ACCEPT; iptables -t nat -D POSTROUTING -o eth0 -j MASQUERADE; ip6tables -D FORWARD -i wg0 -j ACCEPT; ip6tables -t nat -D POSTROUTING -o eth0 -j MASQUERADE
SaveConfig = true
WG
sudo chmod 600 /etc/wireguard/ -R
sed -i -e '/net.ipv4.ip_forward/c net.ipv4.ip_forward=1  ' /etc/sysctl.conf
sed -i -e '/net.ipv6.conf.all.forwarding/c net.ipv6.conf.all.forwarding=1 ' /etc/sysctl.conf
sudo sysctl -p
sudo ufw allow 22/tcp 
sed -i -e '/DEFAULT_FORWARD_POLICY/c DEFAULT_FORWARD_POLICY="ACCEPT" ' /etc/default/ufw
cat << fire >> /etc/ufw/before.rules

# NAT table rules
*nat
:POSTROUTING ACCEPT [0:0]
-A POSTROUTING -o eth0 -j MASQUERADE

# End each table with the 'COMMIT' line or these rules won't be processed
COMMIT
fire
sudo ufw enable -y
sudo systemctl restart ufw
sudo ufw allow 51820/udp
sudo ufw allow 21/tcp 
wg-quick up wg0
sudo systemctl enable wg-quick@wg0
mkdir /client-config
mkdir /client-keys

TMP=2
while [ "$TMP" -lt `expr $CLIENTS + 2` ]
do
  TMP1=`expr $TMP - 1`
  umask 077
  wg genkey > /client-keys/privatekey-$TMP1
  wg pubkey < /client-keys/privatekey-$TMP1 > /client-keys/publickey-$TMP1
cat << _CLIENT_ > /client-config/$TMP1.conf
[Interface]
PrivateKey = $(cat /client-keys/privatekey-$TMP1)
Address = 10.0.0.$TMP/32, fd86:ea04:1115::$TMP/128
DNS = 1.1.1.1

[Peer]
PublicKey = $PUBLICKEY
AllowedIPs = 0.0.0.0/0, ::/0
Endpoint = $IPV4:51820
_CLIENT_
sudo wg set wg0 peer $(cat /client-keys/publickey-$TMP1) allowed-ips 10.0.0.$TMP/32,fd86:ea04:1115::$TMP/128

  TMP=`expr $TMP + 1`
  echo $TMP
done
wg




