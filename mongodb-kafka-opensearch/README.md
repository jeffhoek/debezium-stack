# Debezium Stack
Docker Compose example based on the official tutorial [here](https://debezium.io/documentation/reference/stable/tutorial.html).

This stack was tested on Mac OS Sonoma on Apple M1 Max hardware. YMMV.

## Prerequisites
- [Podman Desktop](https://podman-desktop.io/): Docker Desktop is not officially supported.
- [MongoDB tools](https://www.mongodb.com/try/download/database-tools): Specifically mongosh and mongoimport if you want to easily import data from the CLI.

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
Tail the `connect` container logs in a separate terminal. Review these logs when creating connectors in the subsequent POST commands below.
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

## Kafka

### Check the Connect PlugIns
```bash
curl http://localhost:8083/connector-plugins | jq .
```
You should see e.g.
```
...
"class": "io.aiven.kafka.connect.opensearch.OpensearchSinkConnector",
...
```

### Kafka Topics
Launch bash terminal in kafka container:
```
podman compose exec -it kafka bash
```

List topics:
```
podman compose exec kafka bin/kafka-topics.sh --list --bootstrap-server=kafka:9092
```

Consume a topic:
```
podman compose exec kafka bin/kafka-console-consumer.sh --bootstrap-server=kafka:9092 --topic=mongodb.inventory.cities --from-beginning
```

## MongoDB

### Initiate the Replica Set
We will eventually extend the compose startup process to do this automatically, but for now you will need to run this command:

First, log into mongodb (enter the password when prompted):
```
mongosh -u root
```

Initiate the replica set:
```
rs.initiate()
```

### Create MongoDB Source Connector
Create the source connector.  Note, you may need to update some of these key/value pairs for your use cases. For this example we set `database.include.list` to include our expected `inventory` database.

```
curl -X POST -H "Accept:application/json" -H  "Content-Type:application/json" http://localhost:8083/connectors/ -d @mongodb-source.json
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


## Test Data
You will need to insert some JSON data into a collection in the `inventory` mongodb database. You can use `mongosh` for this, or use the steps below to download the CISA Known Exploited Vulnerabilities (KEV) dataset JSON.

> Note: If don't have `mongoimport` tool see [https://www.mongodb.com/try/download/database-tools](https://www.mongodb.com/try/download/database-tools)

### CISA KEV dataset
Download the CISA KEV dataset from [https://www.cisa.gov/sites/default/files/feeds/known_exploited_vulnerabilities.json](https://www.cisa.gov/sites/default/files/feeds/known_exploited_vulnerabilities.json).

Extract the vulnerabilites list from the JSON into JSON lines using the included script:
```
./mongodb-mongoimport-prepare.sh ~/Downloads/known_exploited_vulnerabilities.json cisa-kev > kev-mongodb-bulk.ndjson
```

Import the dataset using mongoimport (enter the password when prompted):
```
mongoimport -u root --authenticationDatabase=admin --uri=mongodb://127.0.0.1:27017 --db=inventory --collection=cisa_kev_mongo --file=./kev-mongodb-bulk.ndjson
```

Check the Kafka topics (you should see the new topic):
```
podman compose exec -it kafka bin/kafka-topics.sh --list --bootstrap-server=kafka:9092
```
```
mongodb.inventory.cisa_kev_mongo
...
```


## OpenSearch
OpenSearch Dashboard should be available at [http://localhost:5601](http://localhost:5601)

Dev tools are here: [http://localhost:5601/app/dev_tools#/console](http://localhost:5601/app/dev_tools#/console)

### Curl OpenSearch
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

### Check OpenSearch indices
```
curl  http://localhost:9200/_cat/indices
```
```
green  open .opensearch-observability N1I5edQCQU-sLO5Td1OvEg 1 0 0 0  208b  208b
green  open .kibana_1                 H8bTAGoJQDubG6fewoXFvQ 1 0 1 0 5.1kb 5.1kb
```

### Create the OpenSearch Sink Connector(s)
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
["inventory-connector", "opensearch-connector"]
```

Create another connector for cisa-kev dataset:
```
curl -X POST -H "Accept:application/json" -H  "Content-Type:application/json" http://localhost:8083/connectors/ -d @mongodb-source.json
```
You should see a reponse like:
```
{
  "name": "opensearch-connector-cisakev",
  "config": {
    "name": "opensearch-connector-cisakev",
    "connector.class": "io.aiven.kafka.connect.opensearch.OpensearchSinkConnector",
    "tasks.max": "1",
    "topics": "mongodb.inventory.cisa_kev_mongo",
    "connection.url": "http://opensearch-node1:9200",
    "type.name": "kev",
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

If the connector is working you should see a new index with ~1413 documents:
```
curl  http://localhost:9200/_cat/indices
```
```
yellow open mongodb.inventory.cisa_kev_mongo VS1A0GqjQLON_C5BqXuWWw 1 1 1413 0    1mb    1mb
...
```

### Test Elasticsearch _search API
Test basic search:
```
curl -s http://localhost:9200/mongodb.inventory.cisa_kev_mongo/_search\?q\="ios" | jq -C . | less
```

Search the cisa-kev index:
```
curl -s http://localhost:9200/mongodb.inventory.cisa_kev_mongo/_search\?q\="CVE-2020-6820" | jq -r -C '.hits.hits[0]._source'
```
```
{
  "mongo_id": "68c72253c5a97d4060f51c51",
  "cveID": "CVE-2020-6820",
  "vendorProject": "Mozilla",
  "product": "Firefox and Thunderbird",
  "vulnerabilityName": "Mozilla Firefox And Thunderbird Use-After-Free Vulnerability",
  "dateAdded": "2021-11-03",
  "shortDescription": "Mozilla Firefox and Thunderbird contain a race condition vulnerability when handling a ReadableStream under certain conditions. The race condition creates a use-after-free vulnerability, causing unspecified impacts.",
  "requiredAction": "Apply updates per vendor instructions.",
  "dueDate": "2022-05-03",
  "knownRansomwareCampaignUse": "Unknown",
  "notes": "https://nvd.nist.gov/vuln/detail/CVE-2020-6820",
  "cwes": [
    "CWE-362"
  ]
}
```


## Destroy Stack
```
podman compose down -v
```
