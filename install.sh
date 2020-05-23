#!/bin/bash

TMP_FOLDER=$(mktemp -d)
NAME_COIN="Pyrk"
GIT_REPO="https://github.com/pyrkcommunity/pyrk.git"

https://github.com/pyrkcommunity/pyrk/releases/download/v0.12.3.4/pyrk-0.12.3-linux64.tar.gz

FILE_BIN="pyrk-0.12.3-linux64.tar.gz"
BIN_DOWN="https://github.com/pyrkcommunity/pyrk/releases/download/v0.12.3.4/${FILE_BIN}"
#GIT_SENT="https://github.com/pyrkcommunity/sentinel.git"
FOLDER_BIN="./"


BINARY_FILE="pyrkd"
BINARY_CLI="/usr/local/bin/pyrk-cli"
BINARY_CLI_FILE="pyrk-cli"
BINARY_PATH="/usr/local/bin/${BINARY_FILE}"
DIR_COIN=".pyrk"
CONFIG_FILE="pyrk.conf"
DEFULT_PORT=8118

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

function prepare_system() {

	echo -e "Prepare the system to install ${NAME_COIN} master node."
	apt-get update 
	DEBIAN_FRONTEND=noninteractive apt-get -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" -y -qq upgrade 
	apt install -y software-properties-common 
	echo -e "${GREEN}Adding bitcoin PPA repository"
	apt-add-repository -y ppa:bitcoin/bitcoin 
	echo -e "Installing required packages, it may take some time to finish.${NC}"
	apt-get update
	apt-get install -y -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" make software-properties-common \
	build-essential libtool autoconf libssl-dev libboost-dev libboost-chrono-dev libboost-filesystem-dev libboost-program-options-dev \
	libboost-system-dev libboost-test-dev libboost-thread-dev sudo automake git wget pwgen curl libdb4.8-dev bsdmainutils \
	libdb4.8++-dev libminiupnpc-dev libgmp3-dev ufw fail2ban pwgen libzmq3-dev autotools-dev pkg-config libevent-dev libboost-all-dev python-virtualenv virtualenv
	clear
	if [ "$?" -gt "0" ];
	  then
	    echo -e "${RED}Not all required packages were installed properly. Try to install them manually by running the following commands:${NC}\n"
	    echo "apt-get update"
	    echo "apt -y install software-properties-common"
	    echo "apt-add-repository -y ppa:bitcoin/bitcoin"
	    echo "apt-get update"
	    echo "apt install -y make build-essential libtool software-properties-common autoconf libssl-dev libboost-dev libboost-chrono-dev libboost-filesystem-dev \
	libboost-program-options-dev libboost-system-dev libboost-test-dev libboost-thread-dev sudo automake git pwgen curl libdb4.8-dev \
	bsdmainutils libdb4.8++-dev libminiupnpc-dev libgmp3-dev ufw fail2ban pwgen libzmq3-dev autotools-dev pkg-config libevent-dev libboost-all-dev python-virtualenv virtualenv"
	 exit 1
	fi

	clear
	echo -e "Checking if swap space is needed."
	PHYMEM=$(free -g|awk '/^Mem:/{print $2}')
	if [ "$PHYMEM" -lt "2" ];
	  then
	    echo -e "${GREEN}Server is running with less than 2G of RAM, creating 2G swap file.${NC}"
	    dd if=/dev/zero of=/swapfile bs=1024 count=2M
	    chmod 600 /swapfile
	    mkswap /swapfile
	    swapon -a /swapfile
	else
	  echo -e "${GREEN}Server running with at least 2G of RAM, no swap needed.${NC}"
	fi
	clear
}

function checks() {
	if [[ $(lsb_release -d) != *16.04* ]]; then
	  echo -e "${RED}You are not running Ubuntu 16.04. Installation is cancelled.${NC}"
	  exit 1
	fi

	if [[ $EUID -ne 0 ]]; then
	   echo -e "${RED}$0 must be run as root.${NC}"
	   exit 1
	fi

	if [ -n "$(pidof ${BINARY_FILE})" ]; then
	  echo -e "${GREEN}\c"
	  read -e -p "${NAME_COIN} is already running. Do you want to add another MN? [Y/N]" ISNEW
	  echo -e "{NC}"
	  clear
	else
	  ISNEW="new"
	fi
}

