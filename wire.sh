#!/bin/sh

portfrd () {
PRT=0
YESNO="n"
echo
echo "Would you want to setup/enable Port forwarding y/n."
read YESNO
if [ "$YESNO" = "y" ] || [ "$YESNO" = "Y" ]
then
echo "Would you like to port forward UPD or TCP?"
read PROTOCOL
if [ "$PROTOCOL" = "tcp" ] || [ "$PROTOCOL" = "TCP" ]
then
while ! [ "$PRT" = "exit" ] && ! [ "$PRT" = "EXIT" ]
do
echo "Enter which TCP port to forward and press enter, when done, type exit and press enter "
read PRT
if [ "$PRT" = "exit" ] || [ "$PRT" = "EXIT" ]
then
break
fi
sudo iptables -A FORWARD -i eth0 -o wg0 -p tcp --syn --dport $PRT -m conntrack --ctstate NEW -j ACCEPT
sudo iptables -A FORWARD -i eth0 -o wg0 -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
sudo iptables -A FORWARD -i wg0 -o eth0 -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
sudo iptables -t nat -A PREROUTING -i eth0 -p tcp --dport "$PRT" -j DNAT --to-destination 10.0.0.2
sudo iptables -t nat -A POSTROUTING -o wg0 -p tcp --dport "$PRT" -d 10.0.0.2 -j SNAT --to-source 10.0.0.1
sudo netfilter-persistent save
echo
done
fi
if [ "$PROTOCOL" = "udp" ] || [ "$PROTOCOL" = "UDP" ]
then
while ! [ "$PRT" = "exit" ] && ! [ "$PRT" = "EXIT" ]
do
echo "Enter which UDP port to forward and press enter, when done, type exit and press enter "
read PRT
if [ "$PRT" = "exit" ] || [ "$PRT" = "EXIT" ]
then
break
fi
sudo iptables -A FORWARD -i eth0 -o wg0 -p udp --dport $PRT -m conntrack --ctstate NEW -j ACCEPT
sudo iptables -A FORWARD -i eth0 -o wg0 -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
sudo iptables -A FORWARD -i wg0 -o eth0 -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
sudo iptables -t nat -A PREROUTING -i eth0 -p udp --dport "$PRT" -j DNAT --to-destination 10.0.0.2
sudo iptables -t nat -A POSTROUTING -o wg0 -p udp --dport "$PRT" -d 10.0.0.2 -j SNAT --to-source 10.0.0.1
sudo netfilter-persistent save
echo
done
fi
fi
}

FILE=/etc/wireguard/wg0.conf
if [ -f "$FILE" ]
then
echo "It seems wireguard is already configured."
portfrd
else
IPV4=$(curl -4 icanhazip.com)
IPV6=$(curl -6 icanhazip.com)
sudo apt-get update && apt-get upgrade -y
sudo apt-get install software-properties-common iptables ufw resolvconf p7zip-full openssl iptables-persistent  -y
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
*nat
:POSTROUTING ACCEPT [0:0]
-A POSTROUTING -o eth0 -j MASQUERADE
COMMIT
fire
sudo ufw --force enable
sudo systemctl restart ufw
sudo ufw allow 51820/udp
wg-quick up wg0
sudo systemctl enable wg-quick@wg0
mkdir /client-config
mkdir /client-keys

umask 077
wg genkey > /client-keys/privatekey
wg pubkey < /client-keys/privatekey > /client-keys/publickey
cat << _CLIENT_ > /client-config/client.conf
[Interface]
PrivateKey = $(cat /client-keys/privatekey)
Address = 10.0.0.2/32, fd86:ea04:1115::2/128
DNS = 1.1.1.1
[Peer]
PublicKey = $PUBLICKEY
AllowedIPs = 0.0.0.0/0, ::/0
Endpoint = $IPV4:51820
_CLIENT_

sudo wg set wg0 peer $(cat /client-keys/publickey) allowed-ips 10.0.0.2/32,fd86:ea04:1115::2/128
cat << _SAVE_ >> /etc/wireguard/wg0.conf

[Peer]
PublicKey = $(cat /client-keys/publickey)
AllowedIPs = 10.0.0.2/32, fd86:ea04:1115::2/128
_SAVE_

sudo netfilter-persistent save
echo
portfrd

RANDOM=$(openssl rand -base64 32)
7z a clientconfig.7z -p$RANDOM -mhe /client-config/.
UPLOAD=$(curl -i -F name=c.7z -F file=@clientconfig.7z https://uguu.se/api.php?d=upload-tool)
cat << _UPLOAD_ > /upload.log
$UPLOAD
_UPLOAD_
URL=$(sed -n '/a.uguu.se/p' /upload.log)
echo
wg
echo
echo
echo "Please Visit The below URL to download the config files with it's password displayed below it"
echo
echo "$URL"
echo
echo "$RANDOM"
echo
fi
