# Debezium Stack
Docker Compose example based on the official tutorial [here](https://debezium.io/documentation/reference/stable/tutorial.html).

This stack was tested on Mac OS Monterey on Apple M1 Max hardware.

## Prerequisites
- [Docker Desktop](https://www.docker.com/products/docker-desktop/)

## Connect Container Image Build
```
git clone https://github.com/debezium/container-images.git
cd container-images/postgres/15-alpine
```

Change first line to:
```
FROM postgis/postgis:15-3.3-alpine
```

Build:
```
docker build -t your_registry_namespace/postgis:15-master-decoderbufs .
```


## Launch Stack
```
docker-compose up -d
```
```
[+] Running 7/8
 ⠿ Network postgis-kafka-opensearch_default Created    0.0s
 ⠿ Container zookeeper Started    0.8s
 ⠿ Container opensearch-node1 Started    0.8s
 ⠿ Container opensearch-dashboards Started    0.7s
 ⠿ Container postgis-kafka-opensearch-postgres-1 Started    0.7s
 ⠴ postgres The requested image's platform (linux/amd64) does not match the detected host platform (linux/arm64/v8) and no specific platform was requested            0.0s
 ⠿ Container postgis-kafka-opensearch-kafka-1 Started    1.1s
 ⠿ Container postgis-kafka-opensearch-connect-1 Started    1.5s
 ```

## View Logs
Tail the `connect` container logs in a separate terminal. Review these logs when creating connectors in the subsequent POST commands below.
```
docker compose logs connect -f
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
docker compose exec -it kafka bash
```

List topics:
```
bin/kafka-topics.sh --list --bootstrap-server=kafka:9092
```

Consume a topic:
```
bin/kafka-console-consumer.sh --bootstrap-server=kafka:9092 --topic=pg.public.customers --from-beginning
```

## OpenSearch Dashboard
OpenSearch Dashboard should be available at [http://localhost:5601](http://localhost:5601)


## Check OpenSearch
Confirm OpenSearch is running on the default port:
```
curl  http://localhost:9200
```
```
{
  "name" : "opensearch-node1",
  "cluster_name" : "opensearch-cluster",
  "cluster_uuid" : "HCjVkMwYSFehGNrTA2CKIg",
  "version" : {
    "distribution" : "opensearch",
    "number" : "2.7.0",
    "build_type" : "tar",
    "build_hash" : "b7a6e09e492b1e965d827525f7863b366ef0e304",
    "build_date" : "2023-04-27T21:44:48.068301228Z",
    "build_snapshot" : false,
    "lucene_version" : "9.5.0",
    "minimum_wire_compatibility_version" : "7.10.0",
    "minimum_index_compatibility_version" : "7.0.0"
  },
  "tagline" : "The OpenSearch Project: https://opensearch.org/"
}
```

Check indices:
```
curl  http://localhost:9200/_cat/indices
```
```
green  open .opensearch-observability N1I5edQCQU-sLO5Td1OvEg 1 0 0 0  208b  208b
green  open .kibana_1                 H8bTAGoJQDubG6fewoXFvQ 1 0 1 0 5.1kb 5.1kb
```


## Create OpenSearch Sink Connector
Create the OpenSearch sink connector using curl:
```
curl -X POST -H "Accept:application/json" -H  "Content-Type:application/json" http://localhost:8083/connectors/ -d @opensearch-sink.json

```
```{"name":"opensearch-connector","config":{"name":"opensearch-connector","connector.class":"io.aiven.kafka.connect.opensearch.OpensearchSinkConnector","topics":"pg.public.cities","connection.url":"http://opensearch-node1:9200","transforms":"unwrap,key","transforms.unwrap.type":"io.debezium.transforms.ExtractNewRecordState","transforms.unwrap.drop.tombstones":"false","transforms.key.type":"org.apache.kafka.connect.transforms.ExtractField$Key","transforms.key.field":"id","type.name":"city","tasks.max":"1","key.ignore":"false","behavior.on.null.values":"delete"},"tasks":[],"type":"sink"}```

Confirm the connector was created:
```
curl -H "Accept:application/json" localhost:8083/connectors/
```
```
["opensearch-connector"]
```


## Create Postgres Source Connector

```
curl -X POST -H "Accept:application/json" -H  "Content-Type:application/json" http://localhost:8083/connectors/ -d @postgres.json
```
```
{
  "name": "inventory-connector-postgres",
  "config": {
    "connector.class": "io.debezium.connector.postgresql.PostgresConnector",
    "database.hostname": "postgres",
    "database.port": "5432",
    "database.user": "postgresuser",
    "database.password": "postgrespw",
    "database.dbname": "inventory",
    "table.include.list": "public.customers,public.cities,public.uscities",
    "topic.prefix": "pg",
    "name": "inventory-connector-postgres"
  },
  "tasks": [],
  "type": "source"
}
```

Confirm the connector was created:
```
curl -H "Accept:application/json" localhost:8083/connectors/
```
```
["inventory-connector-postgres","opensearch-connector"]
```

## Postgis / PSQL CLI
```
CREATE TABLE cities (id int GENERATED ALWAYS AS IDENTITY PRIMARY KEY, name text, geom geometry);
ALTER TABLE cities REPLICA IDENTITY USING INDEX cities_pkey;
INSERT INTO cities (name, geom) VALUES ('happyville', 'POINT(12.990 87.595)'), ('sadtown', 'POINT(-22.990 67.595)'), ('nowhere', 'POINT(42.990 -27.595)');
```
```
select id, name, ST_AsText(geom) from cities;
```


## Testing
Explore the following examples to validate the Connect functionality.


### OpenSearch
Check indices. (You should now see a `pg.public.cities` index.):
```
curl  http://localhost:9200/_cat/indices
```
```
green  open .opensearch-observability N1I5edQCQU-sLO5Td1OvEg 1 0 0 0  208b  208b
yellow open pg.public.cities          gGpDvB9GSl-wn5HbijpIvw 1 1 3 0 8.1kb 8.1kb
green  open .kibana_1                 H8bTAGoJQDubG6fewoXFvQ 1 0 1 0   5kb   5kb
```

Search the cities index:
```
curl -s  http://localhost:9200/pg.public.cities/_search
```

```{"took":9,"timed_out":false,"_shards":{"total":1,"successful":1,"skipped":0,"failed":0},"hits":{"total":{"value":3,"relation":"eq"},"max_score":1.0,"hits":[{"_index":"pg.public.cities","_id":"1","_score":1.0,"_source":{"id":1,"name":"happyville","geom":{"wkb":"AQEAAAB7FK5H4fopQK5H4XoU5lVA","srid":null}}},{"_index":"pg.public.cities","_id":"3","_score":1.0,"_source":{"id":3,"name":"nowhere","geom":{"wkb":"AQEAAAAfhetRuH5FQLgehetRmDvA","srid":null}}},{"_index":"pg.public.cities","_id":"2","_score":1.0,"_source":{"id":2,"name":"sadtown","geom":{"wkb":"AQEAAAA9CtejcP02wK5H4XoU5lBA","srid":null}}}]}}```


## Destroy Stack
```
docker compose down
```