function compile_server() {
  	echo -e "Clone git repo and compile it. This may take some time. Press a key to continue."
	
	wget $BIN_DOWN -P $TMP_FOLDER
	cd $TMP_FOLDER
	tar -xzvf $FILE_BIN
	cd $FOLDER_BIN
	cp * /usr/local/ -a

	#read -n 1 -s -r -p ""

	#git clone $GIT_REPO $TMP_FOLDER
	#cd $TMP_FOLDER

	#./autogen.sh
	#./configure
	#make

	#cp -a $TMP_FOLDER/src/$BINARY_FILE $BINARY_PATH
	#cp -a $TMP_FOLDER/src/$BINARY_CLI_FILE $BINARY_CLI
  clear
}

function ask_user() {
	  DEFAULT_USER="worker01"
	  read -p "${NAME_COIN} user: " -i $DEFAULT_USER -e WORKER
	  : ${WORKER:=$DEFAULT_USER}

	  if [ -z "$(getent passwd $WORKER)" ]; then
	    useradd -m $WORKER
	    USERPASS=$(pwgen -s 12 1)
	    echo "$WORKER:$USERPASS" | chpasswd

	    HOME_WORKER=$(sudo -H -u $WORKER bash -c 'echo $HOME')
	    DEFAULT_FOLDER="$HOME_WORKER/${DIR_COIN}"
	    read -p "Configuration folder: " -i $DEFAULT_FOLDER -e WORKER_FOLDER
	    : ${WORKER_FOLDER:=$DEFAULT_FOLDER}
	    mkdir -p $WORKER_FOLDER
	    chown -R $WORKER: $WORKER_FOLDER >/dev/null
	  else
	    clear
	    echo -e "${RED}User exits. Please enter another username: ${NC}"
	    ask_user
	  fi
}

function check_port() {
	  declare -a PORTS
	  PORTS=($(netstat -tnlp | awk '/LISTEN/ {print $4}' | awk -F":" '{print $NF}' | sort | uniq | tr '\r\n'  ' '))
	  ask_port

	  while [[ ${PORTS[@]} =~ $PORT_COIN ]] || [[ ${PORTS[@]} =~ $[PORT_COIN+1] ]]; do
	    clear
	    echo -e "${RED}Port in use, please choose another port:${NF}"
	    ask_port
	  done
}


function ask_port() {
	read -p "${NAME_COIN} Port: " -i $DEFULT_PORT -e PORT_COIN
	: ${PORT_COIN:=$DEFULT_PORT}
}


function create_config() {
	RPCUSER=$(pwgen -s 8 1)
	RPCPASSWORD=$(pwgen -s 15 1)
cat << EOF > $WORKER_FOLDER/$CONFIG_FILE
rpcuser=$RPCUSER
rpcpassword=$RPCPASSWORD
rpcallowip=127.0.0.1
rpcport=$[PORT_COIN+1]
listen=1
server=1
daemon=1
port=$PORT_COIN
EOF
}

function create_key() {
	  echo -e "Enter your ${RED}Masternode Private Key${NC}. Leave it blank to generate a new ${RED}Masternode Private Key${NC} for you:"
	  read -e KEY_COIN
	  if [[ -z "$KEY_COIN" ]]; then
	  sudo -u $WORKER $BINARY_PATH -conf=$WORKER_FOLDER/$CONFIG_FILE -datadir=$WORKER_FOLDER
	  sleep 15
	  if [ -z "$(pidof ${BINARY_FILE})" ]; then
	   echo -e "${RED}${NAME_COIN} server couldn't start. Check /var/log/syslog for errors.{$NC}"
	   exit 1
	  fi
	  KEY_COIN=$(sudo -u $WORKER $BINARY_CLI -conf=$WORKER_FOLDER/$CONFIG_FILE -datadir=$WORKER_FOLDER masternode genkey)
	  sudo -u $WORKER $BINARY_CLI -conf=$WORKER_FOLDER/$CONFIG_FILE -datadir=$WORKER_FOLDER stop
	  fi
}

