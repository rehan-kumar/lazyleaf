# lazyleaf
made a script that automatically configures wireguard and generates server and client config files
Running the script

chmod +x wire.sh
./wire.sh

It will then ask you how many client config files are required, type and press enter, client config files will be saved in 
/client-config folder named 1.conf, 2.conf and so on

Just download config file and connect using any wireguard client

Tested only on Ubuntu 20.04 LTS(hetzner and DigitalOcean)

Mainly made it for personal use but maybe someone can find it helpful

Caution and disclaimer- only install this on a new server/VM with latest kernel as i am not responsible for anything going wrong
