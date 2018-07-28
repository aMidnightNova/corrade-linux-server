#!/usr/bin/env bash

PATH_TO_FILE="$1"
PATH_TO_CONFIG_XML="$2"

BASE_DIR="/opt/corrade"

function doContinue() {
ANS=""

while [[ ! ${ANS} =~ ^([yY][eE][sS]|[yY])$ ]]
    do
        if [[ ${ANS} =~ ^([nN][oO]|[nN])$ ]]
            then
                return 1
            else
                read -p "Continue y/n? " ANS
        fi

        if [[ ${ANS} =~ ^([yY][eE][sS]|[yY])$ ]]
            then
                return 0
        fi
    done
}


function setPerms()  {
  if [ -d "$BASE_DIR/live" ]; then
    chown -R corrade:corrade ${BASE_DIR}/live
  fi
}


installCorrade(){
    id -u corrade &>/dev/null || useradd corrade
    id -g corrade &>/dev/null || groupadd corrade


    mkdir -p ${BASE_DIR}/live
    mkdir -p ${BASE_DIR}/backups
    mkdir -p ${BASE_DIR}/temp

#extract to temp
    if [[ -f ${PATH_TO_FILE} ]]
        then
            unzip ${PATH_TO_FILE} -d ${BASE_DIR}/temp
    elif [[ -d ${PATH_TO_FILE} ]]
        then
            unzip <(curl -Ls ${PATH_TO_FILE}) -d ${BASE_DIR}/temp
    else
        echo "Corrade source is not valid."
    fi

#Begin Install
    cp -R ${BASE_DIR}/temp/* ${BASE_DIR}/live
    rm -rf ${BASE_DIR}/temp/*


    if [ PATH_TO_CONFIG_XML != "" ];
        then
            yes | cp -f ${PATH_TO_CONFIG_XML} ${BASE_DIR}/live
    fi

}

function installCorradeLinuxServer() {
    mkdir -p ${BASE_DIR}/corrade-linux-server

    git clone -b $1 --single-branch https://github.com/MidnightRift/corrade-linux-server.git ${BASE_DIR}/corrade-linux-server

    cp ${BASE_DIR}/corrade-linux-server/setup/corrade.service /etc/systemd/system/corrade.service
    cp ${BASE_DIR}/corrade-linux-server/setup/corrade /usr/local/bin/corrade

    chmod 755 /usr/local/bin/corrade


}

function setupFirewalld() {

    systemctl enable firewalld.service
    systemctl start firewalld.service

    firewall-cmd --permanent --zone=public --add-service=https
    firewall-cmd --permanent --zone=public --add-port=8095/tcp

    systemctl restart firewalld.service

}




function setupNginx() {
    yes | cp -f ${BASE_DIR}/corrade-linux-server/setup/nginx.conf /etc/nginx/nginx.conf
    cp ${BASE_DIR}/corrade-linux-server/setup/corrade_http_proxy.conf /etc/nginx/conf.d/corrade_http_proxy.conf
    cp ${BASE_DIR}/corrade-linux-server/setup/corrade_tcp_proxy.conf /etc/nginx/conf.d/corrade_tcp_proxy.conf

    systemctl enable nginx.service
    systemctl start nginx.service
}




###

yum update -y
yum install -y epel-release

yum groupinstall -y --enablerepo=epel mono-complete git openssl-devel nginx firewalld unzip



#begin Setup
setupFirewalld

installCorradeLinuxServer

setupNginx

installCorrade

setPerms