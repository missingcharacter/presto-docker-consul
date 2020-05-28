#!/bin/bash

# Environment variable defaults
: ${ENV:=DEV}
: ${CONSUL_ADDR:=172.17.42.1:8500}
: ${CONSUL_PREFIX:=/config/presto}
: ${PRESTO_ROLE:=worker}
: ${HEAP_PERCENT:=0.5}

# Calculate JVM Xmx (in MB) based off memory percentage of memory reported as available by Docker. Cap max JVM memory to 31GB (compressed pointers)
JVM_XMX=$(cat /sys/fs/cgroup/memory/memory.limit_in_bytes | awk -v "p=${HEAP_PERCENT}" '{v = ($1/1024^2)* p; printf("%d", v >= 31744 ? 31744 : v);}')

# Print out some debugging information
env
echo "$(date) | [INFO] Starting Presto as a ${PRESTO_ROLE} w/ ${JVM_XMX} MB heap. Looking in ${CONSUL_PREFIX} for all related K/V..."

# Create node.properties
cat > /opt/presto/conf/node.properties <<EOT
node.environment=${ENV}
node.id=$(uuid)
node.data-dir=/var/lib/presto/data
EOT

# Create jvm.config
cat > /opt/presto/conf/jvm.config <<EOT
-server
-Xmx${JVM_XMX}m
-XX:+UseG1GC
-XX:G1HeapRegionSize=32M
-XX:+UseGCOverheadLimit
-XX:+ExplicitGCInvokesConcurrent
-XX:+HeapDumpOnOutOfMemoryError
-XX:OnOutOfMemoryError=kill -9 %p
EOT

# Start fsconsul to generate our catalog configs
/usr/local/go/bin/fsconsul -addr=${CONSUL_ADDR} -once=true ${CONSUL_PREFIX}/catalog/ /opt/presto/conf/catalog/

# Start fsconsul again to make the node configs
/usr/local/go/bin/fsconsul -addr=${CONSUL_ADDR} -once=true ${CONSUL_PREFIX}/${PRESTO_ROLE} /opt/presto/conf/

# Now start presto and let it run in the foreground
/opt/presto/latest/bin/launcher run
