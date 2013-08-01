from utils import set_trace
import json
import topojson
import pandas as pd
import numpy as np

def load_stops_topojson(city):    
    # load the lat/long of the stops
#    if city == 'san-francisco':
    print('load the json stops data and add the lat/long info')
    with open('web/data/{}/stops.json'.format(city), 'r') as f: 
        stops = json.loads(f.read())
    # stops may belong to many routes, just take the first 
    stops_topojson = pd.DataFrame(
        topojson.properties(stops, 'stops')) \
        .set_index('id_stop')[['latitude', 'longitude']] \
        .groupby(level=0).first()

#    else:
#        print('load the json routes data to get the stop distances')
#        with open('web/data/{}/routes.json'.format(city), 'r') as f: 
#            routes = json.loads(f.read())
#        # stops may belong to many routes, just take the first 
#        stops_topojson = pd.DataFrame(
#            topojson.properties(routes, 'routes'))
#        stops_topojson['id_route'] = stops_topojson.id_route.astype(int)
    return stops_topojson

def most_common(lst):
    return max(set(lst), key=lst.count)
 
def get_distances(trips, stop_locations, city='san-francisco', 
    city_stops_topojson=None):
    # SF doesn't have squat on info 

    # if city == 'san-francisco':
    # join lat/long to the timeseries data
    
    trips = trips.join(city_stops_topojson, on='id_stop')
#    else:
#        # Zurich has distance from the routes topojson, but indexed differently
#        pass

    stop_locations = stop_locations.set_index('id_stop')
    stop_locations = get_direction_dists(
        trips.xs(1, level='trip_direction').reset_index(),
        stop_locations,
        city,
        city_stops_topojson,
        direction='inbound')
    stop_locations = get_direction_dists(
        trips.xs(0, level='trip_direction').reset_index(),
        stop_locations,
        city,
        city_stops_topojson,
        direction='outbound')
    return stop_locations.reset_index()

def get_stop_pos(sid, df, ordered_trip):
    tids = df[df.id_stop == sid].id_trip
    # get the longest of the trips
    trip_lens = df[df.id_trip.isin(tids)].groupby('id_trip').id_stop.count()
    tid = trip_lens.idxmax()
    trip = df[df.id_trip == tid]
    stop_index = df[(df.id_trip == tid) & (df.id_stop == sid)].index[0]
    if stop_index == trip.index[0]:
        # it is the first stop
        ordered_trip = df.ix[[stop_index]]\
            .append(ordered_trip)\
            .reset_index(drop=True)
        return ordered_trip

    # lookup the prev stop
    prev_sid = trip.ix[stop_index - 1, 'id_stop']
    # lookup the next stop
    if len(trip) > stop_index + 1:
        next_sid = trip.ix[stop_index + 1, 'id_stop']
    else:
        # probably last - not garunteed, would have to check all the other routes
        next_sid = None
    
    if prev_sid in ordered_trip.id_stop.values:
        prev_pos = stopPos(ordered_trip, prev_sid)
    else:
        NNsids = get_nearest_neightbor(sid, df, ordered_trip)
        prev_pos = stopPos(ordered_trip, NNsids[0])
        next_pos = stopPos(ordered_trip, NNsids[1])
        if prev_pos > next_pos:
            tmp = int(prev_pos)
            prev_pos = int(next_pos)
            next_pos = tmp

        prev_sid = ordered_trip.ix[prev_pos, 'id_stop']    
        next_sid = ordered_trip.ix[next_pos, 'id_stop']
        
    if next_sid is not None and \
        len(ordered_trip) > prev_pos + 1 and \
        ordered_trip.ix[prev_pos + 1, 'id_stop'] != next_sid:
        # TODO could be many stops after this 
        print('warning - could be many stops after this one')

    # insert after the prev pos
    ordered_trip = ordered_trip.ix[:prev_pos]\
        .append(df.ix[[stop_index]])\
        .append(ordered_trip.ix[prev_pos+1:]).reset_index(drop=True)

    return ordered_trip

def stopPos(ordered_trip, sid):
    return ordered_trip[ordered_trip.id_stop == sid].index[0]

def get_nearest_neightbor(sid, df, ordered_trip):
    LL = ['latitude', 'longitude']
    stopLL = df[df.id_stop == sid].head(1)[LL].values[0]
    neighbors = (ordered_trip.set_index('id_stop')[LL].add(-1 * stopLL)**2).sum(axis=1)
    neighbors.sort()
    return neighbors.index[:2]
    
    
    
