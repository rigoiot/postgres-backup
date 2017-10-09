FROM postgres:9.6.3

RUN apt-get update && \
    apt-get install -y wget curl netcat cron && \
    mkdir /backup && \
    mkdir /_failed

#RUN apk add --update curl wget && \
#    rm -rf /var/cache/apk/* && \
#    mkdir /backup && \
#    mkdir /_failed
#
#RUN mkdir -p /var/log/cron && mkdir -m 0644 -p /var/spool/cron/crontabs && touch /var/log/cron/cron.log && mkdir -m 0644 -p /etc/cron.d

VOLUME ["/backup"]
VOLUME ["/_failed"]

ADD run.sh /run.sh
RUN chmod +x /run.sh

CMD ["/run.sh"]