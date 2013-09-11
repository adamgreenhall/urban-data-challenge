db = "postgresql://postgres@localhost/bart-gtfs"
url_gtfs = "http://bart.gov/dev/schedules/google_transit.zip" 
url_update = "http://www.bart.gov/dev/gtrtfs/tripupdate.aspx"

desc "install all of the requirements and set up the schedule"
task :install do
  `pip install -r requirements.txt`
  # scheduled gtfs data  
  `createdb bart-gtfs`
  system("gtfsdb-load --database_url #{db} #{url_gtfs}")
  # realtime data
  `git clone https://github.com/mattwigway/gtfsrdb`
end

desc "run the realtime updating script"
task :update do
  system("python gtfsrdb/gtfsrdb.py -t #{url_update} -d #{db} --create-tables --discard-old --wait 30")
end
desc "run the webserver"
task :run do
  system("source venv/bin/activate && python app.py")
end