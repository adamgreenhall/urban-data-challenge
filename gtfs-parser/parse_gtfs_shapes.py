import os
import argparse
import pandas as pd
from ujson import dumps as dump_json
from ipdb import set_trace

from os.path import join as joindir 

def feature_collection(list):
    return dict(type="FeatureCollection", features = list)


def feature(properties, coordinates, geom_type='LineString'):
    return dict(
        type='Feature', 
        properties=properties,
        geometry=dict(type=geom_type, coordinates=coordinates)
        )


def shape_to_geojson(shape_id, shape):
    '''
    converts an individual shape (like a route) listing to geojson format
    shape format from: developers.google.com/transit/gtfs/reference#shapes_fields
    ''' 
    
    return feature(
        properties=dict(shape_id=shape_id),
        coordinates=
            shape.sort('shape_pt_sequence')[['shape_pt_lat', 'shape_pt_lon']]\
                .values.tolist(),
        geom_type="LineString")


def create_topojson(dict, directory, name):
    # dict is in geojson format
    tmp_fnm = joindir(directory, name + '.geojson')
    with open(tmp_fnm, 'w+') as f:
        f.write(dump_json(dict))
    # need to have topojson installed
    print('creating {}'.format(name))
    os.system("topojson {tmp} -o {fnm} --properties".format(
        tmp=tmp_fnm, fnm=joindir(directory, name + '.topojson')))
    os.remove(tmp_fnm)
    

def parse_shapes(directory):
    filename = joindir(directory, 'shapes.txt')
    if os.path.isfile(filename):
        shapes = pd.read_csv(filename).dropna(how='all')
        geojson = feature_collection([
            shape_to_geojson(sid, shape)
            for sid, shape in shapes.groupby('shape_id')
            ])
        create_topojson(geojson, directory, 'shapes')


def parse_stops(directory):
    filename = joindir(directory, 'stops.txt')
    stops = pd.read_csv(filename).dropna(how='all')
    geojson = feature_collection([
        feature(
            properties=row.drop(['stop_lat', 'stop_lon']).dropna().to_dict(), 
            coordinates=row[['stop_lat', 'stop_lon']].values.tolist(), 
            geom_type='Point')
        for i, row in stops.iterrows()
        ])
    create_topojson(geojson, directory, 'stops')
    

def parse(directory):
    parse_stops(directory)
    parse_shapes(directory)
    

if __name__ == '__main__':
    parser = argparse.ArgumentParser(
        description='Parse GTFS data into json and topojson')
    parser.add_argument('--directory', default='gtfs-data/BART')
    kwds = vars(parser.parse_args())
    
    parse(**kwds)
    