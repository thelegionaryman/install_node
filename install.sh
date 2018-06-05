#!/bin/bash
#  
#     _     _    _ _   _ ______  _____ 
#    | |   | |  | | \ | |  ____|/ ____|
#    | |   | |  | |  \| | |__  | (___  
#    | |   | |  | | . ` |  __|  \___ \ 
#    | |___| |__| | |\  | |____ ____) |
#    |______\____/|_| \_|______|_____/ 
#
#
# install_node.sh
# Descrição: Script de instalação do Lunes Node
#
# Usage: 
#  $./install_node.sh <mainnet|testnet> <enter>
#
# Created by Daniel Checchia on 03/06/2018 - Unofficial translated by @thodyssey on 05/06/2018
# Copyright (c) 2015 Lunes Platform.
#

# [ $1 == --help ] && { sed -n -e '/^# ./,/^$/ s/^# \?//p' < $0; exit; }
clear

# Valida diretórios de instalação
[ ! -d /opt/lunesnode ] && mkdir /opt/lunesnode
[ ! -d /etc/lunesnode ] && mkdir /etc/lunesnode

export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:$PATH"
APT=$(which apt)
CAT=$(which cat)
AWK=$(which awk)
CURL=$(which curl)               
WGET=$(which wget)
lunesnode_url="https://lunes.io/install/"
lunesnode_git="https://raw.githubusercontent.com/Lunes-platform/install_node/master/"

# ----> Inicio das Funcoes
ID=$(/usr/bin/which id)

# Get a sane screen width
[ -z "${COLUMNS:-}" ] && COLUMNS=80
# [ -z "${CONSOLETYPE:-}" ] && CONSOLETYPE="$(/sbin/consoletype)"

    BOOTUP=color
    RES_COL=60
    MOVE_TO_COL="echo -en \\033[${RES_COL}G"
    SETCOLOR_SUCCESS="echo -en \\033[1;32m"
    SETCOLOR_FAILURE="echo -en \\033[1;31m"
    SETCOLOR_WARNING="echo -en \\033[1;33m"
    SETCOLOR_NORMAL="echo -en \\033[0;39m"
    LOGLEVEL=1

echo_success() {
  [ "$BOOTUP" = "color" ] && $MOVE_TO_COL
  echo -n "["
  [ "$BOOTUP" = "color" ] && $SETCOLOR_SUCCESS
  echo -n $"  OK  "
  [ "$BOOTUP" = "color" ] && $SETCOLOR_NORMAL
  echo -n "]"
  echo -ne "\r"
  return 0
}

echo_failure() {
  [ "$BOOTUP" = "color" ] && $MOVE_TO_COL
  echo -n "["
  [ "$BOOTUP" = "color" ] && $SETCOLOR_FAILURE
  echo -n $"FAILED"
  [ "$BOOTUP" = "color" ] && $SETCOLOR_NORMAL
  echo -n "]"
  echo -ne "\r"
  return 1
}

echo_passed() {
  [ "$BOOTUP" = "color" ] && $MOVE_TO_COL
  echo -n "["
  [ "$BOOTUP" = "color" ] && $SETCOLOR_WARNING
  echo -n $"PASSED"
  [ "$BOOTUP" = "color" ] && $SETCOLOR_NORMAL
  echo -n "]"
  echo -ne "\r"
  return 1
}

echo_warning() {
  [ "$BOOTUP" = "color" ] && $MOVE_TO_COL
  echo -n "["
  [ "$BOOTUP" = "color" ] && $SETCOLOR_WARNING
  echo -n $"WARNING"
  [ "$BOOTUP" = "color" ] && $SETCOLOR_NORMAL
  echo -n "]"
  echo -ne "\r"
  return 1
}

is_root(){
   if ((${EUID:-0} || "$(/usr/bin/id -u)")); then
   echo "Este script deve ser executado como root!"
   exit 100
   fi
}

step() {
    /bin/echo -n "$@"

    STEP_OK=0
    [[ -w /tmp ]] && /bin/echo $STEP_OK > /tmp/step.$$
}

