ARG DEBEZIUM_VERSION
oops...

FROM quay.io/debezium/connect:${DEBEZIUM_VERSION}
ENV KAFKA_CONNECT_JDBC_DIR=$KAFKA_CONNECT_PLUGINS_DIR/kafka-connect-jdbc \
    KAFKA_CONNECT_ES_DIR=$KAFKA_CONNECT_PLUGINS_DIR/kafka-connect-elasticsearch \
    KAFKA_CONNECT_OS_DIR=$KAFKA_CONNECT_PLUGINS_DIR/kafka-connect-opensearch \
    KAFKA_CONNECT_MONGODB_DIR=$KAFKA_CONNECT_PLUGINS_DIR/kafka-connect-mongodb

ARG OPENSEARCH_VERSION=3.0.0

# Deploy OpenSearch sink connector
RUN mkdir $KAFKA_CONNECT_OS_DIR && cd $KAFKA_CONNECT_OS_DIR &&\
        curl -sLO https://github.com/aiven/opensearch-connector-for-apache-kafka/releases/download/v$OPENSEARCH_VERSION/opensearch-connector-for-apache-kafka-$OPENSEARCH_VERSION.zip &&\
        unzip opensearch-connector-for-apache-kafka-$OPENSEARCH_VERSION.zip
