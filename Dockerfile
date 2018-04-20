FROM openjdk:jre-alpine
ENV SYMDS_DIR /opt/symmetric
ENV SYMDS_ZIP symmetric.zip

RUN adduser -D symmetricds

RUN apk add --update --no-cache ca-certificates bash curl openssl && \
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
        /usr/share/,icons,man,mime,misc,p11-kit,pkgconfig,terminfo,themes,xml}

ENV SYMDS_VERSION 3.9.6
ENV SYMDS_VERSION_SHORT 3.9
ARG SYMDS_URL=https://sourceforge.net/projects/symmetricds/files/symmetricds/symmetricds-$SYMDS_VERSION_SHORT/symmetric-server-$SYMDS_VERSION.zip/download

RUN curl -L $SYMDS_URL -o $SYMDS_ZIP && \
    mkdir -p /opt && \
    unzip -q $SYMDS_ZIP -d /opt/ && \
    mv /opt/symmetric-server-$SYMDS_VERSION $SYMDS_DIR && \
    chown -R symmetricds $SYMDS_DIR && \
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
        $SYMDS_DIR/lib/sqlite-jdbc-*.jar \
        $SYMDS_DIR/lib/voltdbclient-*.jar \
        $SYMDS_DIR/lib/web/WEB-INF/jna-*.tar \
        $SYMDS_DIR/lib/web/WEB-INF/scala-library-*.jar

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
