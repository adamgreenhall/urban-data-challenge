import numpy as np
import pandas as pd
import json
from calendar import timegm
import sys
from IPython.core import ultratb
from ipdb import set_trace

def ipy_on_exception():
    sys.excepthook = ultratb.FormattedTB(mode='Verbose',
        color_scheme='Linux', call_pdb=1, include_vars=1)


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
    
def native_types(obj):
    try: return np.asscalar(obj)
    except: return obj
