# Installation

Run as root

## Info

This project is specifically tailored to work with [node-corrade](https://github.com/MidnightRift/node-corrade) but should work with anything really as long as you use the external ports.


This will launch Corrade with the TCP and HTTP server configured and both placed behind nginx and the public facing ports secured with a certificate from Let's Encrypt.


Public ports are exposed, internal ports are behind a firewall.
### TCP
Internal: 4095

External: 9000

### HTTPS
Internal: 8008

External: 443 (default)


## Install

there are 3 arguments to the install script.

FILE_PATH_OR_URL_TO_CORRADE_ZIP -> this is a file either local or via a url in zip format.

FILE_PATH_TO_XML_CONF -> this is your Corrade configuration file.

CERT_BOT_EMAIL -> if you do not provide a certbot email the install script will use `root@$HOSTNAME`


```
bash <(curl -Ls https://raw.githubusercontent.com/MidnightRift/corrade-linux-server/master/setup.sh) \
FILE_PATH_OR_URL_TO_CORRADE_ZIP FILE_PATH_TO_XML_CONF (optional)CERT_BOT_EMAIL
```

## Commands 

- corrade --start   : Start Corrade
- corrade --stop    : Stop Corrade.
- corrade --restart : Restarts Corrade.
- corrade --status  : Shows Corrade status.
- corrade --update  : Update Corrade.
- corrade --save    : Creates a backup of the live codebase.
- corrade --restore : Restore previous installed version of Corrade.
- corrade --help    : Lists info about commands.






### Commands - what they do.

- corrade --start   -> systemctl start corrade.service
- corrade --stop    -> systemctl stop corrade.service
- corrade --restart -> systemctl restart corrade.service
- corrade --status  -> systemctl status corrade.service
- corrade --update  -> Makes a backup of Corrade, then installs from url or file path.
- corrade --save    -> Creates a backup of the live codebase.
- corrade --restore -> Unless changed backups are @ `/opt/corrade/backups` - after you choose this it will ask for a file path E.G `/opt/corrade/backups/CORRADE_BACKUP_2019-05-15_11-30-31.tar.gz`

