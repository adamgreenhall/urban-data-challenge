import pandas as pd
import utils
import json
import os
import argparse
import datetime
from stop_distance import get_distances, geneva_dist, load_stops_topojson

from utils import set_trace
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


# convert times to timestamps
# ignore the scheduled times 
time_cols = [
    'time_arrival', 'time_departure',
    # 'time_scheduled_arrival', 'time_scheduled_departure'
    ]   
for tcol in filter(lambda c: c in time_cols, df.columns):
    df[tcol] = pd.DatetimeIndex(df[tcol]).values


if city != 'geneva':
    city_stops_topojson = load_stops_topojson(city)
else:
    city_stops_topojson = None


# write timeseries json to files
# one file per route per day
trip_cols = ['count', 'count_boarding', 'count_exiting'] + \
    filter(lambda c: c in time_cols, df.columns)


os.system('mkdir -p web/data/{}/timeseries'.format(city))  # setup the dir 
for (date, id_route), trips in df.groupby(level=['date', 'id_route']):
    filename = 'web/data/{c}/timeseries/{d}_{r}.json'.format(
        c=city, d=date.strftime('%Y%m%d'), r=id_route)
    
    # get the unique stops
    stops_inbound = pd.Index(trips.xs(1, level='trip_direction').id_stop.unique())
    try: 
        stops_outbound = pd.Index(trips.xs(0, level='trip_direction').id_stop.unique())
    except KeyError:
        stops_outbound = pd.Index([])
    
    stops_both_directions = stops_inbound.intersection(stops_outbound)
    if city == 'zurich' and \
        len(stops_both_directions) == len(stops_inbound) == len(stops_outbound):
        stops_both_directions = []
        
    stops_inbound = stops_inbound.diff(stops_both_directions)
    stops_outbound = stops_outbound.diff(stops_both_directions)
        
    stop_locations = pd.DataFrame(
        [dict(id_stop=s, direction='inbound') for s in stops_inbound] + \
        [dict(id_stop=s, direction='outbound') for s in stops_outbound] + \
        [dict(id_stop=s, direction='both') for s in stops_both_directions],
        columns=['id_stop', 'direction', 'distance']
        )
    
    # get linear stop distances    
    if city == 'geneva':
        for i, stop in stop_locations.iterrows():
            stop_locations.ix[i, 'distance'] = geneva_dist(trips, stop)
    else:
        if len(stop_locations) > 0:
            stop_locations = get_distances(
                trips, stop_locations, city, city_stops_topojson=city_stops_topojson)

    stop_locations = stop_locations.set_index('id_stop')
    stop_locations['direction'] = stop_locations.direction\
        .replace('inbound', 1)\
        .replace('outbound', 0)\
        .replace('both', -1)

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

        tStart = trip.time_arrival.min()
        if tStart.hour < 2 and tStart.date() == date.date():
            # this is a trip finishing up in the middle of the night
            continue
        
        # timezones are terrible to deal with in javascript
        # so convert each timestamp to unix time (in local time, but pretend it is in in UTC)
        # on the other end, use d3.time.format.utc to read times (as if in UTC)
        for tcol in filter(lambda c: c in time_cols, df.columns):
            trip[tcol] = trip[tcol].apply(utils.unixtime).values
        
        trip_json = {
            'id_trip': str(id_trip),
            'trip_direction': int(trip_direction),
            'stops': utils.df_to_json(trip[trip_cols])
        }
        trips_json.append(trip_json)
    
    
    all_json = {
        'date': date.strftime('%Y%m%d'),
        'id_route': str(id_route),
        'stop_locations': utils.df_to_json(stop_locations),
        'trips': trips_json,
    }
    
    with open(filename, 'w+') as f:
        print filename
        f.write(json.dumps(all_json))
