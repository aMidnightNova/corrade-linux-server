#!/usr/bin/env bash

if [ "$1" != "" ];
    then
        FILE_PATH_OR_URL_TO_CORRADE_ZIP="$1"
    else
        echo "Please include the required argument FILE_PATH_OR_URL_TO_CORRADE_ZIP"
        exit
fi

PATH_TO_CONFIG_XML="$2"

if [ "$3" != "" ];
    then
        CERT_BOT_EMAIL="$3"
    else
        CERT_BOT_EMAIL=root@$HOSTNAME
fi

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
    mkdir -p ${BASE_DIR}/logs
    mkdir -p ${BASE_DIR}/backups
    mkdir -p ${BASE_DIR}/temp
    mkdir -p ${BASE_DIR}/cert

    #RANDOM_PASSWORD=$(head /dev/urandom | tr -dc A-Za-z0-9 | head -c 16 ; echo '')
    PRIVATE_KEY=$(openssl genrsa 2048)
    CERTIFICATE_SIGNING_REQUEST=$(openssl req -new -key <(cat <<< "$PRIVATE_KEY") -subj "/CN=$HOSTNAME")
    CERTIFICATE=$(openssl x509 -signkey <(cat <<< "$PRIVATE_KEY") -in <(cat <<< "$CERTIFICATE_SIGNING_REQUEST") -req -days 3650)
    openssl pkcs12 -export -passout pass: -in <(cat <<< "$CERTIFICATE") -inkey <(cat <<< "$PRIVATE_KEY") -out ${BASE_DIR}/cert/corrade_cert.pfx


#extract to temp
    if [[ -f ${FILE_PATH_OR_URL_TO_CORRADE_ZIP} ]]
        then
            unzip ${FILE_PATH_OR_URL_TO_CORRADE_ZIP} -d ${BASE_DIR}/temp
    elif [[ -d ${FILE_PATH_OR_URL_TO_CORRADE_ZIP} ]]
        then
            unzip <(curl -Ls ${FILE_PATH_OR_URL_TO_CORRADE_ZIP}) -d ${BASE_DIR}/temp
    else
        echo "Corrade source is not valid."
    fi

#Begin Install
    cp -R ${BASE_DIR}/temp/* ${BASE_DIR}/live
    rm -rf ${BASE_DIR}/temp/*


    if [ PATH_TO_CONFIG_XML != "" ];
        then
            yes | cp -f ${PATH_TO_CONFIG_XML} ${BASE_DIR}/live
            xmlstarlet ed -L -d "Configuration/Servers/TCPserver/Certificate/Password" ${BASE_DIR}/live/Confinguration.xml
            xmlstarlet ed -L -d "Configuration/Servers/TCPserver/Certificate/Path" ${BASE_DIR}/live/Confinguration.xml
            systemctl enable corrade.service
            systemctl start corrade.service
        else
        echo "Please start corrade manually after you update the configuration.xml"

        #echo "Certificate Pass: $RANDOM_PASSWORD"
        echo "Certificate File: $BASE_DIR/cert/corrade_cert.pfx"
        echo "Configuration File: $BASE_DIR/live/Confinguration.xml"

        echo "systemctl enable corrade.service then systemctl start corrade.service"
    fi

}

function installCorradeLinuxServer() {
    mkdir -p ${BASE_DIR}/corrade-linux-server

    git clone -b master --single-branch https://github.com/MidnightRift/corrade-linux-server.git ${BASE_DIR}/corrade-linux-server

    cp ${BASE_DIR}/corrade-linux-server/setup/corrade.service /etc/systemd/system/corrade.service
    cp ${BASE_DIR}/corrade-linux-server/setup/corrade /usr/local/bin/corrade

    chmod 755 /usr/local/bin/corrade


}

function setupFirewalld() {

    systemctl enable firewalld.service
    systemctl start firewalld.service

    firewall-cmd --permanent --zone=public --add-service=https
    firewall-cmd --permanent --zone=public --add-service=http
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

function setupLetsEncrypt() {
    openssl dhparam -out /etc/ssl/certs/dhparam.pem 2048
    certbot certonly --standalone --email ${CERT_BOT_EMAIL} --agree-tos -d $HOSTNAME
    crontab -l | { cat; echo "$((RANDOM %59+1)) 4 * * 1 /usr/local/bin/corrade --cron >> $BASE_DIR/logs/cron.log"; } | crontab -
}

function installMono() {
    rpm --import "https://keyserver.ubuntu.com/pks/lookup?op=get&search=0x3FA7E0328081BFF6A14DA29AA6A19B38D3D831EF"
    su -c 'curl https://download.mono-project.com/repo/centos7-stable.repo | tee /etc/yum.repos.d/mono-centos7-stable.repo'
    yum install -y mono-complete
}

###

yum update -y
yum install -y epel-release
yum install -y --enablerepo=epel git openssl openssl-devel nginx firewalld unzip certbot xmlstarlet



#begin Setup

installMono

setupFirewalld

installCorradeLinuxServer

setupNginx

setupLetsEncrypt

installCorrade

setPerms