try() {
    # Check for `-b' argument to run command in the background.
    export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:$PATH"
    local BG=

    [[ $1 == -b ]] && { BG=1; shift; }
    [[ $1 == -- ]] && {       shift; }

    # Run the command.
    if [[ -z $BG ]]; then
        "$@"
    else
        "$@" &
    fi

    # Check if command failed and update $STEP_OK if so.
    local EXIT_CODE=$?

    if [[ $EXIT_CODE -ne 0 ]]; then
        STEP_OK=$EXIT_CODE
        [[ -w /tmp ]] && /bin/echo $STEP_OK > /tmp/step.$$

        if [[ -n $LOG_STEPS ]]; then
            local FILE=$(readlink -m "${BASH_SOURCE[1]}")
            local LINE=${BASH_LINENO[0]}

            echo "$FILE: line $LINE: Command \`$*' failed with exit code $EXIT_CODE." >> "$LOG_STEPS"
        fi
    fi

    return $EXIT_CODE
}

next() {
    [[ -f /tmp/step.$$ ]] && { STEP_OK=$(< /tmp/step.$$); /bin/rm -f /tmp/step.$$; }
    [[ $STEP_OK -eq 0 ]]  && echo_success || echo_failure
    echo

    return $STEP_OK
}

md5_check () {
    EXIT_MD5=0
    if [ ! -f /opt/lunesnode/lunesnode-latest.md5 ]; then
        echo "181818181" > /opt/lunesnode/lunesnode-latest.md5
    fi
    LOCAL_MD5=$($CAT /opt/lunesnode/lunesnode-latest.md5 | $AWK '{ print $1 }' )
    REMOTE_MD5=$($CURL -s https://lunes.io/install/lunesnode-latest.md5 | $AWK '{ print $1 }' )
    if [[ "$LOCAL_MD5" != "$REMOTE_MD5" ]]; then 
       return 
    else 
       echo "Versão do Node está atualizada!"
       exit 100
    fi
}

wallet_pass () {
    mkdir -p /tmp/wallet
    cd /tmp/wallet    
    /usr/bin/java -jar /opt/lunesnode/walletgenerator.jar -p $WALLET_PASS > SENHAS.TXT
    echo $WALLET_PASS >> SENHAS.TXT
}

create_init () {
cat > /etc/systemd/system/lunesnode.service <<-  "EOF"
[Unit]
Description=Lunes Node Blockchain
After=network.target
[Service]
WorkingDirectory=/opt/lunesnode/
ExecStart=/usr/bin/java -jar /opt/lunesnode/lunesnode-latest.jar /etc/lunesnode/lunes.conf
LimitNOFILE=4096
Type=simple
User=lunesuser
Group=lunesuser
Restart=always
RestartSec=5000ms
StandardOutput=syslog
StandardError=journal
SyslogIdentifier=lunesnode
RestartPreventExitStatus=38
SuccessExitStatus=143
PermissionsStartOnly=true
TimeoutStopSec=300
[Install]
WantedBy=multi-user.target

EOF
}

get_data () {
while read line
 do
   CHAVE=$(echo -e "$line" | awk '{ print $1 }' )
   VALOR=$(echo -e "$line" | awk '{ print $3 }' )
   if [[ "$CHAVE" = "$1" ]]; then
      CHAVE_FINAL=$CHAVE
      VALOR_FINAL=$VALOR
   fi
done < /tmp/wallet/SENHAS.TXT
}

install_or_update () {
    # Valida diretórios de instalação
    UPDATE=1
    [ ! -d /opt/lunesnode ] && UPDATE=0
    [ ! -d /etc/lunesnode ] && UPDATE=0
    [ ! -f /etc/lunesnode/lunes.conf ] && UPDATE=0
}

my_ip () {
    IPV4=$(curl --silent https://checkip.amazonaws.com)
    FQDN=$(dig -x $IPV4 +short)
    NODE_NAME=$(echo "${FQDN%?}")
}

# ----> Termino das Funcoes
clear
echo -e "\e[35m"
echo "            _     _    _ _   _ ______  _____ ";
echo "           | |   | |  | | \ | |  ____|/ ____|";
echo "           | |   | |  | |  \| | |__  | (___  ";
echo "           | |   | |  | | . \`|  __|  \___ \ ";
echo "           | |___| |__| | |\  | |____ ____) |";
echo "           |______\____/|_| \_|______|_____/ ";
echo "                                             ";
echo "                                             ";
echo -e "\e[97m"
echo " "
echo " - Lunes Node Installation / Update Script - Ubuntu 16.04"
echo " "
echo " This script will perform the following settings on your node:"
echo " "
echo " 	* Update packages"
echo " 	* Create new account lunesuser"
echo " 	* Download LunesNode.jar and github release utilities"
echo " 	* Create /opt/lunesnode and install lunesnode"
echo " 	* Create /etc/lunesnode and put lunes.conf"
echo " 	* Create the startup script /etc/systemd/system/lunesnode.service"
echo " 	* Create your Wallet and SEEDs"
echo " 	* Instruct basic Node commands"
echo " "
echo "*** This script should be run as root or sudo bash! ***"
echo " "

read -p "Are you sure you want to continue Setup? <Y/n> " -n 1 -r


if [[ ! $REPLY =~ ^[YySs]$ ]]
   then
      exit 1
fi

# INCLUIR VALIDAÇÃO DE UPDATE !!!!
echo ""

# Valida root
step "Validating Root..."
try is_root
next

# Validando necessidade de atualizacao LunesNode
step "Comparing MD5...."
try md5_check
next


# Atualizando pacotes
step "Updating OS packages..."
try $APT -qq --yes update &> /dev/null
try $APT -qq --yes upgrade &> /dev/null
try $APT -qq --yes autoremove &> /dev/null
next

# Instalando dependencia
step "Installing OpenJDK8...."
try $APT -qq --yes install openjdk-8-jre &> /dev/null
next 

# Criação do usuário lunesuser
# Captura da Senha da Wallet"
echo ""
echo ""
echo -n "Enter the password for the lunesuser: ";
unset LUNESUSER;
while IFS= read -r -s -n1 pass; do
  if [[ -z $pass ]]; then
     echo
     break
  else
     echo -n '*'
     LUNESUSER+=$pass
  fi
done


step "Creating user lunesuser....."
try /usr/sbin/adduser lunesuser --gecos "Lunes User,,," --disabled-password &> /dev/null
try echo "lunesuser:$LUNESUSER" | /usr/bin/sudo chpasswd
next

# Download dos pacotes do LunesNode
cd /opt/lunesnode
step "Downloading LunesNode....."
try $WGET --no-cache "${lunesnode_url}/lunesnode-latest.jar"  &> /dev/null
next

step "Downloading Wallet Generator...."
cd /opt/lunesnode
try $WGET --no-cache "${lunesnode_url}/walletgenerator.jar"  &> /dev/null
next

# Criando o serviço
step "Creating the LunesNode service....."
try create_init
next

# Captura da Senha da Wallet"
echo ""
echo ""
echo -n "Enter the password for your Wallet: ";
unset WALLET_PASS;
while IFS= read -r -s -n1 pass; do
  if [[ -z $pass ]]; then
     echo
     break
  else
     echo -n '*'
     WALLET_PASS+=$pass
  fi
done
WALLET_PASS_FINAL=$WALLET_PASS
step "Creating the Wallet for the Node...."
try wallet_pass
next

step "Setting /etc/lunesnode/lunes.conf...."
mkdir /tmp/node
cd /tmp/node
try $WGET --no-cache "${lunesnode_git}/lunes.conf"  &> /dev/null
next

# Verifica IP e node do Node
my_ip
echo ""
echo ""
echo "Data Found: "
echo "    NODE: " $NODE_NAME
echo "    IPv4: " $IPV4
echo ""
read -p "These are the data of your node? <Y/n> " -n 1 -r
if [[ ! $REPLY =~ ^[YySs]$ ]]
then
    echo "Please correct your DNS data and try again:-) "
    exit 1
fi
NODE_NAME_FINAL=$NODE_NAME
IPV4_FINAL=$IPV4
echo ""
echo ""
step "Including NODE_NAME on lunes.conf ...."
try sed -i s/NODE_NAME/$NODE_NAME_FINAL/g /tmp/node/lunes.conf
next

step "Including IP lunes.conf...."
try sed -i "s/IPV4/$IPV4_FINAL/g" /tmp/node/lunes.conf
next

step "Including Wallet password in lunes.conf....."
try sed -i "s/WALLET_PASS/$WALLET_PASS_FINAL/g" /tmp/node/lunes.conf
next

step "Including your SEED in lunes.conf ....."
get_data seed_hash
try sed -i "s/WALLET_SEED/$VALOR_FINAL/g" /tmp/node/lunes.conf
next
mv /tmp/node/lunes.conf /etc/lunesnode/lunes.conf

echo -e "\e[92m"
echo "  INSTALLATION COMPLETED  ";
echo "                                                       ";
echo -e "\e[97m"

echo "Next steps: "
echo " - in /tmp/wallet there is a file called SENHAS.TXT"
echo "   Keep it with your life!!!!!"
echo ""
echo "Basic Commands:"
echo " - To start the node: systemctl start lunesnode"
echo " - To stop the node: systemctl stop lunesnode"
echo " - To know the status of the node: systemctl status lunesnode"
echo ""
echo "and welcome to the Lunes Platform network!"
echo

