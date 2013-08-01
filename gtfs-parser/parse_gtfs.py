import os
import argparse
import logging
import pandas as pd
from ujson import dumps as dump_json
from ipdb import set_trace

from os.path import join as joindir 

def shape_to_geojson(shape_id, shape):
    '''
    converts an individual shape listing to geojson format
    shape format from: developers.google.com/transit/gtfs/reference#shapes_fields
    ''' 
    
    return dict(type='Feature', properties=dict(shape_id=shape_id),
        geometry=dict(
            type="LineString", 
            coordinates=shape.sort('shape_pt_sequence')[
                ['shape_pt_lat', 'shape_pt_lon']].values.tolist()
        ))
    

def parse(directory):
    shapes_file = joindir(directory, 'shapes.txt')
    geojson_file = joindir(directory, 'shapes.geojson')
    topojson_file = geojson_file.replace('.geojson', '.topojson')
    set_trace()
    if os.path.isfile(shapes_file):
        shapes = pd.read_csv(shapes_file)
        geojson = dict(type="FeatureCollection", 
            features = [
                shape_to_geojson(sid, shape)
                for sid, shape in shapes.groupby('shape_id')]
            )
        with open(geojson_file, 'w+') as f:
            f.write(dump_json(geojson))
        os.system("topojson {gjson} -o {tjson} --properties".format(
            gjson=geojson_file, tjson=topojson_file))

if __name__ == '__main__':
    parser = argparse.ArgumentParser(
        description='Parse GTFS data into json and topojson')
    parser.add_argument('--directory', default='gtfs-data/BART')
    kwds = vars(parser.parse_args())
    
    parse(**kwds)
    