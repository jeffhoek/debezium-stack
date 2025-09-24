# Debezium _Change Data Capture_ Stacks

Docker (Podman) Compose examples based on the official tutorial [here](https://debezium.io/documentation/reference/stable/tutorial.html).

These stacks have been developed and tested under Mac OS Sonoma running on Apple M1 Max hardware.


## Prerequisites

- [Podman Desktop](https://podman-desktop.io/)

OR
- [Docker Desktop](https://www.docker.com/products/docker-desktop/)

> Note: recent testing/stabilization has been under Podman Desktop. YMMV.

## Stacks

- [mongodb-kafka-opensearch](./mongodb-kafka-opensearch/)
- [mysql-kafka-elastic](./mysql-kafka-elastic/)
- [postgres-kafka-elastic](./postgres-kafka-elastic/)
- [postgis-kafka-opensearch](./postgis-kafka-opensearch/)

## Datasets
See this [README](./data/README.md)
