"""
adapted from http://github.com/sgillies/topojson)
"""
import numpy as np

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


def get_linear_dist(latlng):
    '''convert lat long to a linear distance''' 
    # should probably do this properly, in km:
    # http://www.platoscave.net/blog/2009/oct/5/calculate-distance-latitude-longitude-python/
    return (latlng[['latitude', 'longitude']].diff() ** 2).sum(axis=1).apply(np.sqrt).fillna(0).cumsum()    
