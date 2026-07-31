FROM alpine:3.19
# Supports both amd64 and arm64

ENV SYMDS_DIR=/opt/symmetric
ENV SYMDS_ZIP=symmetric.zip
ENV SYMDS_VERSION=3.7.38
ARG SYMDS_URL=https://sourceforge.net/projects/symmetricds/files/symmetricds/symmetricds-3.7/symmetric-server-$SYMDS_VERSION.zip/download
ARG POSTGRESQL_JDBC_VERSION=42.2.18
ENV POSTGRESQL_JDBC_URL=https://jdbc.postgresql.org/download/postgresql-$POSTGRESQL_JDBC_VERSION.jre7.jar

RUN adduser -D symmetricds

# Note: Alpine 3.19 uses openjdk17 by default, which is more modern than openjdk7
# SymmetricDS 3.7.35 is compatible with Java 8+
RUN apk add --update --no-cache \
    ca-certificates \
    bash \
    curl \
    openssl \
    openjdk17-jre-headless \
    && \
    rm -rf \
        /root/src/ \
        /tmp/* \
        /var/cache/apk/* \
        /usr/lib/{engines,gio,gtk-2.0,girepository-1.0}/ \
        /usr/lib/{gdk-pibuf,cario,alsa-lib,krb5}/ \
        /usr/lib/lib{glib,gio,gmodule,gobject,gthread,ffi}* \
        /usr/lib/lib{freetype,harfbuzz,lcms,atk,pango,cairo}* \
        /usr/lib/lib{gdk,gtk,cups,jpeg,turbo,pc,tiff,avahi}* \
        /usr/lib/lib{,asound,dbus,pixman,kr,x,X}* \
        /usr/share/{X11,alsa,doc,fontconfig,gtk-doc} \
        /usr/share/,icons,man,mime,misc,p11-kit,pkgconfig,terminfo,themes,xml} \
        /usr/lib/jvm/java-1.7-openjdk/jre/lib/amd64/server/classes.jsa

RUN curl -L $SYMDS_URL -o $SYMDS_ZIP && \
    mkdir -p /opt && \
    unzip -q $SYMDS_ZIP -d /opt/ && \
    mv /opt/symmetric-server-$SYMDS_VERSION $SYMDS_DIR && \
    rm -rf \
        $SYMDS_ZIP \
        $SYMDS_DIR/doc \
        $SYMDS_DIR/lib/aws-java-sdk-*.jar \
        $SYMDS_DIR/lib/h2-*.jar \
        $SYMDS_DIR/lib/hsqldb-*.jar \
        $SYMDS_DIR/lib/jna-*.tar \
        $SYMDS_DIR/lib/jt400-*.jar \
        $SYMDS_DIR/lib/mariadb-java-client-*.jar \
        $SYMDS_DIR/lib/mongo-java-driver-*.jar \
        $SYMDS_DIR/lib/mysql-connector-java-*.jar \
        $SYMDS_DIR/lib/ojdbc-*.jar \
        $SYMDS_DIR/lib/postgresql-*.jar \
        $SYMDS_DIR/lib/sqlite-jdbc-*.jar \
        $SYMDS_DIR/lib/voltdbclient-*.jar \
        $SYMDS_DIR/lib/web/WEB-INF/jna-*.tar \
        $SYMDS_DIR/lib/web/WEB-INF/scala-library-*.jar && \
    cd $SYMDS_DIR/lib && \
    curl -OL $POSTGRESQL_JDBC_URL && \
    chown -R symmetricds $SYMDS_DIR && \
    # SymmetricDS 3.7.38 bundles a stale truststore at
    # $SYMDS_DIR/security/cacerts, and entrypoint.sh pins the JVM to it via
    # -Djavax.net.ssl.trustStore. It lacks modern roots (e.g. Let's Encrypt
    # ISRG Root X1), so HTTPS registration fails with "PKIX path building
    # failed". Overlay the openjdk17 cacerts (which has modern roots) onto
    # that path at build time and keep it readable by the symmetricds user.
    cp /usr/lib/jvm/java-17-openjdk/lib/security/cacerts $SYMDS_DIR/security/cacerts && \
    chown symmetricds $SYMDS_DIR/security/cacerts

COPY entrypoint.sh /entrypoint.sh
COPY log4j.xml $SYMDS_DIR/conf/log4j.xml
COPY jetty-web.xml $SYMDS_DIR/tmp
COPY psql.class $SYMDS_DIR/lib/psql.class
COPY web.xml $SYMDS_DIR/tmp

VOLUME /opt/symmetric/tmp

USER symmetricds

ENTRYPOINT ["/entrypoint.sh"]

EXPOSE 31415
EXPOSE 31416
EXPOSE 31417
