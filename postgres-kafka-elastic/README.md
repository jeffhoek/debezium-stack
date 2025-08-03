# Debezium Stack
Docker Compose example based on the official tutorial [here](https://debezium.io/documentation/reference/stable/tutorial.html).

This stack was tested on Mac OS Monterey on Apple M1 Max hardware.

## Prerequisites
- [Docker Desktop](https://www.docker.com/products/docker-desktop/)

## Connect Container Image Build
Build the custom Kafka Connect container image:
```
cd docker &&\
docker build --build-arg DEBEZIUM_VERSION=2.2 -t your_registry_namespace/connect-jdbc-es:2.2 .
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
bin/kafka-console-consumer.sh --bootstrap-server=kafka:9092 --topic=pg.public.customers --from-beginning
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


## Create Elasticsearch Sink Connector
Create the Elasticsearch sink connector using curl:
```
curl -X POST -H "Accept:application/json" -H  "Content-Type:application/json" http://localhost:8083/connectors/ -d @es-sink.json
```
```
{"name":"elastic-sink","config":{"connector.class":"io.confluent.connect.elasticsearch.ElasticsearchSinkConnector","tasks.max":"1","topics":"pg.public.people","connection.url":"http://elastic:9200","transforms":"unwrap,key","transforms.unwrap.type":"io.debezium.transforms.ExtractNewRecordState","transforms.unwrap.drop.tombstones":"false","transforms.key.type":"org.apache.kafka.connect.transforms.ExtractField$Key","transforms.key.field":"id","key.ignore":"false","type.name":"person","behavior.on.null.values":"delete","name":"elastic-sink"},"tasks":[],"type":"sink"}
```

Confirm the connector was created:
```
curl -H "Accept:application/json" localhost:8083/connectors/
```
```
["elastic-sink"]
```

## Create Postgres Source
```
curl -X POST -H "Accept:application/json" -H  "Content-Type:application/json" http://localhost:8083/connectors/ -d @postgres.json
```
```
{"name":"inventory-connector-postgres","config":{"connector.class":"io.debezium.connector.postgresql.PostgresConnector","database.hostname":"postgres","database.port":"5432","database.user":"postgresuser","database.password":"postgrespw","database.dbname":"inventory","table.include.list":"public.people","topic.prefix":"pg","name":"inventory-connector-postgres"},"tasks":[],"type":"source"}
```

Confirm the connector was created:
```
curl -H "Accept:application/json" localhost:8083/connectors/
```
```
["elastic-sink","inventory-connector-postgres"]
```

### PSQL CLI
Launch psql
```
docker-compose exec -it postgres psql -U postgresuser inventory
```

Create table and content:
```
CREATE TABLE people (id int GENERATED ALWAYS AS IDENTITY PRIMARY KEY, name text);
ALTER TABLE people REPLICA IDENTITY USING INDEX people_pkey;
INSERT INTO people (name) VALUES ('john'), ('jack'), ('jane');
```

Test updates:
```
update people set name='jose' where id=1;
```


## Testing
Explore the following examples to validate the Connect functionality.


### Elasticsearch
Check indices. (You should now see a `pg.public.customers` index.):
```
curl  http://localhost:9200/_cat/indices
```
```
green  open .geoip_databases L-njLsExSLaaZq_D7qe3bg 1 0 42 0 40.8mb 40.8mb
yellow open pg.public.people KdE6ti7CTlWqN-P6dVQiSQ 1 1  3   1   9.2kb   9.2kb
```

Search the people index:
```
curl -s http://localhost:9200/pg.public.people/_search
```
```
{"took":2,"timed_out":false,"_shards":{"total":1,"successful":1,"skipped":0,"failed":0},"hits":{"total":{"value":3,"relation":"eq"},"max_score":1.0,"hits":[{"_index":"pg.public.people","_type":"person","_id":"2","_score":1.0,"_source":{"id":2,"name":"jack"}},{"_index":"pg.public.people","_type":"person","_id":"3","_score":1.0,"_source":{"id":3,"name":"jane"}},{"_index":"pg.public.people","_type":"person","_id":"1","_score":1.0,"_source":{"id":1,"name":"jose"}}]}}
```


## Destroy Stack
```
docker-compose down
```
