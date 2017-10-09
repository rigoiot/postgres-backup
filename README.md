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
docker tag [IMAGE_ID] [YOUR_DOCKERHUB_REPO]
docker push [YOUR_DOCKERHUB_REPO]

```

## Using image
```yaml
service_name:
    image: [YOUR_DOCKERHUB_REPO]}
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

### Helpful links
* https://crontab.guru/
* https://api.slack.com/incoming-webhooks