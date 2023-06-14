import osmnx as ox
import geopandas as gpd
import matplotlib.pyplot as plt
from shapely.geometry import Point
import random
import csv
import math

EARTH_RADIUS = 6371000  # Earth's radius in meters

def generate_random_point(center, radius):
    while True:
        # Generate random coordinates within a square bounding box
        delta_x = random.uniform(-radius, radius)
        delta_y = random.uniform(-radius, radius)

        # Calculate the distance from the center point
        distance = math.sqrt(delta_x**2 + delta_y**2)

        # Check if the point falls within the desired radius
        if distance <= radius:
            # Calculate the coordinates of the random point
            new_lat = center[0] + (delta_y / (EARTH_RADIUS * math.pi / 180))
            new_lon = center[1] + (delta_x / (EARTH_RADIUS * math.cos(math.radians(center[0])) * math.pi / 180))
            return new_lat, new_lon


# Retrieve the polygon of Zurich
city = "Zurich, Switzerland"
gdf = ox.geocode_to_gdf(city)
polygon = gdf['geometry'].iloc[0]

# Retrieve land cover data for the area
land_cover = ox.geometries_from_polygon(polygon, tags={'landuse': ['commercial', 'industrial', 'residential']})

# Filter land cover data to only include land areas
land_areas = land_cover[land_cover['geometry'].is_valid]

center_point = (47.37, 8.53)
# Define the radius in meters
radius_meters = 2000

# Generate random points within the land areas
num_points = 1000
sampled_points = []
while len(sampled_points) < num_points:
    random_point_y, random_point_x = generate_random_point(center_point, radius_meters)
    random_point = Point(random_point_x, random_point_y)
    # sampled_points.append(random_point)
    if any(land_area.contains(random_point) for land_area in land_areas.geometry) and polygon.contains(random_point):
        print("addingPoint")
        sampled_points.append(random_point)
    else:
        print("not adding")

points_to_save = [f"{el.y},{el.x}" for el in sampled_points]
filename = "../data/coordinates_zurich.csv"

# Write the list to a CSV file
with open(filename, 'w', newline='') as file:
    writer = csv.writer(file)
    writer.writerow(["coordinates"])  # Write the header
    for item in points_to_save:
        writer.writerow([item])



