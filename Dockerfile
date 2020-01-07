FROM openjdk:8-jre

# Build arg expected, what version of presto are we building? (Presto's .tar.gz files extract to a versioned folder, we need to know what it's named)
ARG BUILD_VERSION
ENV PRESTO_VERSION presto-server-${BUILD_VERSION}

ENV GOPATH /usr/local/go
RUN mkdir -p ${GOPATH}

ADD ${PRESTO_VERSION}.tar.gz /opt/presto/
ADD container_init.sh /container_init.sh
RUN ln -s /opt/presto/${PRESTO_VERSION} /opt/presto/latest && \
	chmod +x /container_init.sh && \
	mkdir -p /opt/presto/conf/catalog && \
	mkdir -p /var/lib/presto/data && \
	rm -rf /opt/presto/latest/etc && \
	ln -s /opt/presto/conf /opt/presto/latest/etc

#\ && (cd /opt/presto && tar xvf ${PRESTO_VERSION}.tar.gz)

# Fsconsul for making files from consul k/v - use consul 1.0.0 since 'master' is broken somehow in consul's go libs. Fsconsul should use godep/govendor :(
RUN apt-get update && apt-get install -y golang-go git-core uuid python
RUN go get -d github.com/Cimpress-MCP/fsconsul && (cd ${GOPATH}/src/github.com/hashicorp/consul && git checkout v1.0.0) && go install github.com/Cimpress-MCP/fsconsul

# Run the init script to start fsconsul and presto after
CMD /container_init.sh
