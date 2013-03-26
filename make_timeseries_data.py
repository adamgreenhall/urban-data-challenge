import pandas as pd
import numpy as np
import topojson
import utils
import json
import os
import argparse

utils.ipy_on_exception()

parser = argparse.ArgumentParser()
parser.add_argument('--city', default='san-francisco')
args = parser.parse_args()

city = args.city

timezones = {
    'san-francisco': 'US/Pacific',
    'geneva': 'CET',
    'zurich': 'CET',
}

# load in the timeseries data in the common format
print('load common data format for {}'.format(city))
index_cols = ['date', 'id_route', 'id_trip', 'trip_direction']
df = pd.read_csv('data/common_format/{}.csv'.format(city), 
    parse_dates=[0]).set_index(index_cols)

# drop duplciate rows (problem for SF and Geneva)
df = df.drop_duplicates(cols=['id_stop', 'time_arrival'])


# convert times to unix time
print('convert times to unix time')
time_cols = [
    'time_arrival', 'time_scheduled_arrival',
    'time_departure', 'time_scheduled_departure'
    ]   
# convert to d.t. index and set timezone 
# so that unix time gets created properly
for tcol in filter(lambda c: c in time_cols, df.columns):
    df[tcol] = pd.Series(
        pd.DatetimeIndex(df[tcol].copy()).tz_localize(timezones[city])
        ).apply(utils.unixtime).values


# load the lat/long of the stops
print('load the json stops data and add the lat/long info')
with open('web/data/{}/stops.json'.format(city), 'r') as f: 
    stops = json.loads(f.read())
# stops may belong to many routes, just take the first 
stop_properties = pd.DataFrame(
    topojson.properties(stops, 'stops')) \
    .set_index('id_stop')[['latitude', 'longitude']] \
    .groupby(level=0).first()
# join lat/long to the timeseries data
df = df.join(stop_properties, on='id_stop')


# calc stop_position
df['stop_seq'] = np.nan
df['stop_position'] = np.nan
df = df.reset_index()
for idx, trip in df.groupby(['date', 'id_route', 'id_trip', 'trip_direction']): 
    if trip.trip_direction.values[0] == 0: continue  # if outbound
    df.ix[trip.index, 'stop_seq'] = trip.reset_index().index.values
    
for idx, stops in df.groupby(['id_route', 'id_stop', 'trip_direction']):
    if stops.trip_direction.values[0] == 0: continue  # if outbound
    # take the 75th percentile number to avoid outliers
    df.ix[stops.index, 'stop_position'] = int(stops.stop_seq.describe()['75%'])

df = df.set_index(index_cols)

# write timeseries json to files
# one file per route per day
os.system('mkdir -p web/data/{}/timeseries'.format(city))  # setup the dir 
for (date, id_route), trips in df.groupby(level=['date', 'id_route']):
    filename = 'web/data/{c}/timeseries/{d}_{r}.json'.format(
        c=city, d=date.strftime('%Y%m%d'), r=id_route)
    
    # get the trip order correct
    # trips should be ordered by their first arrival time
    id_trip_ordered = trips.groupby(level=['id_trip', 'trip_direction']).time_arrival.min().order().index

    # nest by trip
    trips_json = []
    for id_trip, trip_direction in id_trip_ordered:
        
        trip = trips.xs(id_trip, level='id_trip').xs(trip_direction, level='trip_direction')\
            .reset_index(drop=True)\
            .sort('time_arrival')\
            .set_index('id_stop')

        # convert lat/long to cummulative km distance from trip start point
        # trip['distance'] = topojson.get_linear_dist(trip)
        # trip = trip.drop(['latitude', 'longitude'], axis=1)

        # TODO - bad data correction on counts
        # TODO - bad data correction on speed
        # trip['speed'] = trip.distance.diff() / trip.time_arrival.diff() * 1000  # in m/s
        
        trip_json = {
            'date': date.strftime('%Y%m%d'),
            'id_route': str(id_route),
            'id_trip': str(id_trip),
            'trip_direction': int(trip_direction),
            'stops': utils.df_to_json(trip)
        }
        trips_json.append(trip_json)
    
    with open(filename, 'w+') as f:
        print filename
        f.write(json.dumps(trips_json))
