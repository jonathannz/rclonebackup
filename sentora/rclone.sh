#!/bin/bash

SERVER_NAME="$(ifconfig | grep broadcast | awk {'print $2'} | head -1)" # get IP
# SERVER_NAME="$(ifconfig | grep broadcast | awk {'print $2'} | awk '{if(NR==1) print $0}')"
# SERVER_NAME="$(ifconfig | grep broadcast | awk {'print $2'} | sed -n 1p)"
TIMESTAMP=$(date +"%F")
BACKUP_DIR="/root/backup/$TIMESTAMP"
MYSQLPATH="$(mysql --help | grep "Default options" -A 1 | sed -n 2p | awk {'print $2'} | sed 's/\~/\/root/')"
MYSQL_USER="root"
MYSQL_PASSWORD="$(cat /root/passwords.txt | grep "MySQL Root Password" | awk {'print $5'})"
MYSQL="$(which mysql)"
MYSQLDUMP="$(which mysqldump)"
SECONDS=0
CHECKSQL="$(ls /usr/bin/ | grep mysql)"
NGINX="$(ls /etc/ | grep nginx)"
NGINX_DIR="$(nginx -V 2>&1 | grep -o '\-\-conf-path=\(.*conf\)' | grep -o '.*/' | awk -F '=' {'print $NF'})"
HTTPD="$(ls /etc/ | grep -w httpd)"
HTTPD_DIR="$(httpd -S 2>&1 | grep ServerRoot | sed 's/\"//g' | awk {'print $2'})"
LOG_DIR=/var/log/
SENTORA="$(ls /var/ | grep sentora)"
VNC_RCLONE="$(rclone config file | grep rclone.conf | sed 's/rclone.conf//')"
VNC_RCLONE_REMOTE="$(cat $VNC_RCLONE/rclone.conf | grep "\[" | sed 's/\[//' | sed 's/\]//')"
mkdir -p "$BACKUP_DIR"

if [[ $CHECKSQL == "mysql" ]];

then
 	mkdir -p "$BACKUP_DIR/mysql"
  		databases=`$MYSQL --user=$MYSQL_USER -p$MYSQL_PASSWORD -e "SHOW DATABASES;" | grep -Ev "(Database|information_schema|performance_schema|mysql)"`

	echo "Starting Backup Database";

	for db in $databases; do
    	$MYSQLDUMP --force --opt --user=$MYSQL_USER -p$MYSQL_PASSWORD --databases $db | gzip > "$BACKUP_DIR/mysql/$db.sql.gz"
	done
	echo "Finished";
	echo '';
else
	echo "VPS not install Mysql"
fi


echo "Starting Backup Website";
# Loop through /home directory
if [ "$SENTORA" = "sentora" ]
then

	echo "VPS User sentora ";
	echo "Backup sentora Config";
     for D in /var/sentora/hostdata/*; do
  	  if [ -d "${D}" ]; then #If a directory
        domain=${D##*/} # Domain name
        echo "- "$domain;
        mkdrir -p $BACKUP_DIR/$domain/
        zip -r $BACKUP_DIR/$domain/$domain.zip /var/www/$domain -q -x home/$domain/wp-content/cache/**\* # No Cache
     	fi
      done
	cp /root/passwords.txt $BACKUP_DIR/sentora_password
	cp -r /etc/sentora/configs/ $BACKUP_DIR/sentora_config
	cp -r /etc/sentora/configs/apache/ $BACKUP_DIR/apache_config
	cp -r /etc/sentora/configs/proftpd/ $BACKUP_DIR/apache_FTP
	cp -r /var/sentora/logs/ $BACKUP_DIR/logs
	cp -r /var/sentora/vmail/ $BACKUP_DIR/vmail
else
	echo "VPS Not User sentora";
fi
echo "Finished";
echo '';

echo "Starting Backup Server Configuration";
if [ "$NGINX" = "nginx" ] && [ "$HTTPD" = "httpd" ]
then
	echo "Starting Backup nginx proxy, apache backend Configuration";
	cp -r $NGINX_DIR $BACKUP_DIR/nginx
	cp -r $HTTPD_DIR $BACKUP_DIR/httpd
	cp -r $LOG_DIR $BACKUP_DIR/log
	echo "Finished";
	echo '';
elif [ "$NGINX" = "nginx" ];
then
	echo "Starting Backup NGINX Configuration";
	cp -r $NGINX_DIR/ $BACKUP_DIR/nginx
	cp -r $LOG_DIR $BACKUP_DIR/log
	echo "Finished";
	echo '';

elif [ "$HTTPD" = "httpd" ];
then
	echo "Starting Backup HTTPD (apache) Configuration";
	cp -r $HTTPD_DIR $BACKUP_DIR/httpd
	cp -r $LOG_DIR $BACKUP_DIR/log
	echo "Finished";
	echo '';
else
	echo "VPS directory http, nginx not found";
fi



size=$(du -sh $BACKUP_DIR | awk '{ print $1}')
echo "Starting Uploading Backup";

for i in $VNC_RCLONE_REMOTE
	do
		rclone copy $BACKUP_DIR "$i:$SERVER_NAME/$TIMESTAMP" >> /var/log/rclone.log 2>&1
	echo "done upload $i"
done

# Clean up



for i in $VNC_RCLONE_REMOTE
	do
		rclone -q --min-age 30d delete "$i:$SERVER_NAME"
	echo "done remote $i"
done

rm -rf $BACKUP_DIR
echo "Finished";
echo '';

duration=$SECONDS
echo "Total $size, $(($duration / 60)) minutes and $(($duration % 60)) seconds elapsed."