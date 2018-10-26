#!/bin/bash

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

#source ${DIR}/bin/local.sh

[ -z "${POSTGRES_HOST}" ] && { echo "=> POSTGRES_HOST cannot be empty" && exit 1; }
[ -z "${POSTGRES_PORT}" ] && { echo "=> POSTGRES_PORT cannot be empty" && exit 1; }
[ -z "${POSTGRES_USER}" ] && { echo "=> POSTGRES_USER cannot be empty" && exit 1; }
[ -z "${POSTGRES_REPL_USER}" ] && { echo "=> POSTGRES_REPL_USER cannot be empty" && exit 1; }
[ -z "${POSTGRES_PASSWORD}" ] && { echo "=> POSTGRES_PASSWORD cannot be empty" && exit 1; }
[ -z "${POSTGRES_DB}" ] && { echo "=> POSTGRES_DB cannot be empty" && exit 1; }
[ -z "${WAL_BACKUP_RETENTION_MINUTES}" ] && { echo "=> WAL_BACKUP_RETENTION_MINUTES cannot be empty" && exit 1; }

export PGPASSWORD="${POSTGRES_PASSWORD}"

BACKUP_CMD="pg_dump -h ${POSTGRES_HOST} -p ${POSTGRES_PORT} -U ${POSTGRES_USER} ${POSTGRES_DB} -F plain -Z 6 -f ${DIR}/backup/dump_\${BACKUP_NAME_CORE}.sql.gz 2> ${DIR}/_failed/failed_\${BACKUP_NAME_CORE}.log"
WAL_BACKUP_CMD="pg_basebackup -h ${POSTGRES_HOST} -p ${POSTGRES_PORT} --username=${POSTGRES_REPL_USER} -X stream -D ${DIR}/wal_backup/\${BACKUP_NAME_CORE} -w -R --checkpoint=fast --label=wal_backup_\${BACKUP_NAME_CORE} 2> ${DIR}/_failed/failed_\${BACKUP_NAME_CORE}.log"

if ! [ -d ${DIR}/_failed ]; then
  mkdir ${DIR}/_failed
fi
if ! [ -d ${DIR}/backup ]; then
  mkdir ${DIR}/backup
fi
if ! [ -d ${DIR}/wal_backup ]; then
  mkdir ${DIR}/wal_backup
fi

echo "=> Creating backup script"
rm -f ${DIR}/backup.sh
cat <<EOF >> ${DIR}/backup.sh
#!/bin/bash
MAX_BACKUPS=${MAX_BACKUPS}
SLACK=${SLACK_WEBHOOK}
BACKUP_NAME_CORE=\$(date +%Y-%m-%d_%H_%M_%S)
export PGPASSWORD="${POSTGRES_PASSWORD}"
echo "=> Backup started: \${BACKUP_NAME_CORE}"
if ${BACKUP_CMD} ;then
    echo "   Backup succeeded"
    rm -rf ${DIR}/_failed/failed_\${BACKUP_NAME_CORE}.log
    if [ -n "\${SLACK}" ]; then
      curl -s -X POST --data-urlencode "payload={\"username\": \"Backup BOT\", \"text\": \"*MAINTENANCE* - database backup succeded: file=*dump_\${BACKUP_NAME_CORE}.sql*\"}" \${SLACK}
    fi
else
    echo "   Backup failed"
    rm -rf ${DIR}/backup/dump_\${BACKUP_NAME_CORE}.sql.gz
    if [ -n "\${SLACK}" ]; then
      curl -s -X POST --data-urlencode "payload={\"username\": \"Backup BOT\", \"text\": \"*MAINTENANCE* - database backup failed\"}" \${SLACK}
    fi
fi
if [ -n "\${MAX_BACKUPS}" ]; then
    while [ \$(ls ${DIR}/backup | wc -l) -gt \${MAX_BACKUPS} ];
    do
        BACKUP_TO_BE_DELETED=\$(ls ${DIR}/backup | sort | head -n 1)
        echo "   Backup \${BACKUP_TO_BE_DELETED} is deleted"
        rm -rf ${DIR}/backup/\${BACKUP_TO_BE_DELETED}
    done
fi
echo "=> Backup done"
EOF
chmod +x ${DIR}/backup.sh

echo "=> Creating WAL backup script"
rm -f wal_backup.sh
cat <<EOF >> ${DIR}/wal_backup.sh
#!/bin/bash
SLACK=${SLACK_WEBHOOK}
BACKUP_RETENTION_MINUTES=${WAL_BACKUP_RETENTION_MINUTES}
BACKUP_NAME_CORE=\$(date +%Y-%m-%d_%H_%M_%S)
export PGPASSWORD="${POSTGRES_PASSWORD}"
echo "=> WAL backup started: \${BACKUP_NAME_CORE}"
if ${WAL_BACKUP_CMD} ;then
    echo "   WAL backup succeeded"
    rm -rf ${DIR}/_failed/failed_\${BACKUP_NAME_CORE}.log
    if [ -n "\${SLACK}" ]; then
      curl -s -X POST --data-urlencode "payload={\"username\": \"Backup BOT\", \"text\": \"*MAINTENANCE* - database WAL backup succeded: file=*wal_\${BACKUP_NAME_CORE}.sql*\"}" \${SLACK}
    fi
else
    echo "   WAL backup failed"
    rm -rf ${DIR}/wal_backup/\${BACKUP_NAME_CORE}
    if [ -n "\${SLACK}" ]; then
      curl -s -X POST --data-urlencode "payload={\"username\": \"Backup BOT\", \"text\": \"*MAINTENANCE* - database WAL backup failed\"}" \${SLACK}
    fi
fi
if [ -n "\${BACKUP_RETENTION_MINUTES}" ]; then
    find ${DIR}/wal_backup -type d -mmin +\${BACKUP_RETENTION_MINUTES} -exec rm -rf '{}' +
fi
echo "=> Base backup done"
EOF
chmod +x ${DIR}/wal_backup.sh

touch ${DIR}/postgres_backup.log
tail -F ${DIR}/postgres_backup.log &

echo "${CRON_TIME} ${DIR}/backup.sh >> ${DIR}/postgres_backup.log 2>&1" > ${DIR}/crontab.conf
echo "${WAL_CRON_TIME} ${DIR}/wal_backup.sh >> ${DIR}/postgres_backup.log 2>&1" >> ${DIR}/crontab.conf
crontab  ${DIR}/crontab.conf
echo "=> Running cron job"
exec cron -f 
