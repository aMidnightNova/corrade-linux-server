#!/usr/bin/env bash
BASE_DIR="/opt/corrade"

function doContinue() {
ANS=""

while [[ ! $ANS =~ ^([yY][eE][sS]|[yY])$ ]]
    do
        if [[ $ANS =~ ^([nN][oO]|[nN])$ ]]
            then
                return 1
            else
                read -p "Continue y/n? " ANS
        fi

        if [[ $ANS =~ ^([yY][eE][sS]|[yY])$ ]]
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

function doSave() {

    STAMP=`date +%Y-%m-%d_%H-%M-%S`

    if [ "$1" == "verbose" ]
        then
            tar -zcvf ${BASE_DIR}/backups/CORRADE.tar.gz -C ${BASE_DIR}/live .
        else
            tar -zcf ${BASE_DIR}/backups/CORRADE.tar.gz -C ${BASE_DIR}/live .
    fi

    echo "saved IN $BASE_DIR/backups/CORRADE_$STAMP.tar.gz ON `date`"
}

function doUpdate() {

    if doContinue $1;
        then
            read -p "File? (full path | url,zip): " CHOSEN_FILE
            echo "Using: " ${CHOSEN_FILE}
            sleep 1

            #clean temp jic
            rm -rf ${BASE_DIR}/temp/*
            #extract to temp
            if [[ -f ${CHOSEN_FILE} ]]
                then
                    unzip ${CHOSEN_FILE} -d ${BASE_DIR}/temp
            elif [[ -d ${CHOSEN_FILE} ]]
                then
                    unzip <(curl -Ls ${CHOSEN_FILE}) -d ${BASE_DIR}/temp
            else
                echo "Corrade source is not valid."
            fi

            doSave verbose

            stopCorrade
            rm -rf ${BASE_DIR}/live/*

            cp -R ${BASE_DIR}/temp/* ${BASE_DIR}/live
            startCorrade

        else
            exit
    fi
}




function doRestore() {

    echo "Listing backup files:"

    find ${BASE_DIR}/backups -type f -printf "%f\n" | sort

    read -p "Choose a File: " CHOSEN_FILE
    echo "Using: " ${CHOSEN_FILE}
    sleep 1

    RESTORE_FILE_PATH="$BASE_DIR/backups/$CHOSEN_FILE"

    stopCorrade
    rm -rf ${BASE_DIR}/live/*
    tar -zxvf ${RESTORE_FILE_PATH} -C ${BASE_DIR}/live
    startCorrade

    echo "Restored"
}


function getHelp() {
    echo " --stop      : Stops Corrade."
    echo " --start     : Starts Corrade."
    echo " --restart   : Restarts Corrade."
    echo " --status    : Restarts Corrade."
    echo " --restore   : Restore previous installed version of Corrade."
    echo " --update    : Update Corrade."
}


function getStatus() {
    systemctl status corrade.service
}

function startCorrade() {
    systemctl start corrade.service
}

function stopCorrade() {
    systemctl stop corrade.service
}

function restartCorrade() {
    systemctl restart corrade.service
}






if [ "$2" != "" ];
    then
        echo "Single argument only."
        exit
fi

case $1 in
    --help)
        getHelp
        ;;
    --status)
        getStatus
        ;;
    --update)
        doUpdate
        ;;
    --restore)
        doRestore
        ;;
    --start)
        startCorrade
        ;;
    --stop)
        stopCorrade
        ;;
    --restart)
        restartCorrade
        ;;
    *)
        echo "ERROR: unknown parameter \"$1\""
        getHelp
        ;;
esac