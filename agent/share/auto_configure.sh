#!/bin/bash -eu
#
# auto_configure.sh setup a temboard-agent to manage a Postgres cluster.
#
# Run auto_configure.sh as root. You configure it like any libpq software. By
# default, the script configure an agent for the running cluster on port 5432,
# using postgres UNIX and PostgreSQL user.
#
# The agent is running on the first free port starting from 2345. Each agent has
# its own user file. This file is emptied by the script.

ETCDIR=${ETCDIR-/etc/temboard-agent}
VARDIR=${VARDIR-/var/lib/temboard-agent}
LOGDIR=${LOGDIR-/var/log/temboard-agent}
LOGFILE=${LOGFILE-/var/log/temboard-agent-auto-configure.log}
SYSUSER=${SYSUSER-postgres}

set -o pipefail

catchall() {
	local exit_code=$?

	trap - INT EXIT TERM

	# shellcheck disable=SC2181
	if [ $exit_code -gt 0 ] ; then
		fatal "Failure. See ${LOGFILE} for details."
	else
		rm -f "${LOGFILE}"
	fi
}

error() {
	echo -e "\\e[1;31m$*\\e[0m" | tee -a /dev/fd/3 >&2
}

fatal() {
	error "$@"
	exit 1
}

log() {
	echo "$@" | tee -a /dev/fd/3 >&2
}

psql() {
	local wrapper
	wrapper=()

	if ! [ "$(whoami)" = "$SYSUSER" ] ; then
		wrapper=(sudo -Eu "$SYSUSER")
	fi

	command "${wrapper[@]}" psql -AtX "$@"
}

query_pgsettings() {
	# Usage: query_pgsettings name [default]

	local name=$1; shift
	local default=${1-}; shift
	val=$(psql -c "SELECT setting FROM pg_settings WHERE name = '${name}';")

	echo "${val:-${default}}"
}

find_next_free_port() {
	local port
	local used_a
	local used
	mapfile -t used_a < <(ss -ln4t '( sport >= 2345 and sport <= 3000 )' | grep -Po ':\K\d+')
	# To mock ss output, use seq:
	# mapfile -t used_a < <(seq 2345 3000)
	used="${used_a[*]:-}"
	for port in {2345..3000} ; do
		if [[ " $used " =~ \ $port\  ]] ; then continue ; fi
		echo "$port"
		return
	done
	log "No free TCP port found between 2345 and 3000. Force with env TEMBOARD_PORT."
	return 1
}

