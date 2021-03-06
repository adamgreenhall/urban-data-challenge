import numpy as np
import pandas as pd
import json
from calendar import timegm
import sys
try:
    from IPython.core import ultratb
    def ipy_on_exception():
        sys.excepthook = ultratb.FormattedTB(mode='Verbose',
            color_scheme='Linux', call_pdb=1, include_vars=0)
except ImportError:
    def ipy_on_exception(): 
        pass

from ipdb import set_trace



def handler(obj):
    if hasattr(obj, 'isoformat'):
        return obj.isoformat()
    # elif isinstance(obj, ...):
    #     return ...
    else:
        raise TypeError, 'Object of type %s with value of %s is not JSON serializable' % (type(obj), repr(obj))

def df_to_json(df, filename=''):
    if not (df.count() == len(df)).all():
        # some cols have NaNs - JSON doesn't like these
        nan_cols = df.count() != len(df)
        for col in nan_cols[nan_cols].index:
            print 'warning: null values in {}'.format(col)
            df[col] = df[col].astype(str)
    
    x = [dict(zip([df.index.name] + list(df.columns), vals)) for vals in df.reset_index().T.to_dict('l').values()]
    
    if filename:
        with open(filename, 'w+') as f: f.write(json.dumps(x, default=handler, allow_nan=False))
    return x


def unixtime(dt):
    '''convert a Datetime to a unix timestamp'''
    try: 
        return timegm(dt.timetuple())
    except: 
        #not a time
        return np.nan
    
def native_types(obj):
    try: return np.asscalar(obj)
    except: return obj