def get_direction_dists(df, stop_locations, city, stops_topojson, direction='inbound'):
    Nstops = df.id_stop.unique().size
    if Nstops == 0:
        return stop_locations

    # if city == 'zurich': return zurich_dist(df, stop_locations, stops_topojson, direction)
        
    trip_stops = df.groupby('id_trip').apply(lambda grp: grp.id_stop.count())
    if (trip_stops == Nstops).any():
        tid = trip_stops[trip_stops == Nstops].index[0]
        ordered_trip = df[df.id_trip == tid]
    else:
        # the route never hits all the stops in order in one trip
        # find the stops not in the trip with the most stops 
        # manufacture an orderd trip
        try: tid = trip_stops[trip_stops <= Nstops].idxmax()
        except ValueError: # nothing in the above select
            tid = trip_stops.idxmax()
            
        ordered_trip = df[df.id_trip == tid]
        stop_order = ordered_trip.id_stop.reset_index(drop=True).values.tolist()
        stops_missing = pd.Index(df.id_stop.unique()).diff(stop_order)
        for sid in stops_missing:
            ordered_trip = get_stop_pos(sid, df, ordered_trip)
                

    # now that we finally have an ordered trip
    # compute/lookup the distances and add them to the stop_locations
#    if city == 'zurich':
#        distance = ordered_trip.set_index('id_stop')\
#            .rename(columns={'stop_distance': 'distance'}).distance.copy()
#    elif city == 'san-francisco':
    distance = pd.Series(
        topojson.get_linear_dist(ordered_trip),
        index=ordered_trip.id_stop.values, name='distance')

    if direction == 'outbound':
        # reverse the distances to make inbuond first stop 0 distance
        distance = pd.Series(list(reversed(distance.values)), index=distance.index)
    
    if len(distance) > len(distance.index.unique()):
        distance = distance.groupby(distance.index).first()
    
    stop_dists = stop_locations.distance
    stop_dists.ix[distance.index] = distance
    stop_locations['distance'] = stop_dists
        
    return stop_locations



def geneva_dist(trips, stop):
    # simple lookup of field "distance from start of route" by stop id
    sid = stop['id_stop']
    stop_dists = trips[trips.id_stop == sid].stop_distance.unique()
    if len(stop_dists) == 1:
        dist = float(stop_dists[0])
    else:
        dist = most_common(trips[trips.id_stop == sid].stop_distance.values.tolist())
    if stop['direction'] in ['inbound', 'both']:
        return dist
    else:
        # if outbound, get distance from the length of route
        route_len = trips.xs(0, level='trip_direction').stop_distance.max()
        return route_len - dist
        
def zurich_dist(trips, stop_locations, stops_topojson, direction='inbound'):
    # get linear stop distances for one direction of one route          
    if not (direction in stop_locations.direction.values):
        return stop_locations
    
    id_route = trips.id_route.unique()[0]
    route_stops = stops_topojson[(stops_topojson.id_route == id_route)]
    route_stop_ids = pd.Index(route_stops.id_stop_start.unique()).union(
        route_stops.id_stop_end)
    
    def get_dist(sid, sid_next):
        return route_stops[
            (route_stops.id_stop_start == sid) &\
            (route_stops.id_stop_end == sid_next)].length_route.values[0]
    
    
    ordered_stop_ids = pd.DataFrame(
        trips[trips.id_stop.isin(route_stop_ids)]\
            .groupby('id_stop').seq_stop.last().order())
    

#    if (ordered_stop_ids.diff() == 0).any():
#        set_trace()    
#        ordered_stop_ids = pd.DataFrame(
#            trips.groupby('id_stop').seq_stop.first().order())
#         if (ordered_stop_ids.diff() == 0).any():
#            print('warning: non-unique sequence for stops')    
    
    # lookup the distance between stops
    ordered_stop_ids['distance'] = 0.0
    for i, sid in enumerate(ordered_stop_ids.index[:-1]):
        sid_next = ordered_stop_ids.index[i+1]
        try: ordered_stop_ids.ix[sid_next, 'distance'] = get_dist(sid, sid_next)
        except IndexError: continue
        
    # get the distance from the start of the line
    ordered_stop_ids['distance'] = ordered_stop_ids.distance.cumsum()
    
    # flip the direction of origin
    if direction == 'outbound': 
        ordered_stop_ids['distance'] = ordered_stop_ids.distance.max() - ordered_stop_ids.distance

    if (ordered_stop_ids.distance == 0).sum() > 1:
        print('warning, non-unique sequence for stops')

    stop_locations.ix[stop_locations.direction == direction, 'distance'] = \
        ordered_stop_ids.distance
    return stop_locations
