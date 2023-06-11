# Containers
See below for manual build steps.

## Connect Container Image Build
Build the custom Kafka Connect container image:
```
cd connect &&\
docker build --build-arg DEBEZIUM_VERSION=2.2 -t your_registry_namespace/connect-jdbc-opensearch:2.2 .
```

## Postgis Container Image Build
```
git clone https://github.com/debezium/container-images.git
cd container-images/postgres/15
```

Make the following changes.
1. Update plugin version:
```
-ENV PLUGIN_VERSION=v2.3.0.CR1
+ENV PLUGIN_VERSION=v2.0.0.Final-postgres15
```
2. Add unzip and wget:
```
-        software-properties-common \
+        software-properties-common unzip wget \
```

Build:
```
docker build -t your_registry_namespace/postgis:15-master-decoderbufs .
```
