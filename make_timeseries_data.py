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


# write timeseries json to files
# one file per route per day
os.system('mkdir -p web/data/{}/timeseries'.format(city))  # setup the dir 
for (date, id_route), trips in df.groupby(level=['date', 'id_route']):
    filename = 'web/data/{c}/timeseries/{d}_{r}.json'.format(
        c=city, d=date.strftime('%Y%m%d'), r=id_route)
    
    # get the unique stops
    stops_inbound = pd.Index(trips.xs(1, level='trip_direction').id_stop.unique())
    stops_outbound = pd.Index(trips.xs(0, level='trip_direction').id_stop.unique())
    stops_both_directions = stops_inbound.intersection(stops_outbound)
    stops_inbound = stops_inbound.diff(stops_outbound)
    stops_outbound = stops_outbound.diff(stops_inbound)
    stop_locations = \
        [dict(id_stop=str(s), direction='inbound') for s in stops_inbound] + \
        [dict(id_stop=str(s), direction='outbound') for s in stops_outbound] + \
        [dict(id_stop=str(s), direction='both') for s in stops_both_directions]
    
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
        
        # FIXME - ensure no nan make it into json
        
        trip_json = {
            'id_trip': str(id_trip),
            'trip_direction': int(trip_direction),
            'stops': utils.df_to_json(trip)
        }
        trips_json.append(trip_json)
    
    
    all_json = {
        'date': date.strftime('%Y%m%d'),
        'id_route': str(id_route),
        'stop_locations': stop_locations,
        'trips': trips_json,
    }
    
    with open(filename, 'w+') as f:
        print filename
        f.write(json.dumps(all_json))
