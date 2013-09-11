from flask import Flask, jsonify, request
import pandas as pd
from psycopg2 import connect
from ipdb import set_trace

app = Flask(__name__)

con = connect("postgresql://postgres@localhost/bart-gtfs")

query_template = """
SELECT trips.route_id, trips.trip_id, trips.trip_headsign, 
    stop_time_updates.stop_id, stop_time_updates.arrival_delay,
    stop_times.arrival_time
FROM trip_updates, stop_time_updates, trips, stop_times
WHERE 
    trips.trip_id::text = trip_updates.trip_id::text AND 
    trip_updates.oid = stop_time_updates.trip_update_id AND
    stop_time_updates.stop_id = stop_times.stop_id AND 
    trips.trip_id::text = stop_times.trip_id::text
"""


@app.route('/current')
def current_schedule():
    route_id = request.args.get('route_id', None)
    query = str(query_template)
    if route_id is not None:
        query += " AND trips.route_id = '{}'".format(route_id)
    df = pd.read_sql(query, con)
    
    placeholder = '__df__'
    response = jsonify(data=placeholder)
    response.data = response.data.replace(
        '"{}"'.format(placeholder), df.to_json(orient='records'))
    return response

if __name__ == '__main__':
    app.debug = True
    app.run()