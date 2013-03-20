import pandas as pd
import numpy as np
import topojson
import utils
import json

utils.ipy_on_exception()
     
city = 'san-francisco'

# load in the timeseries data in the common format
index_cols = ['date', 'id_route', 'id_trip']
df = pd.read_csv('data/common_format/{}.csv'.format(city), 
    parse_dates=[0]).set_index(index_cols)
# SF has duplicate first stops with zero counts 
df = df.reset_index().groupby(
    index_cols + ['id_stop', 'time_arrival', 'time_scheduled_arrival']
    ).sum().reset_index().set_index(index_cols)


# load the lat/long of the stops
with open('web/data/{}/stops.json'.format(city), 'r') as f: 
    stops = json.loads(f.read())
# stops may beong to many routes, just take the first 
stop_properties = pd.DataFrame(
    topojson.properties(stops, 'stops')) \
    .set_index('id_stop')[['latitude', 'longitude']] \
    .groupby(level=0).first()  
# join lat/long to the timeseries data
df = df.join(stop_properties, on='id_stop')


# get the distance (relative to the start of the trip) for all of the stops
# TODO? - this might be better dnoe in d3.js: 
# http://stackoverflow.com/questions/12431595/how-do-i-return-y-coordinate-of-a-path-in-d3-js
df['distance'] = np.nan
for index, trip in df.groupby(level=index_cols):
    df.ix[index, 'distance'] = topojson.get_linear_dist(trip)
df = df.drop(['latitude', 'longitude'], axis=1)


# convert times to unix time
time_cols = [
    'time_arrival', 'time_scheduled_arrival',
    'time_departure', 'time_scheduled_departure'
    ]
for tcol in filter(lambda c: c in time_cols, df.columns):
    df[tcol] = df[tcol].apply(pd.Timestamp).apply(utils.unixtime).astype(int)


# write timeseries json to files
# one file per route per day
for (date, id_route), trips in df.groupby(level=['date', 'id_route']):
    filename = 'web/data/{c}/timeseries/{d}_{r}.json'.format(
        c=city, d=date.strftime('%Y%m%d'), r=id_route)
    
    # nest by trip
    trips_json = []
    for (__, __, id_trip), trip in trips.reset_index().groupby(index_cols):
        trip_json = {
            'date': date.strftime('%Y%m%d'),
            'id_route': str(id_route),
            'id_trip': str(id_trip),
            'stops': utils.df_to_json(
                trip.drop(index_cols, axis=1).set_index('id_stop')),
        }
        trips_json.append(trip_json)
    
    with open(filename, 'w+') as f:
        print filename
        f.write(json.dumps(trips_json))