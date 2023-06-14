# !/bin/bash


## Create folder for minio
directory="./miniodata/state"
if [ ! -d "$directory" ]; then
    mkdir -p "$directory"
    echo "Directory created: $directory"
else
    echo "Directory already exists: $directory"
fi

## Start all services
echo "Will start Kafka, Flink and Minio..."
docker-compose up -d
echo ""

sleep 10

echo "Will start Druid and Superset..."

# Get the name of the current directory
default_network="$(basename "$PWD")_default"

# Prompt the user for input
read -p "Enter the name of the Docker network to use [enter nothing and press Enter to use the default value $default_network]: " docker_network

# Use the default network name if the user input is empty
docker_network=${docker_network:-$default_network}

# Create a temporary file
temp_file=$(mktemp)

# Replace the placeholder in the Docker Compose file and write to the temporary file
sed "s/YOUR-DOCKER-NETWORK/$docker_network/g" druid_setup/docker-compose.yaml > "$temp_file"

# Copy the original Docker Compose file
cp druid_setup/docker-compose.yaml druid_setup/docker-compose.yaml.bak

# Replace the original file with the temporary file
mv "$temp_file" druid_setup/docker-compose.yaml
docker-compose -f ./druid_setup/docker-compose.yaml up -d

# Prompt the user for the API key
read -p "Enter your API key for Mapbox: " api_key

# Create a temporary file
temp_file=$(mktemp)

# Replace the MAPBOX_API_KEY value in the environment file and write to the temporary file
sed "s/MAPBOX_API_KEY='.*'/MAPBOX_API_KEY='$api_key'/" superset_setup/docker/.env-non-dev > "$temp_file"

# Copy the original Docker Compose file
cp superset_setup/docker/.env-non-dev superset_setup/docker/.env-non-dev.bak

# Replace the original environment file with the temporary file
mv "$temp_file" superset_setup/docker/.env-non-dev

docker-compose -f ./superset_setup/docker-compose-non-dev.yml up -d
mv superset_setup/docker/.env-non-dev.bak superset_setup/docker/.env-non-dev
echo ""

docker ps -a
echo ""

sleep 15

## Open browser windows
url="http://localhost:18081"
# xdg-open "$url"
nohup xdg-open "$url" > /dev/null 2>&1 &
sleep 10
url="http://localhost:8088"
# xdg-open "$url"
nohup xdg-open "$url" > /dev/null 2>&1 &
sleep 10
url="http://localhost:8888"
# xdg-open "$url"
nohup xdg-open "$url" > /dev/null 2>&1 &
sleep 10
url="http://localhost:9021"
# xdg-open "$url"
nohup xdg-open "$url" > /dev/null 2>&1 &
sleep 10



# Pause execution until everything works
echo "Next step is to clean and reset Druid. Press Enter when ready..."
read -r

echo "Will post all ingestions tasks..."
curl -X POST -H "Content-Type: application/json" -d @druid_specs/devices_ingestion.json http://druid_system:password2@localhost:8888/druid/indexer/v1/supervisor
sleep 1
curl -X POST -H "Content-Type: application/json" -d @druid_specs/events_geo_ingestion.json http://druid_system:password2@localhost:8888/druid/indexer/v1/supervisor
sleep 1
curl -X POST -H "Content-Type: application/json" -d @druid_specs/alerts_ingestion.json http://druid_system:password2@localhost:8888/druid/indexer/v1/supervisor
sleep 1
echo ""

echo "Will reset all ingestions task..."
reset_url="http://druid_system:password2@localhost:8888/druid/indexer/v1/supervisor/DEVICES/reset"
curl -X 'POST' $reset_url
sleep 1
reset_url="http://druid_system:password2@localhost:8888/druid/indexer/v1/supervisor/ALERTS/reset"
curl -X 'POST' $reset_url
sleep 1
reset_url="http://druid_system:password2@localhost:8888/druid/indexer/v1/supervisor/EVENTS_GEO/reset"
curl -X 'POST' $reset_url
sleep 1
echo ""

echo "Will disable all segments..."
reset_url="http://druid_system:password2@localhost:8888/druid/coordinator/v1/datasources/DEVICES"
curl -X 'DELETE' $reset_url
sleep 1
reset_url="http://druid_system:password2@localhost:8888/druid/coordinator/v1/datasources/ALERTS"
curl -X 'DELETE' $reset_url
sleep 1
reset_url="http://druid_system:password2@localhost:8888/druid/coordinator/v1/datasources/EVENTS_GEO"
curl -X 'DELETE' $reset_url
sleep 1
echo ""

echo "Will delete all segments..."
current_date=$(date +%F)
delete_url="http://druid_system:password2@localhost:8888/druid/coordinator/v1/datasources/DEVICES?kill=true&interval=1000-01-01/$current_date"
curl -X 'DELETE' $delete_url
sleep 1
delete_url="http://druid_system:password2@localhost:8888/druid/coordinator/v1/datasources/ALERTS?kill=true&interval=1000-01-01/$current_date"
curl -X 'DELETE' $delete_url
sleep 1
delete_url="http://druid_system:password2@localhost:8888/druid/coordinator/v1/datasources/EVENTS_GEO?kill=true&interval=1000-01-01/$current_date"
curl -X 'DELETE' $delete_url
sleep 1


# Pause execution until everything works
echo "Next step is to produce the devices data to Kafka. Start the producers yourself and press Enter when ready..."
read -r

# Pause execution until everything works
echo "Next step is to Start the Flink jobs. Press Enter when ready..."
read -r

docker exec sql-client sql-client.sh -f synthetic-join.sql
sleep 5
docker exec sql-client sql-client.sh -f alerts.sql
sleep 5