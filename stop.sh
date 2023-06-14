#!/bin/bash

docker-compose -f ./superset_setup/docker-compose-non-dev.yml down
docker-compose -f ./druid_setup/docker-compose.yaml down
# Restore the original Docker Compose file
mv druid_setup/docker-compose.yaml.bak druid_setup/docker-compose.yaml
docker-compose down

sleep 5

docker ps -a