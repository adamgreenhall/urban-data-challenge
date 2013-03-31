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

task :deploy do
  if clean_working_directory?
    puts "Checking out deploy branch..."
    `git checkout deploy`
    puts "Done!"
    puts "Running stasis..."
    `cd web; stasis; cd ..`
    puts "Done!"
    puts "Commiting changes"
    `git add . && git commit -am "Deploy on #{Time.now}"`
    puts "Done!"
    puts "Pushing to GitHub"
    `git push origin deploy`
    puts "Done!"
    puts "Pushing to Heroku..."
    `git push heroku deploy:master`
    puts "Deploy finished!"
  else
    puts <<-EOF
  # ERROR
  #####################
  # Unable to deploy because
  # working directory is not clean
  #
  # Commit changes and try again.
  # ###################
    EOF
  end
end

def clean_working_directory?
  !`git status`.split("\n").grep(/nothing to commit/).empty?
end
