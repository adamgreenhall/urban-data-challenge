"""
adapted from http://github.com/sgillies/topojson)
"""
import numpy as np
import math

def lat_long(coordinates, scale, translate):
    """convert the topojson encoded coordinates into (lat, long)"""
    return dict(
        latitude=coordinates[1] * scale[1] + translate[1],
        longitude=coordinates[0] * scale[0] + translate[0])


def properties(json, obj_name):
    '''
    convert topojson gemometries to a dataframe of the properties
    and coordinates (converted to lat, long)
    '''
    properties = []
    for obj in json['objects'][obj_name]['geometries']:
        obj_prop = obj['properties'].copy()
        obj_prop.update(lat_long(obj['coordinates'], **json['transform']))
        properties.append(obj_prop)
    return properties


def get_linear_dist(df):
    '''convert lat long to a linear distance travelled since start'''
    LL = ['latitude', 'longitude']
    latlng = df.reset_index()[LL].fillna(0)
    latlng['distance'] = 0.0
    for i, coords in latlng.iterrows():
        if i == 0: continue
        latlng.ix[i, 'distance'] = haversine_distance(
            latlng.ix[i - 1][LL].values,
            coords[LL].values)
    return latlng.distance.cumsum().values


def haversine_distance(origin, destination):
    # Haversine formula for great circle distance
    # platoscave.net/blog/2009/oct/5/calculate-distance-latitude-longitude-python/
    lat1, lon1 = origin
    lat2, lon2 = destination
    radius = 6371 # km

    dlat = math.radians(lat2-lat1)
    dlon = math.radians(lon2-lon1)
    a = math.sin(dlat/2) * math.sin(dlat/2) + math.cos(math.radians(lat1)) \
        * math.cos(math.radians(lat2)) * math.sin(dlon/2) * math.sin(dlon/2)
    return 2 * radius * math.atan2(math.sqrt(a), math.sqrt(1-a))