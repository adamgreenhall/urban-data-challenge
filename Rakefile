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
    ensure_success do
      exec_command_with_output("git checkout deploy --force", "Checking out deploy branch")
      exec_command_with_output("cd web && stasis && cd ..", "Generating public files")
      raise "No changes to deploy" if clean_working_directory?
      exec_command_with_output("git add . && git commit -am 'Deploy on #{Time.now}'", "Commiting changes")
      exec_command_with_output("git push origin deploy", "Pushing to GitHub")
      exec_command_with_output("git push heroku deploy:master", "Pushing to Heroku")
    end
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

def ensure_success
  begin
    yield
  ensure
    exec_command_with_output("git checkout master", "Cleaning up")
  end
end

def exec_command_with_output(command, message = nil)
  puts "#{message}..." if message
  output = `#{command} 2>&1`
  result = $?.success?

  output = output.split("\n")
  output.each do |line|
    puts " -- #{line}"
  end

  raise "Command `#{command}` failed" unless result

  puts "Done!" if message
end
