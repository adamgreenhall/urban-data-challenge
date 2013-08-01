gtfs-data:
	mkdir -p "gtfs-data"

gtfs-data/bart:gtfs-data
	curl "http://bart.gov/dev/schedules/google_transit.zip" > "tmp.zip"
	unzip tmp.zip -d gtfs-data/bart
	rm tmp.zip

gtfs-data/sfmta:gtfs-data
	curl "http://gtfs.sfmta.com/transitdata/google_transit.zip" > "tmp.zip"
	unzip tmp.zip -d gtfs-data/sfmta
	rm tmp.zip
