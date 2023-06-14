import requests
import json
import random
from datetime import datetime
from confluent_kafka import Producer
from math import sin, cos, sqrt, atan2, radians
import sys

# Retrieve the arguments
args = sys.argv[1:]
# Convert the string argument to a boolean
disruption_enabled = args[0].lower() == 'true'


def distance_between_coordinates(lat1, lon1, lat2, lon2):
    # Approximate radius of earth in km
    R = 6373.0

    lat1 = radians(lat1)
    lon1 = radians(lon1)
    lat2 = radians(lat2)
    lon2 = radians(lon2)

    dlon = lon2 - lon1
    dlat = lat2 - lat1

    a = sin(dlat / 2)**2 + cos(lat1) * cos(lat2) * sin(dlon / 2)**2
    c = 2 * atan2(sqrt(a), sqrt(1 - a))
    ## distance in km
    distance = R * c
    return distance


# Kafka broker address
bootstrap_servers = 'localhost:9092'

# Kafka topic to produce records to
topic = 'EVENTS'

# Kafka producer configuration
producer_config = {
    'bootstrap.servers': bootstrap_servers,
    'client.id': 'python-producer'
}

# Create a Kafka producer instance
producer = Producer(producer_config)

druid_sql_endpoint = "http://druid_system:password2@localhost:8888/druid/v2/sql/"
# Path to the JSON file
druid_query = '../druid_queries/get_devices_locations_synthetic.json'

# Load the JSON file as a dictionary
with open(druid_query, 'r') as file:
    json_data = json.load(file)
    file.close()

# Send the POST request with the JSON data
response = requests.post(druid_sql_endpoint, json=json_data)

# Check the response status code
if response.status_code == 200:
    # Convert the response content to a dictionary
    response_dict = response.json()
    devices_locations = {el["deviceId"]: {"latitude": el["latitude"], "longitude": el["longitude"]} for el in response_dict}
    all_device_ids = list(devices_locations.keys())
else:
    print(f"Error: {response.status_code} - {response.reason}")

## Wiedikon
location_with_disruption = {"latitude": 47.37, "longitude": 8.52}

for i in range(1,100_000):
    this_device_id = random.choice(all_device_ids)

    if disruption_enabled:
        distance_to_disruption = distance_between_coordinates(
            devices_locations[this_device_id]["latitude"],
            devices_locations[this_device_id]["longitude"],
            location_with_disruption["latitude"],
            location_with_disruption["longitude"]
        )
        ## High disruption within 100 meters around wiedikon
        if distance_to_disruption < 0.1:
            weights = (1, 100)
        else:
            weights = (100, 1)
    
    else:
        weights = (100, 1)

    # Get the current timestamp
    # timestamp = datetime.now()
    timestamp = datetime.utcnow()

    # Convert the timestamp to ISO-8601 format with milliseconds
    formatted_timestamp = timestamp.strftime("%Y-%m-%dT%H:%M:%S.%f")[:-3] + "Z"

    # Get the Message
    possible_messages = ["accessGranted", "accessRejected"]
    message = random.choices(possible_messages, weights=weights, k=1)[0]

    message_to_send = {
        "deviceId": this_device_id,
        "messageName": "operatingNotification",
        "payload": {
            "notificationName": message,
            "eventTimestamp": formatted_timestamp
        },
        "timestamp": formatted_timestamp
    }

    # Convert the record to JSON string
    record_str = json.dumps(message_to_send)

    # Produce the record to the Kafka topic
    producer.produce(topic=topic, value=record_str)

    # Flush the producer buffer
    producer.flush()



    