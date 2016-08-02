FROM alpine:3.4
ENV SYMDS_DIR /opt/symmetric
ENV SYMDS_ZIP symmetric.zip
ENV SYMDS_VERSION 3.7.35
ARG SYMDS_URL=https://sourceforge.net/projects/symmetricds/files/symmetricds/symmetricds-3.7/symmetric-server-$SYMDS_VERSION.zip/download

RUN adduser -D symmetricds
RUN apk add --update --no-cache ca-certificates bash curl openjdk7-jre-base && \
    rm -rf \
        /root/src/ \
        /tmp/* \
        /var/cache/apk/* \
        /usr/lib/{engines,gio,gtk-2.0,girepository-1.0,gdk-pibuf,cario,alsa-lib,krb5}/ \
        /usr/lib/lib{glib,gio,gmodule,gobject,gthread,ffi,freetype,harfbuzz,lcms,atk,pango,cairo}* \
        /usr/lib/lib{gdk,gtk,cups,jpeg,turbo,pc,tiff,avahi,asound,dbus,pixman,kr,x,X}* \
        /usr/share/{X11,alsa,doc,fontconfig,gtk-doc,icons,man,mime,misc,p11-kit,pkgconfig,terminfo,themes,xml}
RUN curl -L $SYMDS_URL -o $SYMDS_ZIP && \
    mkdir -p /opt && \
    unzip -q $SYMDS_ZIP -d /opt/ && \
    mv /opt/symmetric-server-$SYMDS_VERSION $SYMDS_DIR && \
    chown -R symmetricds $SYMDS_DIR && \
    rm -rf \
        $SYMDS_ZIP \
        $SYMDS_DIR/doc \
        $SYMDS_DIR/lib/aws-java-sdk-*.jar \
        $SYMDS_DIR/h2-*.jar \
        $SYMDS_DIR/hsqldb-*.jar \
        $SYMDS_DIR/jna-*.tar \
        $SYMDS_DIR/jt400-*.jar \
        $SYMDS_DIR/mariadb-java-client-*.jar \
        $SYMDS_DIR/mongo-java-driver-*.jar \
        $SYMDS_DIR/mysql-connector-java-*.jar \
        $SYMDS_DIR/ojdbc-*.jar \
        $SYMDS_DIR/sqlite-jdbc-*.jar \
        $SYMDS_DIR/voltdbclient-*.jar \
        $SYMDS_DIR/web/WEB-INF/jna-*.tar \
        $SYMDS_DIR/web/WEB-INF/scala-library-*.jar
RUN rm /usr/lib/jvm/java-1.7-openjdk/jre/lib/amd64/server/classes.jsa
COPY entrypoint.sh /entrypoint.sh

VOLUME /opt/symmetric/logs
VOLUME /opt/symmetric/tmp

USER symmetricds

ENTRYPOINT ["/entrypoint.sh"]

EXPOSE 31415
EXPOSE 31416
EXPOSE 31417
