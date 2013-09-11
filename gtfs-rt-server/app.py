from flask import Flask
import pandas as pd
from psycopg2 import connect
from pdb import set_trace

app = Flask(__name__)

con = connect("postgresql://postgres@localhost/bart-gtfs")

query = """
SELECT trips.route_id, trips.trip_id, trips.trip_headsign, 
    stop_time_updates.stop_id, stop_time_updates.arrival_delay, stop_times.arrival_time
FROM trip_updates, stop_time_updates, trips, stop_times
WHERE 
    trips.trip_id::text = trip_updates.trip_id::text AND 
    trip_updates.oid = stop_time_updates.trip_update_id AND
    stop_time_updates.stop_id = stop_times.stop_id AND 
    trips.trip_id::text = stop_times.trip_id::text
ORDER BY stop_time_updates.stop_id;
"""

df = pd.read_sql('select * from agency', con)
print df

@app.route('/current')
def current_schedule(route_id=None):
    set_trace()
    return data.to_json()

if __name__ == '__main__':
    app.run()