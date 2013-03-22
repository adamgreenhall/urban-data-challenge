#!/usr/bin/env rake

cities = ['san-francsico', 'geneva', 'zurich']


task :install_env
  `bundle install`
  `pip install requirements.txt`
end


task :make_timeseries_json
  # this will take a few minutes
  cities.each{|c| exec "python make_timeseries_json.py -city #{c}"}
end


task :dev_server
  `cd web; statis -d 3000`
end
