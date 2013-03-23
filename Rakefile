#!/usr/bin/env rake

cities = ['san-francisco', 'geneva', 'zurich']


task :install_env do
  `bundle install`
  `pip install requirements.txt`
end


task :make_timeseries_json do
  # this will take a few minutes
  cities.each{|c| exec "python make_timeseries_data.py --city #{c}"}
end


task :dev_server do
  `cd web; stasis -d 3000`
end
