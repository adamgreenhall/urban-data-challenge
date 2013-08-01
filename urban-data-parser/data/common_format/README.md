The three cities have very different formats. 
This is a standardization of the common elements.


Timeseries data
===================

| Index       |
| ----------- |
| date        |
| id_route    |
| id_trip     | 
| id_stop     |


| Field                    | meaning                                       |
| -------------            | ----------------------------------------------|
| time_arrival             |                                               |
| time_scheduled_arrival   |                                               |
| count                    |                                               |
| count_boarding           |                                               |
| count_exiting            |                                               |




Geo data
===================

This is standardized to the topojson object properties and 
put into the files ``routes.json`` and ``stops.json``.