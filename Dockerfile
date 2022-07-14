FROM docker.io/python:3.10-alpine

ARG UWSGI_VERSION=2.0.20

COPY buildconfig.ini /buildconfig.ini

RUN set -ex \
    && addgroup -g 101 -S uwsgi \
    && adduser -S -D -H -u 101 -h /var/cache/uwsgi -s /sbin/nologin -G uwsgi -g uwsgi uwsgi \
    && apk add --no-cache --virtual .fetch-deps \
        gnupg \
        tar \
        gzip \
    \
    && wget -O uwsgi.tar.gz "http://projects.unbit.it/downloads/uwsgi-$UWSGI_VERSION.tar.gz" \
    && mkdir -p /usr/src/uwsgi \
    && tar -xzC /usr/src/uwsgi --strip-components=1 -f uwsgi.tar.gz \
    && rm uwsgi.tar.gz \
    \
    # Optimization: add build deps before removing fetch deps in case there's overlap
    && apk add --no-cache --virtual .build-deps  \
        gcc \
        libc-dev \
        openssl-dev \
        linux-headers \
    && apk del --no-network .fetch-deps \
    \
    && cd /usr/src/uwsgi \
    && CC="gcc" python3 uwsgiconfig.py --build /buildconfig.ini \
    && rm /buildconfig.ini \
    && install -m 755 -D uwsgi /usr/local/sbin/uwsgi \
    && install -D LICENSE /usr/local/share/licenses/uwsgi/LICENSE \
    && rm -rf /usr/src/uwsgi \
    \
    && apk del --no-network .build-deps \
    \
    && mkdir /uwsgi-entrypoint.d

STOPSIGNAL SIGINT

COPY uwsgi.ini /etc/uwsgi/uwsgi.ini
COPY entrypoint/10-listen-on-ipv6-by-default.sh /docker-entrypoint.d/10-listen-on-ipv6-by-default.sh
COPY entrypoint/docker-entrypoint.sh /docker-entrypoint.sh
ENTRYPOINT ["/docker-entrypoint.sh"]

EXPOSE 16910

CMD [ "uwsgi", "--ini", "/etc/uwsgi/uwsgi.ini" ]
