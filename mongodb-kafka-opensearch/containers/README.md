# Containers
See below for manual build steps.

## Connect Container Image Build
Build the custom Kafka Connect container image:
```
cd containers/connect &&\
docker build --build-arg DEBEZIUM_VERSION=3.2.2.Final -t your_registry_namespace/my-custom-connect:2.3 .
```
