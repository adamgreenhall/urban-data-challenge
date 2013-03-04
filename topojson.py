"""
adapted from http://github.com/sgillies/topojson)
"""

def lat_long(coordinates, scale, translate):
    """convert the topojson encoded coordinates into (lat, long)"""
    return dict(
        latitude=coordinates[1] * scale[1] + translate[1],
        longitude=coordinates[0] * scale[0] + translate[0])


def properties(geometries, transform):
    '''
    convert topojson gemometries to a dataframe of the properties
    and coordinates (converted to lat, long)
    '''
    properties = []
    for obj in geometries:
        obj_prop = obj['properties'].copy()
        obj_prop.update(lat_long(obj['coordinates'], **transform))
        properties.append(obj_prop)
    return properties