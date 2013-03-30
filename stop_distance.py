from utils import set_trace
import json
import topojson
import pandas as pd

def load_stops_topojson(city):    
    # load the lat/long of the stops
    print('load the json stops data and add the lat/long info')
    with open('web/data/{}/stops.json'.format(city), 'r') as f: 
        stops = json.loads(f.read())
    # stops may belong to many routes, just take the first 
    city_stops_topojson = pd.DataFrame(
        topojson.properties(stops, 'stops')) \
        .set_index('id_stop')[['latitude', 'longitude']] \
        .groupby(level=0).first()
    return city_stops_topojson

def most_common(lst):
    return max(set(lst), key=lst.count)
 
def get_distances(trips, stop_locations, city='san-francisco', 
    city_stops_topojson=None):
    # SF doesn't have squat on info 
    # Zurich has mileage

    # join lat/long to the timeseries data
    trips = trips.join(city_stops_topojson, on='id_stop')

    stop_locations = stop_locations.set_index('id_stop')
    stop_locations = get_direction_dists(
        trips.xs(1, level='trip_direction').reset_index(),
        stop_locations,
        city,
        direction='inbound')
    stop_locations = get_direction_dists(
        trips.xs(0, level='trip_direction').reset_index(),
        stop_locations,
        city,
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
        
    if next_sid is not None and ordered_trip.ix[prev_pos + 1, 'id_stop'] != next_sid:
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
    
    
    
def get_direction_dists(df, stop_locations, city, direction='inbound'):
    Nstops = df.id_stop.unique().size
    if Nstops == 0:
        return stop_locations
    
    trip_stops = df.groupby('id_trip').apply(lambda grp: grp.id_stop.count())
    if (trip_stops == Nstops).any():
        tid = trip_stops[trip_stops == Nstops].index[0]
        ordered_trip = df[df.id_trip == tid]
    else:
        # the route never hits all the stops in order in one trip
        # find the stops not in the trip with the most stops 
        # manufacture an orderd trip
        tid = trip_stops[trip_stops <= Nstops].idxmax()
        ordered_trip = df[df.id_trip == tid]
        stop_order = ordered_trip.id_stop.reset_index(drop=True).values.tolist()
        stops_missing = pd.Index(df.id_stop.unique()).diff(stop_order)
        for sid in stops_missing:
            ordered_trip = get_stop_pos(sid, df, ordered_trip)
                

    # now that we finally have an ordered trip
    # compute/lookup the distances and add them to the stop_locations
    if city == 'zurich':
        distance = ordered_trip.set_index('id_stop')\
            .rename(columns={'stop_distance': 'distance'}).distance.copy()
    elif city == 'san-francisco':
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
    dist = trips[trips.id_stop == sid].stop_distance.unique()
    if len(dist) == 1:
        return float(dist[0])
    else:
        return most_common(trips[trips.id_stop == sid].stop_distance.values.tolist())
