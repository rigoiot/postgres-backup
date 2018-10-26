# postgres-backup
Cron-automated Postgres backup running on Docker

## Clone project

```
git clone git@github.com:rspective/postgres-backup.git
cd postgres-backup
```

## Image build
You need to be logged in your Docker Hub account locally

```
docker build ./
docker tag [IMAGE_ID] rspective/postgres_backup:[TAG_NAME]
docker push rspective/postgres_backup

```

## Using image

*All variables are required, there is no default values*

```yaml
service_name:
    image: rspective/postgres_backup:[TAG_NAME]
    container_name: [CUSTOM_NAME]
    links:
      - pg # link your DB from other service
    environment:
      - POSTGRES_HOST=pg # DB alias
      - POSTGRES_PORT=5432 # DB port
      - POSTGRES_USER=db_username
      - POSTGRES_PASSWORD=db_password
      - POSTGRES_DB=db_name
      - CRON_TIME= */1 * * * * # CRON settings, max resolution - once in a minute
      - MAX_BACKUPS=30 # if there is more backup files than limit, the oldest one will be removed
      - SLACK_WEBHOOK=https://hooks.slack.com/services/123123123/123123123/kjqekqjweSAddaS23eadsDAS # if set you will see notifications from success and failure
    volumes:
      - ./database/backup:/backup # backup files
      - ./database/failed:/_failed # failure logs
```

## Enable WAL

Update `postgresql.conf` 


```bash
# The WAL level should be hot_standby or logical.
wal_level = logical

# Allow up to 8 standbys and backup processes to connect at a time.
max_wal_senders = 8

# Retain 1GB worth of WAL files. Adjust this depending on your transaction rate.
max_wal_size = 1GB
```

Create a user. This streaming replication client in the slave node will connect to the master as this user.
```bash
/ # su - postgres
879a020a7544:~$ psql
psql (9.6.3)
Type "help" for help.

postgres=# create user repluser replication;
CREATE ROLE
postgres=# \q
```

In `pg_hba.conf`, allow this user to connect for replication.

```bash
# TYPE  DATABASE        USER            ADDRESS                 METHOD
host    replication     repluser        x.x.x.x/32              trust
```

### Helpful links
* https://crontab.guru/
* https://api.slack.com/incoming-webhooks
