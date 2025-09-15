# Datasets

## CISA KEV dataset
Download the CISA KEV dataset from [here](https://www.cisa.gov/known-exploited-vulnerabilities-catalog). Or use curl:
```
curl -s https://www.cisa.gov/sites/default/files/feeds/known_exploited_vulnerabilities.json -o known_exploited_vulnerabilities.json
```

Extract the individual vulnerabilites into JSON lines using the included Bash script:
```
./cisa-kev-to-jsonl.sh ./known_exploited_vulnerabilities.json > cisa-kev.jsonl
```

Import the dataset using mongoimport (enter the password when prompted):
```
mongoimport -u root --authenticationDatabase=admin --uri=mongodb://127.0.0.1:27017 --db=inventory --collection=cisa_kev_mongo --file=./cisa-kev.jsonl
```

Check the Kafka topics (you should see the new topic):
```
podman compose exec -it kafka bin/kafka-topics.sh --list --bootstrap-server=kafka:9092
```
```
mongodb.inventory.cisa_kev_mongo
...
```

### Create connection

```
curl -s -X POST -H "Accept:application/json" -H  "Content-Type:application/json" http://localhost:8083/connectors/ -d @opensearch-sink-cisakev.json | jq .
```
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

### CISA KEV queries

```
curl -s http://localhost:9200/mongodb.inventory.cisa_kev_mongo/_search\?q\="ios" | jq -C . | less
```

Search for specific CVE. Note that even though multiple hits are returned the first hit is the correct match.
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
