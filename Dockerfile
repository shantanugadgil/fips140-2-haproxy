FROM centos:7 as builder

RUN yum install -y gcc wget gpg perl make patch

RUN wget https://www.openssl.org/source/openssl-fips-2.0.16.tar.gz

# This isn't a great way to verify the archive, any suggestions would
# be appreciated
RUN wget https://www.openssl.org/source/openssl-fips-2.0.16.tar.gz.asc
ADD levitte.asc /tmp/levitte.asc
ADD henson.asc /tmp/henson.asc
ADD caswell.asc /tmp/caswell.asc
RUN gpg --import /tmp/levitte.asc /tmp/henson.asc /tmp/caswell.asc
RUN gpg --verify openssl-fips-2.0.16.tar.gz.asc || exit 1

RUN tar -zxvf openssl-fips-2.0.16.tar.gz

# Build the FIPS module according to the instructions at
# https://www.openssl.org/docs/fips/UserGuide-2.0.pdf
RUN cd openssl-fips-2.0.16 && ./config
RUN cd openssl-fips-2.0.16 && make
RUN cd openssl-fips-2.0.16 && make install

# Build the OpenSSL library
RUN wget https://www.openssl.org/source/openssl-1.0.2l.tar.gz
RUN tar -zxvf openssl-1.0.2l.tar.gz
RUN cd openssl-1.0.2l && ./config fips -I/usr/local/ssl/fips-2.0/include
RUN cd openssl-1.0.2l && make depend
RUN cd openssl-1.0.2l && make
RUN cd openssl-1.0.2l && make install

# Build haproxy linked against the new OpenSSL 
RUN wget http://www.haproxy.org/download/1.7/src/haproxy-1.7.8.tar.gz
RUN tar -zxvf haproxy-1.7.8.tar.gz
ADD haproxy.patch /tmp
RUN cd haproxy-1.7.8 && patch -p0 < /tmp/haproxy.patch
RUN cd haproxy-1.7.8 && make TARGET=linux26 USE_OPENSSL=1 SSL_INC=/usr/local/ssl/include SSL_LIB=/usr/local/ssl/lib CC=/usr/local/ssl/fips-2.0/bin/fipsld FIPSLD_CC=gcc -j8
RUN cd haproxy-1.7.8 && make install

RUN find /  | grep -i haproxy

FROM centos:7
COPY --from=0 /usr/local/ssl/ /usr/local/ssl/
COPY --from=0 /usr/local/sbin/haproxy /usr/local/sbin/
COPY --from=0 /usr/local/doc/haproxy /usr/local/doc/
COPY --from=0 /usr/local/share/man/man1/haproxy.1 /usr/local/share/man/man1/
CMD ["/usr/local/sbin/haproxy", "-f", "/usr/local/etc/haproxy/haproxy.cfg"]
