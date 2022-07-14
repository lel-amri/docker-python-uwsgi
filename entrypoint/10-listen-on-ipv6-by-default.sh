#!/bin/sh
# vim:sw=4:ts=4:et
# Taken from https://github.com/nginxinc/docker-nginx/blob/3581b6708a9ad8f8511db4a2fd57a703b17903c2/entrypoint/10-listen-on-ipv6-by-default.sh

set -e

ME=$(basename $0)
DEFAULT_CONF_FILE="etc/uwsgi/uwsgi.ini"

# check if we have ipv6 available
if [ ! -f "/proc/net/if_inet6" ]; then
    echo >&3 "$ME: info: ipv6 not available"
    exit 0
fi

if [ ! -f "/$DEFAULT_CONF_FILE" ]; then
    echo >&3 "$ME: info: /$DEFAULT_CONF_FILE is not a file or does not exist"
    exit 0
fi

# check if the file can be modified, e.g. not on a r/o filesystem
touch /$DEFAULT_CONF_FILE 2>/dev/null || { echo >&3 "$ME: info: can not modify /$DEFAULT_CONF_FILE (read-only file system?)"; exit 0; }

# check if the file is already modified, e.g. on a container restart
grep -q "uwsgi-socket = \[::]\:16901" /$DEFAULT_CONF_FILE && { echo >&3 "$ME: info: IPv6 listen already enabled"; exit 0; }

if [ -f "/etc/os-release" ]; then
    . /etc/os-release
else
    echo >&3 "$ME: info: can not guess the operating system"
    exit 0
fi

echo >&3 "$ME: info: Getting the checksum of /$DEFAULT_CONF_FILE"

CHECKSUM='c1070f0740590e09a20bcd6aa9e77c0fa778ebaf'
echo "$CHECKSUM  /$DEFAULT_CONF_FILE" | sha1sum -c - >/dev/null 2>&1 || {
    echo >&3 "$ME: info: /$DEFAULT_CONF_FILE differs from the packaged version"
    exit 0
}

# enable ipv6 on uwsgi.ini listen sockets
# uWSGI directly instanciate a socket(2) and run bind(2) for every uwsgi-socket.
# This make bind(2) cause a EADDRINUSE errno on Linux on a "dual-stack" configuration
# because IPv4 and IPv6 share the port space.
# In case where IPv6 is supported by the system entirely replace IPv4-style uwsgi-socket
# option by an IPv6-style uwsgi-socket option.
sed -i -E 's,uwsgi-socket = 0\.0\.0\.0:16901,uwsgi-socket = [::]:16901,' /$DEFAULT_CONF_FILE

echo >&3 "$ME: info: Enabled listen on IPv6 in /$DEFAULT_CONF_FILE"

exit 0
