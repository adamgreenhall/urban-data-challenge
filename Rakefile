#!/usr/bin/env rake

cities = ['san-francisco', 'geneva', 'zurich']

task :install_env do
  `bundle install`
  `pip install requirements.txt`
end


task :make_timeseries_json do
  # this will take a few minutes
  cities.each{|c| system("python make_timeseries_data.py --city #{c}")}
end


task :dev_server do
  `cd web`
  # stasis gets really slow when it copies all the json every time you update
  # instead - soft link the data to the public directory
  'cd public; ln -s ../data/ data'
  `cd ..`
  # and run stasis on a select group of files
  system("stasis -d 3000 -o #{Dir.glob('*.html*').join(',')},javascript,styles,img")
end