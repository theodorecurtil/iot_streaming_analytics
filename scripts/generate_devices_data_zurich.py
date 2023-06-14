import csv
import json
import uuid

csv_filename = "../data/coordinates_zurich.csv"
json_filename = "../data/devices_zurich.json"

json_data = []

# Read the CSV file and create JSON data
with open(csv_filename, 'r') as file:
    csv_reader = csv.reader(file)
    next(csv_reader)  # Skip header row if present
    for row in csv_reader:
        location = row[0]
        data = {
            "deviceId": str(uuid.uuid4()),
            "payload": {
                "location": {
                    "countryCode": "CH",
                    "region": "Zurich",
                    "city": "Zürich",
                    "loc": location,
                    "timezone": "Europe/Zurich"
                }
            }
        }
        json_data.append(data)

# Write the JSON data to a file
with open(json_filename, 'w') as file:
    json.dump(json_data, file, indent=4, ensure_ascii=False)