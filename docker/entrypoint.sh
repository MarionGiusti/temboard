#!/bin/bash -eu

command=${*-temboard-agent}

export PGHOST=${PGHOST-${TEMBOARD_HOSTNAME-localhost}}
export PGPORT=${PGPORT-5432}
export PGUSER=${PGUSER-postgres}
PGPASSWORD=${PGPASSWORD-}
export PGDATABASE=${PGDATABASE-postgres}

COMPOSE_PROJECT=$(docker inspect --format "{{ index .Config.Labels \"com.docker.compose.project\"}}" $HOSTNAME)
links=($(docker inspect --format "{{range .NetworkSettings.Networks.${COMPOSE_PROJECT}_default.Links }}{{.}} {{end}}" $HOSTNAME))
links=(${links[@]%%:${TEMBOARD_HOSTNAME}})
PGCONTAINER=${links[@]%%*:*}
COMPOSE_SERVICE=$(docker inspect --format "{{ index .Config.Labels \"com.docker.compose.service\"}}" $HOSTNAME)

echo "Managing PostgreSQL container $PGCONTAINER." >&2

echo "Generating temboard-agent.conf" >&2

cat > /etc/temboard-agent/temboard-agent.conf <<EOF
# Generated by $0

[temboard]
home = /var/lib/temboard
users = /etc/temboard-agent/users
address = 0.0.0.0
port = 2345
ssl_cert_file = ${TEMBOARD_SSL_CERT}
ssl_key_file = ${TEMBOARD_SSL_KEY}
hostname = ${TEMBOARD_HOSTNAME-${hostname --fqdn}}
key = ${TEMBOARD_KEY}

[logging]
method = stderr
level = ${TEMBOARD_LOGGING_LEVEL}

[postgresql]
host = /var/run/postgresql/
port = ${PGPORT}
dbname = ${PGDATABASE}
user = ${PGUSER}
password = ${PGPASSWORD}
instance = ${PGINSTANCE-main}

[monitoring]
collector_url = ${TEMBOARD_UI_URL%/}/monitoring/collector
ssl_ca_cert_file = ${TEMBOARD_SSL_CA}

[administration]
pg_ctl = docker %s ${PGCONTAINER}
EOF


touch /etc/temboard-agent/users
chmod 0600 /etc/temboard-agent/users
for entry in ${TEMBOARD_USERS} ; do
    echo "Adding user ${entry%%:*}."
    sed -i /${entry%:*}/d /etc/temboard-agent/users
    temboard-agent-password $entry >> /etc/temboard-agent/users
done

wait-for-it ${PGHOST}:${PGPORT}

register() {
    set -x
    hostportpath=${TEMBOARD_UI_URL#*://}
    hostport=${hostportpath%%/*}
    wait-for-it localhost:2345 -t 60
    wait-for-it ${hostport} -t 60

    temboard-agent-register \
        --host ${TEMBOARD_REGISTER_HOST-$COMPOSE_SERVICE} \
        --port ${TEMBOARD_REGISTER_PORT-2345} \
        --groups ${TEMBOARD_GROUPS} \
        ${TEMBOARD_UI_URL%/}
}

if [ -z "${command##temboard-agent*}" -a -n "${TEMBOARD_UI_USER-}" ] ; then
    register &
fi

set -x
exec ${command}
