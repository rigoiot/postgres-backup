FROM postgres:9.6.3

RUN apt-get update && \
    apt-get install -y wget curl cron && \
    mkdir /backup && \
    mkdir /_failed

VOLUME ["/backup"]
VOLUME ["/_failed"]

ADD run.sh /run.sh
RUN chmod +x /run.sh

CMD ["/run.sh"] 