import pandas as pd
import numpy as np
from os.path import join as joindir
from datetime import datetime
from ipdb import set_trace

day_names = [
    u'monday', u'tuesday', u'wednesday', 
    u'thursday', u'friday', 
    u'saturday', u'sunday']


directory = 'gtfs-data/sfmta'

routes = pd.read_csv(joindir(directory, 'routes.txt'))
trips = pd.read_csv(joindir(directory, 'trips.txt'))
calendar = pd.read_csv(joindir(directory, 'calendar.txt'), 
    parse_dates=['start_date', 'end_date'])
calendar_dates = pd.read_csv(joindir(directory, 'calendar_dates.txt'), 
    parse_dates=['date'])

# this is the big one
stop_times = pd.read_csv(joindir(directory, 'stop_times.txt'))\
    .replace(' ', np.nan).dropna(axis=1, how='all')

# set variables
route_id = routes.ix[0]['route_id']
date = pd.Timestamp(datetime.now())

def get_service_id(date):
    # first check if date is holiday
    holiday = calendar_dates[
        (calendar_dates.date == pd.Timestamp(date.date()))]
    if len(holiday) > 0:
        # type 1 is added service
        holiday = holiday[holiday.exception_type == 1]
        if len(holiday) > 0:
            return holiday.iloc[0]['service_id']
        else:
            return None # no service for the date
    
    # otherwise service_id comes from day of the week
    # TODO - check between valid start_date and end_date
    return calendar[calendar[day_names[date.dayofweek]] == True].iloc[0]['service_id']
    

def mod24hrs(s):
    hrs, mmss = s.split(':', 1)
    return "{:02d}:{}".format(int(hrs) - 24, mmss)


def parse_datetimes(df, date, cols):
    daystr = date.strftime('%Y-%m-%d ')
    for col in cols:
        roll_over_midnight = df[col].str.findall('^2[4-9]:.+').apply(len) > 0
        df.ix[roll_over_midnight, col] = \
            df.ix[roll_over_midnight, col].apply(mod24hrs)
        df[col] = pd.to_datetime(daystr + df[col], coerce=True)
        df.ix[roll_over_midnight, col] = \
            df.ix[roll_over_midnight, col].apply(
            lambda t: t + pd.DateOffset(days=1))
    return df

def get_days_trips(route_id, date):
    service_id = get_service_id(date)
    days_trips = trips[(trips.route_id == route_id) & (trips.service_id == service_id)]
    
    days_times = parse_datetimes(
        stop_times[stop_times.trip_id.isin(days_trips.trip_id)],
        date, ['arrival_time', 'departure_time'])

    if (days_times.arrival_time == days_times.departure_time).all():
        days_times = days_times.drop('departure_time', axis=1)

    with open('route-{}.json'.format(route_id), 'w+') as f:
        f.write(days_times.to_json(orient='records'))