#!/bin/bash
[ -z "${POSTGRES_HOST}" ] && { echo "=> POSTGRES_HOST cannot be empty" && exit 1; }
[ -z "${POSTGRES_PORT}" ] && { echo "=> POSTGRES_PORT cannot be empty" && exit 1; }
[ -z "${POSTGRES_USER}" ] && { echo "=> POSTGRES_USER cannot be empty" && exit 1; }
[ -z "${POSTGRES_PASSWORD}" ] && { echo "=> POSTGRES_PASSWORD cannot be empty" && exit 1; }
[ -z "${POSTGRES_DB}" ] && { echo "=> POSTGRES_DB cannot be empty" && exit 1; }

export PGPASSWORD="${POSTGRES_PASSWORD}"

while getopts ":d" opt; do
  case $opt in
    d)
      echo "Directory mode ( compression by default )" >&2
      DIR_MODE=true
      ;;
    *)
      echo "Plain text format ( no compresion ) saved into .sql file" >&2
      ;;
  esac
done

BACKUP_BASE="pg_dump -h ${POSTGRES_HOST} -p ${POSTGRES_PORT} -U ${POSTGRES_USER} ${POSTGRES_DB}"
ERR_REDIRECT="2> /_failed/failed_${BACKUP_NAME_CORE}.log"

if [[ -n ${DIR_MODE} ]]; then
  BACKUP_CMD="$BACKUP_BASE -Fd -f /backup/dump_\${BACKUP_NAME_CORE} $ERR_REDIRECT"
else
  BACKUP_CMD="$BACKUP_BASE -c > /backup/dump_\${BACKUP_NAME_CORE}.sql $ERR_REDIRECT"
fi

if ! [ -d /_failed ]; then
  mkdir /_failed
fi
if ! [ -d /backup ]; then
  mkdir /backup
fi

echo "=> Creating backup script"
rm -f /backup.sh
cat <<EOF >> /backup.sh
#!/bin/bash
MAX_BACKUPS=${MAX_BACKUPS}
SLACK=${SLACK_WEBHOOK}
BACKUP_NAME_CORE=\$(date +%d-%m-%Y_%H_%M_%S)
export PGPASSWORD="${POSTGRES_PASSWORD}"
echo "=> Backup started: \${BACKUP_NAME_CORE}"
if ${BACKUP_CMD} ;then
    echo "   Backup succeeded"
    rm -rf /_failed/failed_\${BACKUP_NAME_CORE}.log
    if [ -n "\${SLACK}" ]; then
      curl -s -X POST --data-urlencode "payload={\"username\": \"Backup BOT\", \"text\": \"*HA MAINTENANCE* - database backup succeded: file=*dump_\${BACKUP_NAME_CORE}.sql*\"}" \${SLACK}
    fi
else
    echo "   Backup failed"
    rm -rf /backup/\dump_${BACKUP_NAME_CORE}.sql
    if [ -n "\${SLACK}" ]; then
      curl -s -X POST --data-urlencode "payload={\"username\": \"Backup BOT\", \"text\": \"*HA MAINTENANCE* - database backup failed\"}" \${SLACK}
    fi
fi
if [ -n "\${MAX_BACKUPS}" ]; then
    while [ \$(ls /backup | wc -l) -gt \${MAX_BACKUPS} ];
    do
        BACKUP_TO_BE_DELETED=\$(ls /backup | sort | head -n 1)
        echo "   Backup \${BACKUP_TO_BE_DELETED} is deleted"
        rm -rf /backup/\${BACKUP_TO_BE_DELETED}
    done
fi
echo "=> Backup done"
EOF
chmod +x /backup.sh

touch /postgres_backup.log
tail -F /postgres_backup.log &

echo "${CRON_TIME} /backup.sh >> /postgres_backup.log 2>&1" > /crontab.conf
crontab  /crontab.conf
echo "=> Running cron job"
exec cron -f 
