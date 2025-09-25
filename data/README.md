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

#### Terms Aggregations

Using Opensearch Dashboards [Dev Tools](http://localhost:5601/app/dev_tools#/console):
```
GET mongodb.inventory.cisa_kev_mongo/_search
{
  "size": 0,
  "aggs": {
    "my_topk": {
      "terms": {
        "field": "vendorProject.keyword",
        "size": 10
      }
    }
  }
}
```

Using Curl:
```
curl -s -XGET "http://localhost:9200/mongodb.inventory.cisa_kev_mongo/_search" -H 'Content-Type: application/json' -d'
{
  "size": 0,
  "aggs": {
    "my_topk": {
      "terms": {
        "field": "vendorProject.keyword",
        "size": 5
      }
    }
  }
}' | jq -c '.aggregations.my_topk.buckets[]'
```
```
{"key":"Microsoft","doc_count":340}
{"key":"Apple","doc_count":84}
{"key":"Cisco","doc_count":78}
{"key":"Adobe","doc_count":74}
{"key":"Google","doc_count":64}
```

Nested aggregations:
```
curl -s -XGET "http://localhost:9200/mongodb.inventory.cisa_kev_mongo/_search" -H 'Content-Type: application/json' -d'
{
  "size": 0,
  "aggs": {
    "my_topk": {
      "terms": {
        "field": "vendorProject.keyword",
        "size": 5
      },
      "aggs": {
        "top_products": {
          "terms": {
            "field": "product.keyword",
            "size": 5
          }
        }
      }
    }
  }
}'
```

This jq expression will parse a short summary of the aggregation:
```
| jq -C '.aggregations.my_topk.buckets[] | {vendor:.key, docs:.doc_count, products:.top_products.buckets}'
```
```
{
  "vendor": "Microsoft",
  "docs": 340,
  "products": [
    {
      "key": "Windows",
      "doc_count": 150
    },
    {
      "key": "Internet Explorer",
      "doc_count": 33
    },
    {
      "key": "Office",
      "doc_count": 25
    },
    {
      "key": "Win32k",
      "doc_count": 25
    },
    {
      "key": "Exchange Server",
      "doc_count": 16
    }
  ]
}
{
  "vendor": "Apple",
  "docs": 84,
  "products": [
    {
      "key": "Multiple Products",
      "doc_count": 45
    },
    {
      "key": "iOS, iPadOS, and macOS",
      "doc_count": 11
    },
    {
      "key": "iOS",
      "doc_count": 8
    },
    {
      "key": "macOS",
      "doc_count": 5
    },
    {
      "key": "iOS and iPadOS",
      "doc_count": 4
    }
  ]
}
{
  "vendor": "Cisco",
  "docs": 78,
  "products": [
    {
      "key": "IOS and IOS XE Software",
      "doc_count": 14
    },
    {
      "key": "Adaptive Security Appliance (ASA) and Firepower Threat Defense (FTD)",
      "doc_count": 6
    },
    {
      "key": "IOS XR",
      "doc_count": 6
    },
    {
      "key": "IOS software",
      "doc_count": 6
    },
    {
      "key": "Small Business RV160, RV260, RV340, and RV345 Series Routers",
      "doc_count": 5
    }
  ]
}
{
  "vendor": "Adobe",
  "docs": 74,
  "products": [
    {
      "key": "Flash Player",
      "doc_count": 33
    },
    {
      "key": "ColdFusion",
      "doc_count": 15
    },
    {
      "key": "Acrobat and Reader",
      "doc_count": 13
    },
    {
      "key": "Reader and Acrobat",
      "doc_count": 6
    },
    {
      "key": "Commerce and Magento Open Source",
      "doc_count": 2
    }
  ]
}
{
  "vendor": "Google",
  "docs": 64,
  "products": [
    {
      "key": "Chromium V8",
      "doc_count": 35
    },
    {
      "key": "Chromium",
      "doc_count": 4
    },
    {
      "key": "Chromium Blink",
      "doc_count": 2
    },
    {
      "key": "Chromium Intents",
      "doc_count": 2
    },
    {
      "key": "Chromium Mojo",
      "doc_count": 2
    }
  ]
}
```
