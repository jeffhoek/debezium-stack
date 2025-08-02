# Debezium Stack
Docker Compose example based on the official tutorial [here](https://debezium.io/documentation/reference/stable/tutorial.html).

This stack was tested on Mac OS Monterey on Apple M1 Max hardware.

## Prerequisites
- [Docker Desktop](https://www.docker.com/products/docker-desktop/)

## Connect Container Image Build
Build the custom Kafka Connect container image:
```
cd docker &&\
docker build --build-arg DEBEZIUM_VERSION=2.7 -t your_registry_namespace/connect-jdbc-es:2.7 --load .
```

## Launch Stack
```
docker-compose up -d
```
```
[+] Running 6/6
 ⠿ Network debezium_default Created 0.0s
 ⠿ Container debezium-mysql-1 Started 0.8s
 ⠿ Container debezium-elastic-1 Started 0.7s
 ⠿ Container zookeeper Started 0.8s
 ⠿ Container debezium-kafka-1 0.9s
 ⠿ Container debezium-connect-1  Started
 ```

## View Logs
Tail the `connect` container logs in a separate terminal. Review these logs when creating connectors in the subsequent POST commands below.
```
docker-compose logs connect -f
```
```
debezium-connect-1  | Using BOOTSTRAP_SERVERS=kafka:9092
debezium-connect-1  | Plugins are loaded from /kafka/connect
debezium-connect-1  | Using the following environment variables:
debezium-connect-1  |       GROUP_ID=1
...
```

## Kafka Topics
Launch bash terminal in kafka container:
```
docker-compose exec -it kafka bash
```

List topics:
```
bin/kafka-topics.sh --list --bootstrap-server=kafka:9092
```

Consume a topic:
```
bin/kafka-console-consumer.sh --bootstrap-server=kafka:9092 --topic=customers --from-beginning
```


## Kibana
Kibana should be available at [http://localhost:5601](http://localhost:5601)


## Check Elasticsearch
Confirm Elasticsearch is running on the default port:
```
curl  http://localhost:9200
```
```
{
  "name" : "d5232e41f9af",
  "cluster_name" : "docker-cluster",
  "cluster_uuid" : "rGoxO16KQN2NkTkNu7h1tQ",
  "version" : {
    "number" : "7.17.10",
    "build_flavor" : "default",
    "build_type" : "docker",
    "build_hash" : "fecd68e3150eda0c307ab9a9d7557f5d5fd71349",
    "build_date" : "2023-04-23T05:33:18.138275597Z",
    "build_snapshot" : false,
    "lucene_version" : "8.11.1",
    "minimum_wire_compatibility_version" : "6.8.0",
    "minimum_index_compatibility_version" : "6.0.0-beta1"
  },
  "tagline" : "You Know, for Search"
}
```
Check indices:
```
curl  http://localhost:9200/_cat/indices
```
```
green open .geoip_databases L-njLsExSLaaZq_D7qe3bg 1 0 42 0 40.8mb 40.8mb
```

## Launch MySQL CLI
Launch the MySQL CLI:
```
docker-compose exec -it mysql mysql -uroot -pdebezium inventory
```
```
...
Type 'help;' or '\h' for help. Type '\c' to clear the current input statement.

mysql>\q
Bye
```

## Create Elasticsearch Sink Connector
Create the Elasticsearch sink connector using curl:
```
curl -i -X POST -H "Accept:application/json" -H  "Content-Type:application/json" http://localhost:8083/connectors/ -d @es-sink.json
```
```
HTTP/1.1 201 Created
Date: Wed, 31 May 2023 01:30:26 GMT
Location: http://localhost:8083/connectors/elastic-sink
Content-Type: application/json
Content-Length: 565
Server: Jetty(9.4.48.v20220622)

{"name":"elastic-sink","config":{"connector.class":"io.confluent.connect.elasticsearch.ElasticsearchSinkConnector","tasks.max":"1","topics":"customers","connection.url":"http://elastic:9200","transforms":"unwrap,key","transforms.unwrap.type":"io.debezium.transforms.ExtractNewRecordState","transforms.unwrap.drop.tombstones":"false","transforms.key.type":"org.apache.kafka.connect.transforms.ExtractField$Key","transforms.key.field":"id","key.ignore":"false","type.name":"customer","behavior.on.null.values":"delete","name":"elastic-sink"},"tasks":[],"type":"sink"}
```

Confirm the connector was created:
```
curl -H "Accept:application/json" localhost:8083/connectors/
```
```
["elastic-sink"]
```

## Create MySQL Source
Create the MySQL source connector:
```
curl -i -X POST -H "Accept:application/json" -H  "Content-Type:application/json" http://localhost:8083/connectors/ -d @source.json
```
```

HTTP/1.1 201 Created
Date: Wed, 31 May 2023 01:33:29 GMT
Location: http://localhost:8083/connectors/inventory-connector
Content-Type: application/json
Content-Length: 687
Server: Jetty(9.4.48.v20220622)

{"name":"inventory-connector","config":{"connector.class":"io.debezium.connector.mysql.MySqlConnector","tasks.max":"1","topic.prefix":"dbserver1","database.hostname":"mysql","database.port":"3306","database.user":"debezium","database.password":"dbz","database.server.id":"184054","database.include.list":"inventory","schema.history.internal.kafka.bootstrap.servers":"kafka:9092","schema.history.internal.kafka.topic":"schema-changes.inventory","transforms":"route","transforms.route.type":"org.apache.kafka.connect.transforms.RegexRouter","transforms.route.regex":"([^.]+)\\.([^.]+)\\.([^.]+)","transforms.route.replacement":"$3","name":"inventory-connector"},"tasks":[],"type":"source"}
```
Confirm the connector was created:
```
curl -H "Accept:application/json" localhost:8083/connectors/
```
```
["elastic-sink","inventory-connector"]
```


## Testing
Explore the following examples to validate the Connect functionality.


### Elasticsearch
Check indices. (You should now see a `customers` index.):
```
curl  http://localhost:9200/_cat/indices
```
```
green  open .geoip_databases L-njLsExSLaaZq_D7qe3bg 1 0 42 0 40.8mb 40.8mb
yellow open customers        awIg9xdDRpSqGa0hIYWVuQ 1 1  0 0   227b   227b
```

Search the customers index:
```
curl -s http://localhost:9200/customers/_search | jq .
```
```
{
  "took": 6,
  "timed_out": false,
  "_shards": {
    "total": 1,
    "successful": 1,
    "skipped": 0,
    "failed": 0
  },
  "hits": {
    "total": {
      "value": 4,
      "relation": "eq"
    },
    "max_score": 1,
    "hits": [
      {
        "_index": "customers",
        "_type": "customer",
        "_id": "1002",
        "_score": 1,
        "_source": {
          "id": 1002,
...
```
Get a specific customer:
```
curl -s http://localhost:9200/customers/customer/1004 | jq .
```
```
{
  "_index": "customers",
  "_type": "customer",
  "_id": "1004",
  "_version": 3,
  "_seq_no": 3,
  "_primary_term": 1,
  "found": true,
  "_source": {
    "id": 1004,
    "first_name": "Anne",
    "last_name": "Kretchmar",
    "email": "annek@noanswer.org"
  }
}
```

### MySQL CLI
```
use inventory;
```
```
show tables;
```
```
SELECT * FROM customers;
```
```
UPDATE customers SET first_name='Anne Marie' WHERE id=1004;
```
```
DELETE FROM addresses WHERE customer_id=1004;
DELETE FROM customers WHERE id=1004;
```
```
INSERT INTO customers VALUES (default, "Sarah", "Thompson", "kitt@acme.com");
```

### Elasticsearch
Confirm MySQL CLI update:
```
curl -s http://localhost:9200/customers/customer/1004 | jq .
```
```
...
    "first_name": "Anne Marie",
...
```

## Destroy Stack
```
docker-compose down
```
