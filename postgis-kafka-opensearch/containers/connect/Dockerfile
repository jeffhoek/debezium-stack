ARG DEBEZIUM_VERSION
FROM quay.io/debezium/connect:${DEBEZIUM_VERSION}
ENV KAFKA_CONNECT_OS_DIR=$KAFKA_CONNECT_PLUGINS_DIR/kafka-connect-opensearch

ARG OPENSEARCH_VERSION=3.1.1

# Deploy OpenSearch sink connector
RUN mkdir $KAFKA_CONNECT_OS_DIR && cd $KAFKA_CONNECT_OS_DIR &&\
        curl -sLO https://github.com/aiven/opensearch-connector-for-apache-kafka/releases/download/v$OPENSEARCH_VERSION/opensearch-connector-for-apache-kafka-$OPENSEARCH_VERSION.zip &&\
        unzip opensearch-connector-for-apache-kafka-$OPENSEARCH_VERSION.zip
