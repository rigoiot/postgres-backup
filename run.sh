#!/bin/bash
# ==== 参数验证 ====
[ -z "${POSTGRES_HOST}" ] && { echo "=> POSTGRES_HOST cannot be empty" && exit 1; }
[ -z "${POSTGRES_PORT}" ] && { echo "=> POSTGRES_PORT cannot be empty" && exit 1; }
[ -z "${POSTGRES_USER}" ] && { echo "=> POSTGRES_USER cannot be empty" && exit 1; }
[ -z "${POSTGRES_PASSWORD}" ] && { echo "=> POSTGRES_PASSWORD cannot be empty" && exit 1; }

export PGPASSWORD="${POSTGRES_PASSWORD}"
 
# ==== 备份命令模板 ====
BACKUP_CMD="pg_dumpall -h ${POSTGRES_HOST} -p ${POSTGRES_PORT} -U ${POSTGRES_USER} | gzip > /backup/dump_\${BACKUP_NAME_CORE}.sql.gz 2> /_failed/failed_\${BACKUP_NAME_CORE}.log"

if ! [ -d /_failed ]; then
  mkdir /_failed
fi
if ! [ -d /backup ]; then
  mkdir /backup
fi

# ==== 生成备份脚本 ====
echo "=> Creating backup script"
rm -f /backup.sh
cat <<EOF >> /backup.sh
#!/bin/bash

MAX_BACKUPS=${MAX_BACKUPS}
SLACK=${SLACK_WEBHOOK}
BACKUP_NAME_CORE=\$(date +%Y-%m-%d_%H_%M_%S)
BACKUP_FILE="/backup/dump_\${BACKUP_NAME_CORE}.sql.gz"
LATEST_FILE="/backup/dump_latest.sql.gz"

export PGPASSWORD="${POSTGRES_PASSWORD}"

echo "=> Backup started: \${BACKUP_NAME_CORE}"

if ${BACKUP_CMD}; then
    echo "   Backup succeeded"
    
    # 更新最新备份文件
    cp -f "\${BACKUP_FILE}" "\${LATEST_FILE}"

    rm -f /_failed/failed_\${BACKUP_NAME_CORE}.log

    if [ -n "\${SLACK}" ]; then
      curl -s -X POST --data-urlencode "payload={\"username\": \"Backup BOT\", \"text\": \"*MAINTENANCE* - database backup succeeded: file=*\\\${BACKUP_FILE}*\"}" \${SLACK}
    fi
else
    echo "   Backup failed"
    rm -f "\${BACKUP_FILE}"
    if [ -n "\${SLACK}" ]; then
      curl -s -X POST --data-urlencode "payload={\"username\": \"Backup BOT\", \"text\": \"*MAINTENANCE* - database backup failed\"}" \${SLACK}
    fi
fi

# ==== 保留最新 MAX_BACKUPS 个历史备份 ====
if [ -n "\${MAX_BACKUPS}" ]; then
    while [ \$(ls /backup/dump_*.sql.gz | grep -v "dump_latest.sql.gz" | wc -l) -gt \${MAX_BACKUPS} ]; do
        BACKUP_TO_BE_DELETED=\$(ls /backup/dump_*.sql.gz | grep -v "dump_latest.sql.gz" | sort | head -n 1)
        echo "   Backup \${BACKUP_TO_BE_DELETED} is deleted"
        rm -f "\${BACKUP_TO_BE_DELETED}"
    done
fi

echo "=> Backup done"
EOF

chmod +x /backup.sh

# ==== 日志 ====
touch /postgres_backup.log
tail -F /postgres_backup.log &

# ==== 设置 cron ====
echo "${CRON_TIME} /backup.sh >> /postgres_backup.log 2>&1" > /crontab.conf
crontab /crontab.conf
echo "=> Running cron job"
exec cron -f
