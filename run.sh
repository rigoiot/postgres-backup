#!/bin/bash
touch /postgres_backup.log
tail -F /postgres_backup.log &


echo "${CRON_TIME} /backup.sh >> /postgres_backup.log 2>&1" > /crontab.conf
crontab  /crontab.conf
echo "=> Running cron job"
exec cron -f