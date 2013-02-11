import json

def df_to_json(df, filename=''):
    x = df.reset_index().T.to_dict().values()
    if filename:
        with open(filename, 'w+') as f: f.write(json.dumps(x))
    return x
    