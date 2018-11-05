FROM centos:7 as builder

ENV HAPROXY_MAJOR_VER 1.8
ENV HAPROXY_VER 1.8.13
ENV OPENSSL_VER 1.0.2o
ENV OPENSSL_FIPS_VER 2.0.16

RUN yum -y update
RUN yum install -y gcc wget gpg perl make patch pcre-static pcre-devel zlib-devel curl

RUN wget https://www.openssl.org/source/openssl-fips-${OPENSSL_FIPS_VER}.tar.gz
#RUN wget https://www.openssl.org/source/openssl-fips-${OPENSSL_FIPS_VER}.tar.gz.sha256
#RUN sha256sum -c openssl-fips-${OPENSSL_FIPS_VER}.tar.gz.sha256 || exit 1

# This isn't a great way to verify the archive, any suggestions would
# be appreciated
#RUN wget https://www.openssl.org/source/openssl-fips-${OPENSSL_FIPS_VER}.tar.gz.asc
#ADD levitte.asc /tmp/levitte.asc
#ADD henson.asc /tmp/henson.asc
#ADD caswell.asc /tmp/caswell.asc
#RUN gpg --import /tmp/levitte.asc /tmp/henson.asc /tmp/caswell.asc
#RUN gpg --verify openssl-fips-${OPENSSL_FIPS_VER}.tar.gz.asc || exit 1

RUN tar oxvfm openssl-fips-${OPENSSL_FIPS_VER}.tar.gz

# Build the FIPS module according to the instructions at
# https://www.openssl.org/docs/fips/UserGuide-2.0.pdf
RUN cd openssl-fips-${OPENSSL_FIPS_VER} && ./config
RUN cd openssl-fips-${OPENSSL_FIPS_VER} && make
RUN cd openssl-fips-${OPENSSL_FIPS_VER} && make install

# Build the OpenSSL library
RUN wget https://www.openssl.org/source/openssl-${OPENSSL_VER}.tar.gz
#RUN wget https://www.openssl.org/source/openssl-${OPENSSL_VER}.tar.gz.sha256
#RUN sha256sum -c openssl-${OPENSSL_VER}.tar.gz.sha256sum

RUN tar oxvfm openssl-${OPENSSL_VER}.tar.gz
RUN cd openssl-${OPENSSL_VER} && ./config fips shared --openssldir=/usr/local/ssl --with-fipsdir=/usr/local/ssl/fips-2.0 --with-fipslibdir=/usr/local/ssl/fips-2.0/lib/
RUN cd openssl-${OPENSSL_VER} && make depend
RUN cd openssl-${OPENSSL_VER} && make
RUN cd openssl-${OPENSSL_VER} && make install

RUN find /usr/local/ssl

# Build haproxy linked against the new OpenSSL
RUN wget http://www.haproxy.org/download/${HAPROXY_MAJOR_VER}/src/haproxy-${HAPROXY_VER}.tar.gz
RUN tar oxvmf haproxy-${HAPROXY_VER}.tar.gz
ADD haproxy.patch /tmp
RUN cd haproxy-${HAPROXY_VER} && patch -p0 < /tmp/haproxy.patch
RUN cd haproxy-${HAPROXY_VER} && bash -c "export LD_LIBRARY_PATH=/usr/local/ssl/lib; make TARGET=linux2628 USE_LIBCRYPT= USE_PCRE=1 USE_STATIC_PCRE=1 USE_OPENSSL=1 USE_ZLIB=1 SSL_INC=/usr/local/ssl/include SSL_LIB=/usr/local/ssl/lib CC=/usr/local/ssl/fips-2.0/bin/fipsld FIPSLD_CC=gcc LDFLAGS=-Wl,-rpath=/usr/local/ssl/lib -j4"
RUN cd haproxy-${HAPROXY_VER} && make install

RUN find /  | grep -i haproxy
RUN yum clean all && rm -rf /var/cache/yum

FROM centos:7
COPY --from=builder /usr/local/ssl/ /usr/local/ssl/
COPY --from=builder /usr/local/sbin/haproxy /usr/local/sbin/
COPY --from=builder /usr/local/doc/haproxy /usr/local/doc/
COPY --from=builder /usr/local/share/man/man1/haproxy.1 /usr/local/share/man/man1/
CMD ["/usr/local/sbin/haproxy", "-f", "/usr/local/etc/haproxy/haproxy.cfg"]
