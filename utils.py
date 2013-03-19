import json
from calendar import timegm


def handler(obj):
    if hasattr(obj, 'isoformat'):
        return obj.isoformat()
    # elif isinstance(obj, ...):
    #     return ...
    else:
        raise TypeError, 'Object of type %s with value of %s is not JSON serializable' % (type(obj), repr(obj))

def df_to_json(df, filename=''):
    x = df.reset_index().T.to_dict().values()
    if filename:
        with open(filename, 'w+') as f: f.write(json.dumps(x, default=handler))
    return x


def unixtime(dt):
    '''convert a Datetime to a unix timestamp'''
    return timegm(dt.timetuple())