function update_config() {
  sed -i 's/daemon=1/daemon=0/' $WORKER_FOLDER/$CONFIG_FILE
  NODEIP=$(curl -s4 icanhazip.com)
  cat << EOF >> $WORKER_FOLDER/$CONFIG_FILE
logtimestamps=1
maxconnections=256
masternode=1
externalip=$NODEIP:$PORT_COIN
masternodeprivkey=$KEY_COIN
addnode=223.98.67.11:8118
addnode=223.98.67.101:8118
addnode=223.98.67.151:8118
addnode=106.54.11.83:8118
addnode=223.98.67.141:8118
addnode=223.98.67.12:8118
addnode=223.98.67.102:8118
addnode=223.186.188.18:8118
addnode=223.98.67.13:8118
addnode=223.186.188.21:8118
addnode=223.98.67.1:8118
addnode=51.89.96.163:8118
addnode=106.54.107.95:8118
addnode=223.186.188.25:8118
addnode=223.98.67.14:8118
addnode=223.98.67.15:8118
addnode=223.98.67.103:8118
addnode=95.216.148.4:8118
addnode=116.203.23.193:8118
addnode=223.98.67.2:8118
addnode=223.98.67.104:8118
addnode=46.166.162.123:8118
addnode=46.166.162.81:8118
addnode=194.182.86.91:8118
addnode=223.186.188.3:8118
addnode=223.98.67.16:8118
addnode=223.98.67.17:8118
addnode=95.217.67.191:8118
addnode=223.98.67.105:8118
addnode=5.199.171.65:8118
addnode=106.54.13.180:8118
addnode=223.98.67.139:8118
addnode=5.199.171.64:8118
addnode=223.98.67.143:8118
addnode=80.89.229.169:8118
addnode=185.205.210.130:8118
addnode=212.86.101.50:8118
addnode=223.98.67.3:8118
addnode=119.3.139.48:8118
addnode=223.98.67.4:8118
addnode=185.216.117.45:8118
addnode=106.52.144.80:8118
addnode=223.98.67.18:8118
addnode=121.89.166.18:8118
addnode=223.98.68.1:8118
addnode=223.98.68.2:8118
addnode=95.217.97.193:8118
addnode=95.217.52.127:8118
addnode=223.98.67.149:8118
addnode=223.98.67.33:8118
addnode=223.98.67.136:8118
addnode=27.155.78.58:8118
addnode=106.54.13.101:8118
addnode=91.228.56.100:8118
addnode=95.217.218.16:8118
addnode=121.37.252.177:8118
addnode=223.98.67.106:8118
addnode=116.63.132.211:8118
addnode=173.249.49.54:8118
addnode=95.217.97.215:8118
addnode=223.98.67.107:8118
addnode=94.177.234.195:8118
addnode=173.249.23.185:8118
addnode=223.98.67.108:8118
addnode=223.98.67.109:8118
addnode=95.216.127.184:8118
addnode=106.54.108.144:8118
addnode=95.217.218.182:8118
addnode=95.216.127.167:8118
addnode=223.98.67.110:8118
addnode=88.198.135.169:8118
addnode=95.217.67.252:8118
addnode=223.98.67.5:8118
addnode=223.186.188.15:8118
addnode=95.217.98.225:8118
addnode=80.89.229.161:8118
addnode=223.98.67.111:8118
addnode=223.98.67.112:8118
addnode=223.98.67.150:8118
addnode=223.98.67.113:8118
addnode=188.214.130.8:8118
addnode=111.229.80.30:8118
addnode=47.57.20.78:8118
addnode=185.231.245.186:8118
addnode=223.98.67.26:8118
addnode=113.221.44.17:8118
addnode=91.228.56.74:8118
addnode=223.98.67.114:8118
addnode=45.91.203.27:8118
addnode=45.91.203.65:8118
addnode=223.98.68.3:8118
addnode=223.98.68.4:8118
addnode=223.98.68.5:8118
addnode=223.98.68.6:8118
addnode=223.98.68.7:8118
addnode=223.98.68.8:8118
addnode=223.98.68.9:8118
addnode=223.98.68.10:8118
addnode=223.98.68.11:8118
addnode=223.98.68.12:8118
addnode=223.98.68.13:8118
addnode=223.98.68.14:8118
addnode=223.98.68.15:8118
addnode=223.98.68.16:8118
addnode=223.98.68.17:8118
addnode=223.98.68.18:8118
addnode=223.98.68.19:8118
addnode=223.98.68.20:8118
addnode=223.98.68.21:8118
addnode=223.98.68.22:8118
addnode=223.98.68.23:8118
addnode=223.98.68.24:8118
addnode=223.98.68.25:8118
addnode=223.98.68.26:8118
addnode=223.98.68.27:8118
addnode=223.98.68.28:8118
addnode=223.98.68.29:8118
addnode=223.98.68.30:8118
addnode=223.98.68.31:8118
addnode=223.98.68.32:8118
addnode=223.98.68.33:8118
addnode=223.98.68.34:8118
addnode=223.98.68.35:8118
addnode=223.98.68.36:8118
addnode=223.98.68.37:8118
addnode=223.98.68.38:8118
addnode=223.98.67.6:8118
addnode=223.186.188.13:8118
addnode=223.186.188.14:8118
addnode=212.86.101.214:8118
addnode=106.54.109.94:8118
addnode=223.98.67.27:8118
addnode=223.98.67.19:8118
addnode=95.217.67.244:8118
addnode=95.217.52.126:8118
addnode=93.115.26.126:8118
addnode=223.186.188.22:8118
addnode=46.166.162.45:8118
addnode=223.98.67.121:8118
addnode=223.98.67.115:8118
addnode=223.98.67.142:8118
addnode=45.137.65.10:8118
addnode=95.251.45.156:8118
addnode=223.98.67.116:8118
addnode=161.117.56.93:8118
addnode=223.98.67.7:8118
addnode=95.217.98.226:8118
addnode=223.98.67.20:8118
addnode=95.217.180.3:8118
addnode=223.186.188.9:8118
addnode=5.189.154.210:8118
addnode=223.98.67.21:8118
addnode=93.115.29.52:8118
addnode=223.98.67.117:8118
addnode=192.144.214.84:8118
addnode=95.217.97.199:8118
addnode=185.92.150.197:8118
addnode=223.98.67.147:8118
addnode=95.216.127.161:8118
addnode=114.67.91.157:8118
addnode=223.98.67.22:8118
addnode=116.203.40.82:8118
addnode=95.217.67.189:8118
addnode=91.228.56.145:8118
addnode=45.81.226.151:8118
addnode=212.237.8.122:8118
addnode=106.54.12.161:8118
addnode=223.98.67.118:8118
addnode=121.36.133.243:8118
addnode=45.147.198.110:8118
addnode=223.98.68.47:8118
addnode=108.61.165.251:8118
addnode=223.98.67.144:8118
addnode=89.36.210.71:8118
addnode=95.216.234.128:8118
addnode=223.186.188.2:8118
addnode=223.98.67.119:8118
addnode=223.98.67.8:8118
addnode=223.98.67.134:8118
addnode=47.113.188.132:8118
addnode=223.98.67.23:8118
addnode=223.98.67.122:8118
addnode=188.214.130.8:8118
addnode=116.85.32.22:8118
addnode=106.54.107.28:8118
addnode=223.186.188.4:8118
addnode=95.217.97.214:8118
addnode=223.98.67.145:8118
addnode=185.92.150.196:8118
addnode=223.186.188.10:8118
addnode=223.98.67.135:8118
addnode=134.175.136.224:8118
addnode=223.186.188.16:8118
addnode=95.217.70.46:8118
addnode=223.98.67.123:8118
addnode=49.235.129.33:8118
addnode=223.98.67.124:8118
addnode=223.98.67.28:8118
addnode=223.186.188.19:8118
addnode=106.54.11.239:8118
addnode=223.186.188.24:8118
addnode=223.98.67.125:8118
addnode=39.99.167.115:8118
addnode=223.98.68.39:8118
addnode=49.235.131.130:8118
addnode=223.186.188.7:8118
addnode=95.217.67.231:8118
addnode=223.98.67.126:8118
addnode=223.98.67.29:8118
addnode=95.217.97.210:8118
addnode=95.217.95.232:8118
addnode=223.186.188.12:8118
addnode=223.98.67.140:8118
addnode=154.223.134.122:8118
addnode=121.37.4.3:8118
addnode=46.4.205.25:8118
addnode=116.63.132.211:8118
addnode=223.186.188.17:8118
addnode=106.54.12.25:8118
addnode=223.98.67.127:8118
addnode=223.98.67.138:8118
addnode=223.98.67.128:8118
addnode=223.98.67.133:8118
addnode=106.54.107.86:8118
addnode=167.179.112.239:8118
addnode=223.98.67.30:8118
addnode=129.211.60.79:8118
addnode=49.235.131.239:8118
addnode=223.98.67.146:8118
addnode=223.98.67.129:8118
addnode=49.235.189.69:8118
addnode=106.54.13.196:8118
addnode=223.98.67.24:8118
addnode=223.186.188.20:8118
addnode=46.166.162.126:8118
addnode=223.98.67.9:8118
addnode=223.98.67.137:8118
addnode=45.87.0.166:8118
addnode=139.9.193.247:8118
addnode=223.98.67.130:8118
addnode=223.98.67.25:8118
addnode=95.217.67.228:8118
addnode=223.98.68.40:8118
addnode=93.115.26.27:8118
addnode=223.98.67.10:8118
addnode=223.98.68.41:8118
addnode=223.98.68.42:8118
addnode=223.98.68.43:8118
addnode=223.98.68.44:8118
addnode=223.98.68.45:8118
addnode=223.98.68.46:8118
addnode=223.98.67.131:8118
addnode=80.211.19.186:8118
addnode=223.186.188.5:8118
addnode=223.98.67.31:8118
addnode=89.223.123.145:8118
addnode=58.47.32.23:8118
addnode=223.98.67.148:8118
addnode=106.54.33.191:8118
addnode=223.98.67.132:8118
addnode=139.9.149.124:8118
addnode=47.105.104.21:8118
addnode=148.70.32.5:8118
addnode=223.98.67.32:8118
addnode=188.214.129.65:8118
addnode=46.166.162.76:8118
addnode=223.98.67.120:8118
addnode=95.216.186.231:8118
addnode=113.221.44.179:8118
addnode=223.98.67.34:8118
EOF
  chown -R $WORKER: $WORKER_FOLDER >/dev/null
}

