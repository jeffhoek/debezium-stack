# Containers
See below for manual build steps.

## Connect Container Image Build
Build the custom Kafka Connect container image:
```
cd containers/connect &&\
docker build --build-arg DEBEZIUM_VERSION=2.3 -t your_registry_namespace/connect-jdbc-opensearch-mongodb:2.3 .
```
