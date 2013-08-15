import gtfs_realtime_pb2 as gtfsrt
# https://developers.google.com/transit/gtfs-realtime/trip-updates

# TODO - load from URL

alert = gtfsrt.Alert()
with open('alerts-bart.txt') as f: 
    alert.ParseFromString(f.read())

tu = gtfsrt.TripUpdate()
with open('trip-update-bart.txt', 'r') as f: 
    tu.ParseFromString(f.read())

any([stu.arrival.delay for stu in tu.stop_time_update])
any([stu.departure.delay for stu in tu.stop_time_update])