function enable_firewall() {
  echo -e "Installing ${GREEN}fail2ban${NC} and setting up firewall to allow ingress on port ${GREEN}$PORT_COIN${NC}"
  ufw allow $PORT_COIN/tcp comment "${NAME_COIN} MN port" >/dev/null
  ufw allow $[PORT_COIN-1]/tcp comment "${NAME_COIN} MN port" >/dev/null
  ufw allow $[PORT_COIN+1]/tcp comment "${NAME_COIN} RPC port" >/dev/null
  ufw allow ssh >/dev/null 2>&1
  ufw limit ssh/tcp >/dev/null 2>&1
  ufw default allow outgoing >/dev/null 2>&1
  echo "y" | ufw enable >/dev/null 2>&1
  systemctl enable fail2ban >/dev/null 2>&1
  systemctl start fail2ban >/dev/null 2>&1
}

function systemd_up() {
  cat << EOF > /etc/systemd/system/$WORKER.service
[Unit]
Description=${NAME_COIN} service
After=network.target
[Service]
Type=forking
User=$WORKER
Group=$WORKER
WorkingDirectory=$WORKER_FOLDER
ExecStart=$BINARY_PATH -daemon
ExecStop=$BINARY_PATH stop
Restart=always
PrivateTmp=true
TimeoutStopSec=60s
TimeoutStartSec=10s
StartLimitInterval=120s
StartLimitBurst=5
  
[Install]
WantedBy=multi-user.target
EOF

  systemctl daemon-reload
  sleep 3
  systemctl start $WORKER.service
  systemctl enable $WORKER.service >/dev/null 2>&1

  if [[ -z "$(pidof ${BINARY_FILE})" ]]; then
    echo -e "${RED}${NAME_COIN} is not running${NC}, please investigate. You should start by running the following commands as root:"
    echo "systemctl start $WORKER.service"
    echo "systemctl status $WORKER.service"
    echo "less /var/log/syslog"
    exit 1
  fi
}

