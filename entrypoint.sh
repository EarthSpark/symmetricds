#!/bin/bash

set -eu

: ${AWS_ACCESS_KEY_ID:=}
: ${AWS_SECRET_ACCESS_KEY:=}
: ${AUTO_REGISTRATION:=true}
: ${AUTO_RELOAD:=true}
: ${DATABASE_URL:=postgresql://localhost:5432/symds}
: ${ENGINE_NAME:=engine-name}
: ${EXTERNAL_ID:=external-id}
: ${GROUP_ID:=group-id}
: ${PROPERTIES_FILE:=/tmp/symdb.properties}
: ${PROTOCOL:=https}
: ${PULL_PERIOD:=60000}
: ${PURGE_RETENTION:=43200}
: ${PUSH_PERIOD:=60000}
: ${REGISTRATION_URL:=}
: ${START_SYNCTRIGGERS:=false}
: ${SYM_HOME:=/opt/symmetric}
: ${SYNC_URL:=}

# s3simple is a small, simple bash s3 client with minimal dependencies.
# See http://github.com/paulhammond/s3simple for documentation and licence.
s3simple() {
    local command="$1"
    local url="$2"
    local file="${3:--}"

    # todo: nice error message if unsupported command?
    if [ "${url:0:5}" != "s3://" ]; then
        echo "Need an s3 url"
        return 1
    fi
    local path="${url:4}"

    if [ -z "${AWS_ACCESS_KEY_ID-}"  ]; then
        echo "Need AWS_ACCESS_KEY_ID to be set"
        return 1
    fi

    if [ -z "${AWS_SECRET_ACCESS_KEY-}" ]; then
        echo "Need AWS_SECRET_ACCESS_KEY to be set"
        return 1
    fi

    local method md5 args
    case "$command" in
        get)
            method="GET"
            md5=""
            args="-o $file"
            ;;
        put)
            method="PUT"
            if [ ! -f "$file" ]; then
                echo "file not found"
                exit 1
            fi
            md5="$(openssl md5 -binary $file | openssl base64)"
            args="-T $file -H Content-MD5:$md5"
            ;;
        *)
            echo "Unsupported command"
            return 1
    esac

    local date="$(date -u '+%a, %e %b %Y %H:%M:%S +0000')"
    local string_to_sign
    printf -v string_to_sign "%s\n%s\n\n%s\n%s" "$method" "$md5" "$date" "$path"
    local signature=$(echo -n "$string_to_sign" | openssl sha1 -binary -hmac "${AWS_SECRET_ACCESS_KEY}" | openssl base64)
    local authorization="AWS ${AWS_ACCESS_KEY_ID}:${signature}"

    curl $args -s -f -H Date:"${date}" -H Authorization:"${authorization}" https://s3.amazonaws.com"${path}"
}

create_java_options() {
    local options="-Dfile.encoding=utf-8 \
-Duser.language=en \
-Djava.io.tmpdir=${SYM_HOME}/tmp \
-Dorg.eclipse.jetty.server.Request.maxFormContentSize=800000 \
-Dorg.eclipse.jetty.server.Request.maxFormKeys=100000 \
-Djavax.net.ssl.trustStore=${SYM_HOME}/security/cacerts \
-Dlog4j.configuration=file:${SYM_HOME}/conf/log4j.xml \
-Dsun.net.client.defaultReadTimeout=1800000 \
-Dsun.net.client.defaultConnectTimeout=1800000 \
-Djava.net.preferIPv4Stack=true \
-XX:+HeapDumpOnOutOfMemoryError \
-XX:HeapDumpPath=${SYM_HOME}/tmp"
    echo $options
}

run_java() {
    local CLASSPATH="${SYM_HOME}/patches:${SYM_HOME}/patches/*:${SYM_HOME}/lib/*:${SYM_HOME}/web/WEB-INF/lib/*"
    java $SYM_OPTIONS -cp "$CLASSPATH" "$@"
}

run_sym() {
    run_java org.jumpmind.symmetric.SymmetricLauncher "$@"
}

run_symadmin() {
    run_java org.jumpmind.symmetric.SymmetricAdmin "$@"
}

export SYM_OPTIONS=$(create_java_options)

