import csv, sys, os, datetime
import pandas as pd
import numpy as np

## Heavily adapted from 
## http://www.eurion.net/python-snippets/snippet/CSV%20to%20Dictionary.html
#csvFile = 'data/san-francisco/scheduled-arrivals.excerpt.csv'
#headers = None
#content = {}

#print('Reading file %s' % csvFile)
#reader=csv.reader(open(csvFile))
#for row in reader:
    #if reader.line_num == 1:
        #headers = row[0:]
    #else:
        #content[int(reader.line_num)-2] = dict(zip(headers, row[0:]))
        
# Read Scheduled Arrivals into memory
schedArrivals = pd.read_csv('data/san-francisco/scheduled-arrivals.excerpt.csv',
    usecols=[
            'PUBLIC_ROUTE_NAME', 'TRIP_ID', 'BLOCK_NAME',
            'LONGITUDE', 'LATITUDE', 'SCHEDULED_ARRIVAL_TIME',
        ])
                      
# From Adam's code
#os.system('!grep -n \",2\\(4\\|5\\|6\\|7\\|8\\|9\\):\" data/san-francisco/passenger-count-excerpt.csv |cut -f1 -d: > data/san-francisco/bad_hour_lines.csv')
bad_lines = pd.read_csv('data/san-francisco/bad_hour_lines.csv', header=None, squeeze=True).values - 1 # linenos are 1 indexed!\n",

pcounts = pd.read_csv('data/san-francisco/passenger-count.excerpt.csv',
    skiprows=bad_lines,
    usecols=[
        'MO', 'DAY', 'YR',
        'TIMESTOP',
        'TIMEDOORCLOSE',
        'TIMEPULLOUT',
        'STOPID', 'ROUTE', 'TRIP_ID', 'STOP_ID',
        # 'STOP_NAME', 'STOP_SEQ',
        # 'DIR', 'VEHNO',
        'ON', 'OFF', 'LOAD',
    ],
    parse_dates=[\
        ['MO', 'DAY', 'YR'],
        ['MO', 'DAY', 'YR', 'TIMESTOP'],
        ['MO', 'DAY', 'YR', 'TIMEDOORCLOSE'],
        ['MO', 'DAY', 'YR', 'TIMEPULLOUT'],
    ]).rename(columns=dict(
        MO_DAY_YR='date',
        MO_DAY_YR_TIMESTOP='time_stop',
        MO_DAY_YR_TIMEDOORCLOSE='time_door_close',
        MO_DAY_YR_TIMEPULLOUT='time_pullout',
        ))

# I'm a noob and can't figure out numpy or panda.
pcounts['stop_seconds'] = 0
for i in range(len(pcounts)):
    pcounts['stop_seconds'][i] = (np.datetime64(pcounts['time_pullout'][i]) - np.datetime64(pcounts['time_stop'][i])).item().seconds
    
#print pcounts['stop_seconds'].describe()

stop_variability = pcounts.groupby('STOP_ID').stop_seconds.agg([np.mean, np.std])
#print stop_variability[['mean', 'std']].head()

stops = pd.read_csv('data/san-francisco/passenger-count.excerpt.csv',
    usecols=[
        'STOP_ID',
        'STOP_NAME',
        'LATITUDE',
        'LONGITUDE',
        'ROUTE',
        'DIR',
        'STOP_SEQ',
    ])
stops = stops.groupby('STOP_ID').first()
# the latitude on the original dataset isn't negative\n",
stops['LONGITUDE']  *= -1

# get the city's center for a map
stops[['LATITUDE', 'LONGITUDE']].mean().tolist()