function install_sentinel() {
	wget https://raw.githubusercontent.com/pyrkcommunity/sentinel/master/sentinel-one-line-installer.sh && chmod +x sentinel-one-line-installer.sh && ./sentinel-one-line-installer.sh
}


function resumen() {
 echo
 echo -e "================================================================================================================================"
 echo -e "${NAME_COIN} Masternode is up and running as user ${GREEN}$WORKER${NC} and it is listening on port ${GREEN}$PORT_COIN${NC}."
 echo -e "${GREEN}$WORKER${NC} password is ${RED}$USERPASS${NC}"
 echo -e "Configuration file is: ${RED}$WORKER_FOLDER/$CONFIG_FILE${NC}"
 echo -e "Start: ${RED}systemctl start $WORKER.service${NC}"
 echo -e "Stop: ${RED}systemctl stop $WORKER.service${NC}"
 echo -e "VPS_IP:PORT ${RED}$NODEIP:$PORT_COIN${NC}"
 echo -e "MASTERNODE PRIVATEKEY is: ${RED}$KEY_COIN${NC}"
 echo -e "================================================================================================================================"
}

function setup_node() {
	ask_user
	check_port
	create_config
	create_key
	update_config
	enable_firewall
	install_sentinel
	systemd_up
	resumen
}

######################################################
#                      Main Script                   #
######################################################

clear

checks
if [[ ("$ISNEW" == "y" || "$ISNEW" == "Y") ]]; then
  setup_node
  exit 0
elif [[ "$ISNEW" == "new" ]]; then
  prepare_system
  compile_server
  setup_node
else
  echo -e "${GREEN}${NAME_COIN} already running.${NC}"
  exit 0
fi