if [ ! -z "${KEYSTORE_URL+x}" ]; then
    echo "[ Downloading keystore from $KEYSTORE_URL ]"
    s3simple get $KEYSTORE_URL $SYM_HOME/security/keystore.downloaded
    SYM_OPTIONS="$SYM_OPTIONS -Dsym.keystore.file=$SYM_HOME/security/keystore.downloaded"
else
    SYM_OPTIONS="$SYM_OPTIONS -Dsym.keystore.file=$SYM_HOME/security/keystore"
fi

if [ ! -z "${DATABASE_URL+x}" ]; then
    tmp=$(echo "$DATABASE_URL" | awk -F/ '{print $3}')
    if [[ $tmp == *"@"* ]]; then
        user_pass=$(echo "$tmp" | awk -F@ '{print $1}')
        JDBC_HOST=$(echo "$tmp" | awk -F@ '{print $2}')
        JDBC_USER=$(echo "$user_pass" | awk -F: '{print $1}')
        JDBC_PASSWORD=$(echo "$user_pass" | awk -F: '{print $2}')
    else
        JDBC_HOST=$tmp
        JDBC_USER=""
        JDBC_PASSWORD=""
    fi
    JDBC_DBNAME=$(echo "$DATABASE_URL" | awk -F/ '{print $4}')
    JDBC_URL="jdbc:postgresql://${JDBC_HOST}/${JDBC_DBNAME}"

    SYM_OPTIONS="$SYM_OPTIONS -Ddb.driver=org.postgresql.Driver -Ddb.url=$JDBC_URL"

    if [ ! -z "${JDBC_USER}" ]; then
        SYM_OPTIONS="$SYM_OPTIONS -Ddb.user=$JDBC_USER"
    fi
    if [ ! -z "${JDBC_PASSWORD}" ]; then
        SYM_OPTIONS="$SYM_OPTIONS -Ddb.password=$JDBC_PASSWORD"
    fi
fi

# Enable HTTPS, disable HTTP
if [ "$PROTOCOL" = "https" ]; then
    SYM_OPTIONS="$SYM_OPTIONS -Dhttp.enable=false -Dhttps.allow.self.signed.certs=false"
    SYM_OPTIONS="$SYM_OPTIONS -Dhttps.enable=true"
else
    SYM_OPTIONS="$SYM_OPTIONS -Dhttp.enable=true -Dhttps.allow.self.signed.certs=false"
    SYM_OPTIONS="$SYM_OPTIONS -Dhttps.enable=false"
fi

echo "[ Runtime Options ]"
echo "$SYM_OPTIONS"

cd "$SYM_HOME"
echo "[ Running symadmin create-sym-tables ]"
cat <<EOF >> $PROPERTIES_FILE
engine.name=$ENGINE_NAME
group.id=$GROUP_ID
external.id=$EXTERNAL_ID
db.driver=org.postgresql.Driver
db.url=$JDBC_URL
db.user=$JDBC_USER
db.password=$JDBC_PASSWORD
job.pull.period.time.ms=${PULL_PERIOD}
job.push.period.time.ms=${PUSH_PERIOD}
start.synctriggers.job=${START_SYNCTRIGGERS}
purge.retention.minutes=${PURGE_RETENTION}
auto.reload=${AUTO_RELOAD}
auto.registration=${AUTO_REGISTRATION}
sync.url=$SYNC_URL
registration.url=$REGISTRATION_URL
EOF
run_symadmin --properties $PROPERTIES_FILE create-sym-tables

# echo "[ Checking if SymmetricDS is configured ]"
# stmt = "SELECT COUNT(*) FROM sym_node WHERE node_id = '$EXTERNAL_ID'"
# period = 10
# while true; do
#     if [ "$(psql stmt)" = "1" ]; then
#         break;
#     fi
#     echo "[ Not yet, waiting 30 seconds ]"
#     sleep 30
# done;

echo "[ Running sym ]"
PARAMS="--no-log-file --properties $PROPERTIES_FILE"

if [ ! -z "${CLIENT_ONLY+x}" ]; then
    PARAMS="$PARAMS --client"
fi

run_sym $PARAMS "$@"
