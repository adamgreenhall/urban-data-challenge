import os
from os.path import join as joindir 
import pandas as pd
from pandas.io.sql import get_schema
from glob import glob

directory = 'gtfs-data/BART'
schemas = []
for fnm in sorted(glob(joindir(directory, "*.txt"))):
    
    name = os.path.splitext(os.path.split(fnm)[1])[0]
    schemas.append(get_schema(pd.read_csv(fnm), name, 'postgres'))
    
with open('create-schema.sql', 'w+') as f:
    f.write('\n\n'.join(schemas))
    