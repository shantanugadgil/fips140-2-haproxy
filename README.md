# fips140-2-haproxy

This repo contains a Docker container with HAProxy compiled against
the FIPS 140-2 OpenSSL module.  It is not intended to be used as is,
but as an example for building a **hopefully** FIPS 140-2 compliant
HAProxy.

This dockerfile uses the multi-stage build support available in newer
versions of Docker.  It should be straight forward to split it into
two dockerfiles, or remove the second part of the build and use a
single dockerfile if desired.  The only downside would be a larger
image.

# Build ContainerImage

```docker build . -t tzneal/haproxy-fips140-2```

# Pull image from dockerhub
```docker pull tzneal/haproxy-fips140-2```


# Example Usage
To run haproxy, you need to supply a configuraion file. The repository
contains a sample config file that can be run as:

```docker run --rm -d -v `pwd`/sample:/usr/local/etc/haproxy:ro -p 8080:443 --name haproxy-example tzneal/haproxy-fips140-2```

To verify it's running, visit https://localhost:8080 and you should see the HAProxy statistics.

To kill the container run ```docker kill haproxy-example```

