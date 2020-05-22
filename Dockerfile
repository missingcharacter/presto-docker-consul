FROM openjdk:11.0.7-jre-slim-buster

# Build arg expected, what version of presto are we building? (Presto's .tar.gz files extract to a versioned folder, we need to know what it's named)
ARG BUILD_VERSION
ENV PRESTO_VERSION presto-server-${BUILD_VERSION}

ENV GOPATH /usr/local/go
RUN mkdir -p ${GOPATH}

ADD container_init.sh /container_init.sh
RUN apt update && \
    apt install -y curl && \
    mkdir -p /opt/presto && \
    curl -L "https://repo1.maven.org/maven2/io/prestosql/presto-server/${BUILD_VERSION}/${PRESTO_VERSION}.tar.gz" -o "/opt/presto/${PRESTO_VERSION}.tar.gz" && \
    tar -xzvf "/opt/presto/${PRESTO_VERSION}.tar.gz" -C /opt/presto/ && \
    ln -s /opt/presto/${PRESTO_VERSION} /opt/presto/latest && \
    chmod +x /container_init.sh && \
    mkdir -p /opt/presto/conf/catalog && \
    mkdir -p /var/lib/presto/data && \
    rm -rf /opt/presto/latest/etc && \
    ln -s /opt/presto/conf /opt/presto/latest/etc

#\ && (cd /opt/presto && tar xvf ${PRESTO_VERSION}.tar.gz)

# Fsconsul for making files from consul k/v - use consul 1.0.0 since 'master' is broken somehow in consul's go libs. Fsconsul should use godep/govendor :(
RUN apt update && \
    apt install -y golang-1.11-go git-core uuid python && \
    ln -s /usr/lib/go-1.11/bin/go /usr/bin/go
RUN go get -d github.com/Cimpress-MCP/fsconsul && \
    (cd ${GOPATH}/src/github.com/hashicorp/consul && git checkout v1.0.0) && \
    go install github.com/Cimpress-MCP/fsconsul && \
    apt clean all && \
    rm -rf /var/log/apt/* /var/log/alternatives.log /var/log/bootstrap.log /var/log/dpkg.log

# Run the init script to start fsconsul and presto after
CMD /container_init.sh