generate_configuration() {
	# Usage: generate_configuration homedir sslcert sslkey cluster_name

	# Generates minimal configuration required to adapt default
	# configuration to this cluster.

	local ui_url=$1; shift
	local home=$1; shift
	local sslcert=$1; shift
	local sslkey=$1; shift
	local instance=$1; shift
	local has_statements=$1; shift

	local pg_ctl
	local port

	sudo -u "$SYSUSER" test -r "$sslkey"
	sudo -u "$SYSUSER" test -r "$sslcert"

	port="${TEMBOARD_PORT-$(find_next_free_port)}"
	test -n "$port"
	log "Configuring temboard-agent to run on port ${port}."
	if ! pg_ctl="$(command -v pg_ctl)" ; then
		pg_ctl="/bin/false"
		log "Can't find pg_ctl in PATH."
		log "Please configure it manually to enable restart feature."
	fi

	plugins=(administration dashboard maintenance monitoring pgconf)
	if [ -n "$has_statements" ] ; then
		plugins+=(statements)
	fi
	printf -v qplugins ', "%s"' "${plugins[@]}"  # loose jsonify

	local usepeer
	if [ -n "${PGPASSWORD-}" ] ; then
	    usepeer=
	else
	    usepeer=1
	fi

	cat <<-EOF
	#
	#   T E M B O A R D   A G E N T   C O N F I G U R A T I O N
	#
	# Generated by ${BASH_SOURCE[0]} on $(date +%Y-%m-%d).
	#


	#
	# General temBoard agent configuration
	#
	[temboard]
	# Base URL of the UI managing this agent.
	ui_url = $ui_url
	# Directory for temBoard agent runtime files.
	home = ${home}
	# Host FQDN. Leave empty to let temBoard query system everytime.
	hostname = ${TEMBOARD_HOSTNAME}
	# Agent bind address.
	address = 0.0.0.0
	# Agent bind port.
	port = ${port}
	# Path to SSL Certificate for HTTPS.
	ssl_cert_file = ${sslcert}
	# Path to SSL private key for HTTPS.
	ssl_key_file = ${sslkey}
	# Enabled plugins.
	plugins = ["activity"${qplugins[@]}]

	#
	# Managed PostgreSQL instance configuration
	#
	[postgresql]
	# UNIX socket directory where PostgreSQL is listening.
	host = ${PGHOST}
	# PostgreSQL listening port.
	port = ${PGPORT}
	# PostgreSQL connection role.
	user = ${PGUSER}
	# PostgreSQL password if peer authentication is disabled.
	${usepeer:+# }password = ${PGPASSWORD-}
	# Default database for connection.
	dbname = ${PGDATABASE}

	#
	# temBoard Agent logging configuration
	#
	[logging]
	# Available methods for logging: stderr, syslog or file
	method = stderr
	# Syslog facility.
	# facility = local0
	# Log destination, should be /dev/log for syslog on Linux system.
	# When using file logging method, this is referencing the log file path.
	# destination = /var/log/temboard-agent/${instance}/temboard-agent.log
	# Log level, can be: DEBUG, INFO, WARNING, ERROR or CRITICAL.
	level = INFO

	#
	# temBoard agent plugin configuration
	#
	[administration]
	# Path to pg_ctl. %s is either start, restart or reload.
	pg_ctl = ${pg_ctl} %s -D ${PGDATA}

	[dashboard]
	# Interval, in second, between each run of the process collecting
	# data used to render the dashboard. Default: 2
	# scheduler_interval = 2
	# Number of record to keep. Default: 150
	# history_length = 150

	[monitoring]
	# Comma separated list of database names to monitor. * for all.
	dbnames = *
	# List of probes to run, comma separator, * for all.
	# Available probes: bgwriter,blocks,btree_bloat,cpu,db_size,filesystems_size,heap_bloat,loadavg,locks,memory,process,replication_connection,replication_lag,sessions,tblspc_size,temp_files_size_delta,wal_files,xacts
	probes = *
	# Interval, in second, between each run of the process executing
	# the probes. Default: 60
	# scheduler_interval = 60

	[statements]
	# DB name hosting pg_stat_statements view (the one where the extension has
	# been created with "CREATE EXTENSION")
	dbname = ${PGDATABASE}

	# temBoard agent overrides values of this file with .conf files
	# found in directory named after this filename, with .d suffix. e.g.
	# temboard-agent.conf.d/custom.conf.
	EOF
}

search_bindir() {
	# Usage: search_bindir pgversion

	# Search for bin directory where pg_ctl is installed for this version.

	local pgversion=$1; shift
	for d in /usr/lib/postgresql/$pgversion /usr/pgsql-$pgversion ; do
		if [ -x "$d/bin/pg_ctl" ] ; then
			echo "$d/bin"
			return
		fi
	done
	return 1
}

setup_pq() {
	# Ensure used libpq vars are defined for configuration template.

	export PGUSER=${PGUSER-postgres}
	log "Configuring for PostgreSQL user ${PGUSER}."
	export PGDATABASE=${PGDATABASE-${PGUSER}}
	export PGPORT=${PGPORT-5432}
	log "Configuring for cluster on port ${PGPORT}."
	export PGHOST=${PGHOST-$(query_pgsettings unix_socket_directories)}
	PGHOST=${PGHOST%%,*}
	if ! psql -c "SELECT 'Postgres connection working.';" ; then
		fatal "Can't connect to Postgres cluster."
	fi
	export PGDATA
	PGDATA=$(query_pgsettings data_directory)
	log "Configuring for cluster at ${PGDATA}."

	read -r PGVERSION < "${PGDATA}/PG_VERSION"
	if ! command -v pg_ctl &>/dev/null ; then
	    if bindir=$(search_bindir "$PGVERSION") ; then
			log "Using ${bindir}/pg_ctl."
			export PATH=$bindir:$PATH
	    fi
	fi

	# Instance name defaults to cluster_name. If unset (e.g. Postgres 9.4),
	# use the tail of ${PGDATA} after ~postgres has been removed. If PGDATA
	# is not in postgres home, compute a cluster name from version and port.
	local home
	home="$(eval readlink -e "~${SYSUSER}")"
	if [ -z "${PGDATA##"${home}"/*}" ] ; then
		default_cluster_name="${PGDATA##"${home}"/}"
	else
		default_cluster_name=$PGVERSION/pg${PGPORT}
	fi
	export PGCLUSTER_NAME
	PGCLUSTER_NAME=$(query_pgsettings cluster_name "$default_cluster_name")
	log "Cluster name is $PGCLUSTER_NAME."
}

setup_ssl() {
	local name=${1//\//-}; shift
	local pki
	read -r pki < <(readlink -e /etc/pki/tls /etc/ssl "$ETCDIR/$name")
	pki="${PKIDIR-$pki}"

	if [ -f "$pki/certs/ssl-cert-snakeoil.pem" ] && [ -f "$pki/private/ssl-cert-snakeoil.key" ] ; then
		log "Using snake-oil SSL certificate."
		sslcert=$pki/certs/ssl-cert-snakeoil.pem
		sslkey=$pki/private/ssl-cert-snakeoil.key
	else
		sslcert=$pki/certs/temboard-agent-$name.pem
		sslkey=$pki/private/temboard-agent-$name.key
		openssl req -new -x509 -days 365 -nodes \
			-subj "/C=XX/ST= /L=Default/O=Default/OU= /CN= " \
			-out "$sslcert" -keyout "$sslkey"
		chmod 0640 "$sslkey"
		chgrp "$(id --group --name "$SYSUSER")" "$sslcert" "$sslkey"
	fi

	readlink -e "$sslcert" "$sslkey"
}

if [ -n "${DEBUG-}" ] ; then
	exec 3>/dev/null
else
	exec 3>&2 2>"${LOGFILE}" 1>&2
	chmod 0600 "${LOGFILE}"
	trap 'catchall' INT EXIT TERM
fi

# Now, log everything.
set -x

if [ -z "${1-}" ] ; then
	fatal "Missing temBoard UI URL as first parameter."
fi

umask 037

cd "$(readlink -m "${BASH_SOURCE[0]}/..")"

export TEMBOARD_HOSTNAME=${TEMBOARD_HOSTNAME-$(hostname --fqdn)}
if [ -n "${TEMBOARD_HOSTNAME##*.*}" ] ; then
	fatal "FQDN is not properly configured. Set agent hostname with TEMBOARD_HOSTNAME env var.".
fi
log "Using hostname ${TEMBOARD_HOSTNAME}."

setup_pq

name=${PGCLUSTER_NAME}
home=${VARDIR}/${name}

if [ -f "${ETCDIR}/${name}/temboard-agent.conf" ] ; then
	error "${ETCDIR}/${name}/temboard-agent.conf already exists."
	error "To clean previous installation, use"
	error
	error "    ${0/auto_configure/purge} ${name}"
	error
	fatal "Refusing to overwrite existing configuration."
fi

# Create directories
mkdir --parents \
	"${ETCDIR}/${name}/temboard-agent.conf.d/" \
	"${LOGDIR}" "${home}"
chown --recursive "${SYSUSER}:${SYSUSER}" "${ETCDIR}" "${VARDIR}" "${LOGDIR}"

has_statements=$(psql -c "SELECT 'HAS_STATEMENTS' FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'pg_stat_statements';")

# Start with default configuration
log "Configuring temboard-agent in ${ETCDIR}/${name}/temboard-agent.conf ."

mapfile -t sslfiles < <(set -eu; setup_ssl "$name")

# Inject autoconfiguration in dedicated file.
conf=${ETCDIR}/${name}/temboard-agent.conf
generate_configuration "$1" "$home" "${sslfiles[0]}" "${sslfiles[1]}" "$name" "$has_statements" | tee "$conf"
chown "$SYSUSER:$SYSUSER" "$conf"

# Use type -p to search in auto_configure.sh PATH.
sudo -Eu "${SYSUSER}" $(type -p temboard-agent) -c "$conf" discover >/dev/null

# systemd
if grep -q systemd /proc/1/cmdline && [ -w /etc/systemd/system ] ; then
	unit="temboard-agent@$(systemd-escape "${name}").service"
	log "Configuring systemd unit ${unit}."
	if [ "${SYSUSER}" != "postgres" ] ; then
		mkdir -p "/etc/systemd/system/$unit.d/"
		cat > "/etc/systemd/system/$unit.d/user.conf" <<-EOF
		[Service]
		User=${SYSUSER}
		Group=${SYSGROUP}
		EOF
	fi
	start_cmd="systemctl enable --now $unit"
else
	start_cmd="sudo -u ${SYSUSER} temboard-agent -c $conf"
fi

log
log "Success. You now need to fetch UI signing key using:"
log
log "    sudo -u $SYSUSER temboard-agent -c $conf fetch-key"
log
log "Then start agent service using:"
log
log "    ${start_cmd}"
log
log "See documentation for detailed instructions."
