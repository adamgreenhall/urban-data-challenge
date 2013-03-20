import pandas as pd
import numpy as np
import topojson
import utils
import json
# from ipdb import set_trace
     
city = 'san-francisco'


index_cols = ['date', 'id_route', 'id_trip']
df = pd.read_csv('data/common_format/{}.csv'.format(city), 
    parse_dates=[0]).set_index(index_cols)
with open('web/data/{}/stops.json'.format(city), 'r') as f: 
    stops = json.loads(f.read())

stop_properties = pd.DataFrame(
    topojson.properties(stops, 'stops')
    ).set_index('id_stop')[['latitude', 'longitude']]
    
df = df.join(stop_properties, on='id_stop')


# SF has duplicate first stops with zero counts 
df = df.reset_index().groupby(
    index_cols + ['id_stop', 'time_arrival', 'time_scheduled_arrival']
    ).sum().reset_index().set_index(index_cols)


# get the distance for all of the 
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
for (date, id_route), trips in df.groupby(level=['date', 'id_route']):
    filename = 'web/data/{c}/timeseries/{d}_{r}.json'.format(
        c=city, d=date.strftime('%Y%m%d'), r=id_route)
    trips_json = []
    
    for (__, __, id_trip), trip in trips.reset_index().groupby(index_cols):
        trip_json = {
            'date': date.strftime('%Y%m%d'),
            'id_route': int(id_route),
            'id_trip': int(id_trip),
            'stops': utils.df_to_json(
                trip.drop(index_cols, axis=1).set_index('id_stop')),
        }
        trips_json.append(trip_json)
    
    with open(filename, 'w+') as f:
        print filename
        f.write(json.dumps(trips_json))