#!/bin/bash
#
# letsencrypt renew for cron / shell
# by André Bauer
# https://github.com/monotek/letsencrypt-renew/
# LICENSE: https://raw.githubusercontent.com/monotek/letsencrypt-renew/master/LICENSE
#

PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin

#config
LETSENCRPYT_CMD="/usr/bin/letsencrypt"
LETSENCRYPT_CERTS="/etc/letsencrypt/live"
LETSENCRYPT_HTTP_DIR="/var/www/letsencrypt"
KEY_SIZE="4096"
# creates tempfiles in .well-known dir in domain folder
LE_METHOD="--webroot-path /var/www/${DOMAIN}/html/ --webroot"
# opens letsencrypt prozess on port 80. can be used for creating certs on another server. reverse proxy to this server by looking for .well-known dir
#LE_METHOD="--standalone-supported-challenges http-01 --standalone" 
UPLOAD_TO_WEBSERVER="no"
WEBSERVER="root@your.host"
WEBSERVER_CERTS_DIR="/etc/nginx/ssl"
RESTART_WEBSERVER="yes"

# use command line arguments for domains or add the to the domains.yml
if [ -n "${1}" ]; then
    DOMAINS="${1}"
else
    DOMAINS="$(sed 's/le-domains://' < domains.yml)"
fi

# functions
function actionstart (){
    echo -e "\n`date '+%d.%m.%G %H:%M:%S'` - ${1}"
}

function exitcode (){
    if [ "$?" = 0 ]; then
        echo "`date '+%d.%m.%G %H:%M:%S'` - ${1} - ok "
    else
        echo "`date '+%d.%m.%G %H:%M:%S'` - ${1} - not ok "
        let ERROR_COUNT=ERROR_COUNT+1
    fi
}

# script
for DOMAIN in ${DOMAINS}; do

    if [ "$(echo ${DOMAIN} | awk -F . '{print NF-1}')" -gt "1" ]; then
	actionstart "create cert for ${DOMAIN} without www subdomain"
	${LETSENCRYPT_CMD} certonly --rsa-key-size ${KEY_SIZE} --duplicate --text ${LE_METHOD} -d ${DOMAIN}
	exitcode "create cert for ${DOMAIN} without www subdomain"
    else
	actionstart "create cert for ${DOMAIN} including www sub domain"
	${LETSENCRYPT_CMD} certonly --rsa-key-size ${KEY_SIZE} --duplicate --text ${LE_METHOD} -d ${DOMAIN} -d www.${DOMAIN}
	exitcode "create cert for ${DOMAIN} including www sub domain"
    fi

    NEWEST_CERT=$(ls ${LETSENCRYPT_CERTS} | egrep "^${DOMAIN}(|-[0-9]{4})$" | tail -n 1)

    actionstart "create domain dir ${WEBSERVER_CERTS}/${DOMAIN}"
    test -d ${WEBSERVER_CERTS} || mkdir -p ${WEBSERVER_CERTS}
    exitcode "create domain dir ${WEBSERVER_CERTS}/${DOMAIN}"


    if [ "${UPLOAD_TO_WEBSERVER}" == "yes" ];then
	echo "uploading"

	actionstart "scp ${WEBSERVER_CERTS_DIR}/${DOMAIN}-fullchain.pem"
	scp ${LETSENCRYPT_CERTS}/${NEWEST_CERT}/fullchain.pem ${WEBSERVER}:${WEBSERVER_CERTS_DIR}/${DOMAIN}-fullchain.pem
	exitcode "scp ${WEBSERVER_CERTS_DIR}/${DOMAIN}-fullchain.pem"

	actionstart "scp ${WEBSERVER_CERTS_DIR}/${DOMAIN}-privkey.pem"
	scp ${LETSENCRYPT_CERTS}/${NEWEST_CERT}/privkey.pem ${WEBSERVER}:${WEBSERVER_CERTS_DIR}/${DOMAIN}-privkey.pem
	exitcode "scp ${WEBSERVER_CERTS_DIR}/${DOMAIN}-privkey.pem"
    else
	echo "copy to local ssl dir"

	actionstart "cp ${WEBSERVER_CERTS_DIR}/${DOMAIN}-fullchain.pem"
	cp ${LETSENCRYPT_CERTS}/${NEWEST_CERT}/fullchain.pem ${WEBSERVER_CERTS_DIR}/${DOMAIN}-fullchain.pem
	exitcode "cp ${WEBSERVER_CERTS_DIR}/${DOMAIN}-fullchain.pem"

	actionstart "cp ${WEBSERVER_CERTS_DIR}/${DOMAIN}-privkey.pem"
	cp ${LETSENCRYPT_CERTS}/${NEWEST_CERT}/privkey.pem ${WEBSERVER_CERTS_DIR}/${DOMAIN}-privkey.pem
	exitcode "cp ${WEBSERVER_CERTS_DIR}/${DOMAIN}-privkey.pem"
    fi

done

if [ "${RESTART_WEBSERVER}" == "yes" ];then
    echo "restarting webserver..."

    if [ -n "$(which nginx)" ]; then
	systemctl restart nginx
    elif[ -n "$(which apache2)" ]; then
	systemctl restart apache
    else
	echo "no webserver found"
    fi
fi
