from confluent_kafka import Producer
import json

# Kafka broker address
bootstrap_servers = 'localhost:9092'

# Kafka topic to produce records to
topic = 'DEVICES'

# Kafka producer configuration
producer_config = {
    'bootstrap.servers': bootstrap_servers,
    'client.id': 'python-producer'
}

# Create a Kafka producer instance
producer = Producer(producer_config)

# JSON records to produce

# Load the JSON data from a file
with open('../data/devices_zurich.json') as json_file:
    records = json.load(json_file)

# Produce records to the Kafka topic
for record in records:
    # Convert the record to JSON string
    record_str = json.dumps(record)

    # Produce the record to the Kafka topic
    producer.produce(topic=topic, value=record_str)

    # Flush the producer buffer
    producer.flush()
