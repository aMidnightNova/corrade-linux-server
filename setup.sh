#!/usr/bin/env bash

BASE_DIR="/opt/corrade"

source ${BASE_DIR}/corrade-linux-server/setup/nginx.conf

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










function installMono() {
    rpm --import "https://keyserver.ubuntu.com/pks/lookup?op=get&search=0x3FA7E0328081BFF6A14DA29AA6A19B38D3D831EF"
    su -c 'curl https://download.mono-project.com/repo/centos7-stable.repo | tee /etc/yum.repos.d/mono-centos7-stable.repo'
    yum install -y mono-complete
}

function setupFirewalld() {
    systemctl enable firewalld.service
    systemctl start firewalld.service

    firewall-cmd --permanent --zone=public --add-service=https
    firewall-cmd --permanent --zone=public --add-service=http
    firewall-cmd --permanent --zone=public --add-port=9000/tcp #tcp
    firewall-cmd --permanent --zone=public --add-port=9005/tcp #mqtt
    systemctl restart firewalld.service
}

function installCorradeLinuxServer() {
    mkdir -p ${BASE_DIR}/corrade-linux-server

    git clone -b master --single-branch https://github.com/MidnightRift/corrade-linux-server.git ${BASE_DIR}/corrade-linux-server

    cp ${BASE_DIR}/corrade-linux-server/setup/corrade.service /etc/systemd/system/corrade.service
    cp ${BASE_DIR}/corrade-linux-server/setup/corrade /usr/local/bin/corrade

    chmod 755 /usr/local/bin/corrade


}

function setupNginx() {
    echo "${NGINX_CONF}" > /etc/nginx/nginx.conf
    echo "${CORRADE_HTTP_PROXY}" > /etc/nginx/conf.d/corrade_http_proxy.conf
    echo "${CORRADE_MQTT_PROXY}" > /etc/nginx/conf.d/corrade_mqtt_proxy.conf
    echo "${CORRADE_TCP_PROXY}" > /etc/nginx/conf.d/corrade_tcp_proxy.conf

    RANDOM_PASSWORD=$(head /dev/urandom | tr -dc A-Za-z0-9 | head -c 16 ; echo '')

    htpasswd -c -b /etc/nginx/.htpasswd corrade ${RANDOM_PASSWORD}
    echo "Basic Auth"
    echo "User: corrade"
    echo "Password: $RANDOM_PASSWORD"

    systemctl enable nginx.service
    systemctl start nginx.service
}

function setupLetsEncrypt() {
    openssl dhparam -out /etc/ssl/certs/dhparam.pem 2048
    certbot certonly --non-interactive --staging --standalone --email ${CERT_BOT_EMAIL} --agree-tos -d $HOSTNAME
    crontab -l | { cat; echo "$((RANDOM %59+1)) 4 * * 1 /usr/local/bin/corrade --cron >> $BASE_DIR/logs/cron.log"; } | crontab -
}

function createDirectorStructure() {
    mkdir -p ${BASE_DIR}/live
    mkdir -p ${BASE_DIR}/logs
    mkdir -p ${BASE_DIR}/backups
    mkdir -p ${BASE_DIR}/temp
    mkdir -p ${BASE_DIR}/cert
}

function createCerts() {
    openssl genrsa -out ${BASE_DIR}/cert/corrade_private_key.pem 2048
    openssl req -new -key ${BASE_DIR}/cert/corrade_private_key.pem -subj "/CN=$HOSTNAME" -out ${BASE_DIR}/cert/corrade_csr.csr
    openssl x509 -signkey ${BASE_DIR}/cert/corrade_private_key.pem -in ${BASE_DIR}/cert/corrade_csr.csr -req -days 3650 -out ${BASE_DIR}/cert/corrade_cert.pem
    openssl pkcs12 -export -passout pass: -in ${BASE_DIR}/cert/corrade_cert.pem -inkey ${BASE_DIR}/cert/corrade_private_key.pem -out ${BASE_DIR}/cert/corrade_pfx_cert.pfx
    openssl rsa -in ${BASE_DIR}/cert/corrade_private_key.pem -outform PVK -pvk-none -out ${BASE_DIR}/cert/corrade_pvk_cert.pvk
}

installCorrade(){
    id -u corrade &>/dev/null || useradd corrade
    id -g corrade &>/dev/null || groupadd corrade


    mkdir -p ${BASE_DIR}/live
    mkdir -p ${BASE_DIR}/logs
    mkdir -p ${BASE_DIR}/backups
    mkdir -p ${BASE_DIR}/temp

    #RANDOM_PASSWORD=$(head /dev/urandom | tr -dc A-Za-z0-9 | head -c 16 ; echo '')


#extract to temp
    if [[ -f ${FILE_PATH_OR_URL_TO_CORRADE_ZIP} ]]
        then
            unzip ${FILE_PATH_OR_URL_TO_CORRADE_ZIP} -d ${BASE_DIR}/temp
    elif [[ ${FILE_PATH_OR_URL_TO_CORRADE_ZIP} =~ https?://* ]]
        then
            curl -Ls ${FILE_PATH_OR_URL_TO_CORRADE_ZIP} | bsdtar -xf - -C ${BASE_DIR}/temp
    else
        echo "Corrade source is not valid."
    fi

#Begin Install
    cp -R ${BASE_DIR}/temp/* ${BASE_DIR}/live
    rm -rf ${BASE_DIR}/temp/*

    #tell mono to use a cert on the 8080 port
    httpcfg -add -port 8080 -pvk ${BASE_DIR}/cert/corrade_pvk_cert.pvk -cert ${BASE_DIR}/cert/corrade_cert.pem

    if [ PATH_TO_CONFIG_XML != "" ];
        then
            yes | cp -f ${PATH_TO_CONFIG_XML} ${BASE_DIR}/live
            #remove password and protocol fields
            xmlstarlet ed -L -d "Configuration/Servers/TCPserver/TCPCertificate/Password" ${BASE_DIR}/live/Configuration.xml
            xmlstarlet ed -L -d "Configuration/Servers/TCPserver/TCPCertificate/Protocol" ${BASE_DIR}/live/Configuration.xml

            xmlstarlet ed -L -u "Configuration/Servers/TCPserver/TCPCertificate/Path" -v "$BASE_DIR/cert/corrade_pfx_cert.pfx" ${BASE_DIR}/live/Configuration.xml

            xmlstarlet ed -L -u "Configuration/Servers/MQTTServer/MQTTCertificate/Path" -v "$BASE_DIR/cert/corrade_pfx_cert.pfx" ${BASE_DIR}/live/Configuration.xml

            xmlstarlet ed -L -u "Configuration/Servers/HTTPServer/Prefixes/Prefix" -v "https://+:8080/" ${BASE_DIR}/live/Configuration.xml


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

function setPerms()  {
  if [ -d "$BASE_DIR/live" ]; then
    chown -R corrade:corrade ${BASE_DIR}/live
  fi
}



###

yum update -y
yum install -y epel-release
yum install -y --enablerepo=epel git openssl openssl-devel nginx firewalld unzip certbot xmlstarlet httpd-tools bsdtar



#begin Setup

installMono

setupFirewalld

installCorradeLinuxServer

setupNginx

setupLetsEncrypt

createDirectorStructure

createCerts

installCorrade

setPerms