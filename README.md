# Debezium Stack
Docker Compose example based on the official tutorial [here](https://debezium.io/documentation/reference/stable/tutorial.html).

## Connect Container Image Build
```
cd debezium-jdbc-es &&\
docker build --build-arg DEBEZIUM_VERSION=2.2 -t your_registry_namespace/connect-jdbc-es:2.2 .
```

## Docker Compose UP
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
```
docker compose logs connect
```
```
debezium-connect-1  | Using BOOTSTRAP_SERVERS=kafka:9092
debezium-connect-1  | Plugins are loaded from /kafka/connect
debezium-connect-1  | Using the following environment variables:
debezium-connect-1  |       GROUP_ID=1
...
```

## Check Elasticsearch
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

## Lauch MySQL CLI
```
docker compose exec -it mysql mysql -uroot -pdebezium inventory
```
```
...
Type 'help;' or '\h' for help. Type '\c' to clear the current input statement.

mysql>\q
Bye
```

## Create Elasticsearch Sink Connector
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

Confirm:
```
curl -H "Accept:application/json" localhost:8083/connectors/
```
```
["elastic-sink"]
```

## Create MySQL Source
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
Confirm:
```
curl -H "Accept:application/json" localhost:8083/connectors/
```
```
["elastic-sink","inventory-connector"]
```

## Elasticsearch Testing
Check indices:
```
curl  http://localhost:9200/_cat/indices
```
```
green  open .geoip_databases L-njLsExSLaaZq_D7qe3bg 1 0 42 0 40.8mb 40.8mb
yellow open customers        awIg9xdDRpSqGa0hIYWVuQ 1 1  0 0   227b   227b
```

Search customers:
```
curl -s http://localhost:9200/customers/_search
```
```
{"took":4,"timed_out":false,"_shards":{"total":1,"successful":1,"skipped":0,"failed":0},"hits":{"total":{"value":4,"relation":"eq"},"max_score":1.0,"hits":[{"_index":"customers","_type":"customer","_id":"1002","_score":1.0,"_source":{"id":1002,"first_name":"George","last_name":"Bailey","email":"gbailey@foobar.com"}},{"_index":"customers","_type":"customer","_id":"1001","_score":1.0,"_source":{"id":1001,"first_name":"Sally","last_name":"Thomas","email":"sally.thomas@acme.com"}},{"_index":"customers","_type":"customer","_id":"1003","_score":1.0,"_source":{"id":1003,"first_name":"Edward","last_name":"Walker","email":"ed@walker.com"}},{"_index":"customers","_type":"customer","_id":"1004","_score":1.0,"_source":{"id":1004,"first_name":"Anne","last_name":"Kretchmar","email":"annek@noanswer.org"}}]}}
```
Get a specific customer:
```
curl -s http://localhost:9200/customers/customer/1004
```
```
{"_index":"customers","_type":"customer","_id":"1004","_version":3,"_seq_no":3,"_primary_term":1,"found":true,"_source":{"id":1004,"first_name":"Anne","last_name":"Kretchmar","email":"annek@noanswer.org"}}
```

## MySQL Testing
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
