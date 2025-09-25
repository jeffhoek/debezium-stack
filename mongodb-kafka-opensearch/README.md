# Debezium Stack
This "change data capture" stack produces data from MongoDB into a Kafka topic, and then consumes into OpenSearch.

This Docker Compose example is based on the official tutorial [here](https://debezium.io/documentation/reference/stable/tutorial.html).

This stack was tested on Mac OS Sonoma on Apple M1 Max hardware. Some additional Java options may be required on newer (M4) silicon. The goal is to eventually support Mac and Linux.

## Prerequisites
- [Podman Desktop](https://podman-desktop.io/): Docker Desktop might also work.


## Launch Stack
```
podman compose up -d --build
```
```
[+] Running 7/7
 ✔ Network mongodb-kafka-opensearch_default Created     0.0s
 ✔ Container mongodb-kafka-opensearch-mongodb-1  Started      0.2s
 ✔ Container opensearch-dashboards               Started      0.3s
 ✔ Container mongodb-kafka-opensearch-connect-1  Started      0.4s
 ✔ Container opensearch-node1                    Started      0.2s
 ✔ Container zookeeper                           Started      0.4s
 ✔ Container mongodb-kafka-opensearch-kafka-1    Started
```

## View Logs
Use `podman compose logs <service_name>` to view logs from `<service_name>`.  You may want to follow the `connect` service logs (user control-C to exit):
```
podman compose logs connect -f
```
```
debezium-connect-1  | Using BOOTSTRAP_SERVERS=kafka:9092
debezium-connect-1  | Plugins are loaded from /kafka/connect
debezium-connect-1  | Using the following environment variables:
debezium-connect-1  |       GROUP_ID=1
...
```


## Check the Kafka Connect PlugIns
```bash
curl http://localhost:8083/connector-plugins | jq -c '.[]'
```
You should see the MongoDB source and Opensearch sink:
```
{"class":"io.aiven.kafka.connect.opensearch.OpensearchSinkConnector","type":"sink","version":"3.0.0"}
{"class":"io.debezium.connector.mongodb.MongoDbConnector","type":"source","version":"3.2.2.Final"}
```

## MongoDB

### Initiate the Replica Set
Until this gets automated you will need to _manually_ initialize (initiate) the replica set.

First, log in to MongoDB using Mongo Shell (`mongosh`). Enter the password when prompted:
```
podman compose exec -it mongodb mongosh -u root
```

Initiate the replica set:
```
rs.initiate()
```

### Test Data
We will also create some test data...

Switch to the `inventory` database:
```
use inventory
```

Create a test document in the cities collection:
```
db.cities.insertOne({city:"Charleston", state:"SC", zip:"29401"})
```
Feel free to insert additional cities for testing search and change data capture.

```
exit
```

### Create the MongoDB Source Connector
Create the source connector.  Note, review the key/value pairs in [mongodb-source.json](./mongodb-source.json). You may want to update values, for example, if you have a different database name, etc. For this example we set `database.include.list` to include our `inventory` database.

```
curl -s -X POST -H "Accept:application/json" -H  "Content-Type:application/json" http://localhost:8083/connectors/ -d @mongodb-source.json | jq .
```

Expected response:
```
{
  "name": "inventory-connector",
  "config": {
    "connector.class": "io.debezium.connector.mongodb.MongoDbConnector",
    "transforms": "unwrap",
    "transforms.unwrap.type": "io.debezium.connector.mongodb.transforms.ExtractNewDocumentState",
    "mongodb.connection.string": "mongodb://mongodb:27017/?replicaSet=rs0",
    "topic.prefix": "mongodb",
    "mongodb.user": "root",
    "mongodb.password": "example",
    "database.include.list": "inventory",
    "name": "inventory-connector"
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
["inventory-connector"]
```

## Kafka Topics
List topics:
```
podman compose exec kafka bin/kafka-topics.sh --list --bootstrap-server=kafka:9092
```

You should see:
```
mongodb.inventory.cities
```

Consume a topic:
```
podman compose exec kafka bin/kafka-console-consumer.sh --bootstrap-server=kafka:9092 --topic=mongodb.inventory.cities --from-beginning
```
```
{"schema":{"type":"struct","fields":[{"type":"string","optional":true,"field":"_id"},{"type":"string","optional":true,"field":"city"},{"type":"string","optional":true,"field":"state"},{"type":"string","optional":true,"field":"zip"}],"optional":false,"name":"mongodb.inventory.cities"},"payload":{"_id":"68c769803f6e28aa934392b1","city":"Charleston","state":"SC","zip":"29401"}}
```


## OpenSearch
OpenSearch Dashboard should be available at [http://localhost:5601](http://localhost:5601)

Dev tools are here: [http://localhost:5601/app/dev_tools#/console](http://localhost:5601/app/dev_tools#/console)

### OpenSearch Healthcheck
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

### Get OpenSearch indices
```
curl -X GET  http://localhost:9200/_cat/indices
```
You may see some default indexes:
```
green  open .opensearch-observability N1I5edQCQU-sLO5Td1OvEg 1 0 0 0  208b  208b
green  open .kibana_1                 H8bTAGoJQDubG6fewoXFvQ 1 0 1 0 5.1kb 5.1kb
```

### Create the OpenSearch Sink Connector

Create sink connector:
```
curl -s -X POST -H "Accept:application/json" -H  "Content-Type:application/json" http://localhost:8083/connectors/ -d @opensearch-sink.json | jq .
```
You should see a reponse like:
```
{
  "name": "opensearch-connector",
  "config": {
    "name": "opensearch-connector",
    "connector.class": "io.aiven.kafka.connect.opensearch.OpensearchSinkConnector",
    "tasks.max": "1",
    "topics": "mongodb.inventory.cities",
    "connection.url": "http://opensearch-node1:9200",
    "type.name": "city",
    "behavior.on.null.values": "delete",
    "key.ignore": "true",
    "transforms": "RenameId",
    "transforms.RenameId.type": "org.apache.kafka.connect.transforms.ReplaceField$Value",
    "transforms.RenameId.renames": "_id:mongo_id"
  },
  "tasks": [],
  "type": "sink"
}
```

Confirm the connector was created:
```
curl -s -X GET -H "Accept:application/json" localhost:8083/connectors/
```
```
["opensearch-connector","inventory-connector"]
```

If the sink connector is working you should see a new OpenSearch index with some hits:
```
curl  http://localhost:9200/_cat/indices
```
```
yellow open mongodb.inventory.cities         TqXXvjaZRp6GYufbTxX31w 1 1    1  0   6.1kb   6.1kb
```


### Test OpenSearch _search API
Test basic search:
```
curl -s http://localhost:9200/mongodb.inventory.cities/_search | jq .
```
```
{
  "took": 2,
  "timed_out": false,
  "_shards": {
    "total": 1,
    "successful": 1,
    "skipped": 0,
    "failed": 0
  },
  "hits": {
    "total": {
      "value": 1,
      "relation": "eq"
    },
    "max_score": 1,
    "hits": [
      {
        "_index": "mongodb.inventory.cities",
        "_id": "mongodb.inventory.cities+0+0",
        "_score": 1,
        "_source": {
          "mongo_id": "68c769803f6e28aa934392b1",
          "city": "Charleston",
          "state": "SC",
          "zip": "29401"
        }
      }
    ]
  }
}
```


## Destroy Stack
```
podman compose down -v
```
