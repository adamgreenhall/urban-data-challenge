playbackTmax = 3 * 60 * 1000  # 3min

colorOfDayScale = d3.scale.linear()
  .domain([0,23])
colorOfDayScale.domain([0.0, 0.20, 0.21875, 0.23958333333333334, 0.25, 0.2708333333333333, 0.2916666666666667, 0.3125,  0.3333333333333333, 0.375, 0.4166666666666667, 0.5, 0.5416666666666666, 0.5833333333333334, 0.625, 0.6666666666666666, 0.7083333333333334, 0.75,
 0.7708333333333334, 0.7916666666666666, 0.8125, 0.8333333333333334, 0.8541666666666666, 0.875, 0.916].map(colorOfDayScale.invert))
colorOfDayScale.range(["#01062d","#2b1782","#600eae","#9b13bb","#b13daf","#d086b5","#dfa7ac","#ebc8ab","#f3dfbc","#fef6aa","#fefdea","#fbf4a5","#f0d681","#fbf8da","#f5f1ba","#f0e435","#f4be51","#ec2523","#a82358","#712b80","#4a3f96","#188dba","#1c71a3","#173460","#020b2f"])

colorOfDay = (t) ->
  d3.rgb(colorOfDayScale(+d3.time.format.utc('%H')(new Date(t * 1000))))

colorOfTextScale = d3.scale.linear()
  .domain([0,23])
colorOfTextScale.domain([0.0, 0.20, 0.21875, 0.23958333333333334, 0.25, 0.2708333333333333, 0.2916666666666667, 0.3125, 0.3333333333333333, 0.375, 0.4166666666666667, 0.5, 0.5416666666666666, 0.5833333333333334, 0.625, 0.6666666666666666, 0.7083333333333334, 0.75, 0.7708333333333334, 0.7916666666666666, 0.8125, 0.8333333333333334, 0.8541666666666666, 0.875, 0.916].map(colorOfTextScale.invert))
colorOfTextScale.range(["#e5e7f8","#e5e7f8","#f6f2f8","#f6f2f8","#f6f2f8","#d086b5","#2c0938","#2c0938","#2c0938","#2c0938","#2c0938","#2c0938","#2c0938","#2c0938","#2c0938","#2c0938","#2c0938","#2c0938","#2c0938","#2c0938","#f6f2f8","#f6f2f8","#f6f2f8","#f6f2f8","#f6f2f8"])

colorOfText = (t) ->
  d3.rgb(colorOfTextScale(+d3.time.format.utc('%H')(new Date(t * 1000))))

updateTime = (timeDisplay, t) ->
  curTime = new Date(t * 1000)
  timeDisplay.time.text(d3.time.format.utc('%I:%M')(curTime))
  timeDisplay.ampm.text(d3.time.format.utc('%p')(curTime))

isNight = (t) ->
  hour = +d3.time.format.utc('%H')(new Date(t * 1000))
  0<=hour<7 or hour>=19

radiusPassenger = 3
maxNpassengers = 5


window.show_ts = (error, data_daily, map) ->

  if error
    console.log(error.statusText)
    d3.selectAll('.normalOperation').classed('hidden', true)
    d3.selectAll('.errorState').classed('hidden', false)
    return
  else
    d3.selectAll('.errorState').classed('hidden', true)
    d3.selectAll('.normalOperation').classed('hidden', false)

  tVal = (d) -> d.time_arrival
  tDepartureVal = (d) -> d.time_departure
  rVal = (d) -> d.count  # passenger count


  fraction_stopped_time =
    deptaring: 2/5
    boarding: 3/5

  visStopRadius = 3

  # setup container
  margin =
    top: 3
    right: 20
    bottom: 3
    left: 20
  width = map.getWidth() - margin.left - margin.right
  height = map.getHeight() / 4 - margin.top - margin.bottom

  svg_route = d3.select('#route_vis').append('svg').attr
    width: width + margin.left + margin.right
    height: height + margin.top + margin.bottom
  g = svg_route.append("g").attr
    transform: translate(margin.left, margin.top)

  timeDisplay =
    time: d3.select('#time-display > .time')
    ampm: d3.select('#time-display > .ampm')
    weekday: d3.select('#time-display > .weekday')

  stopNameDisplay = g.append('text')
    .attr
      id: 'stop-name-sign'
      x: 0
      y: 0
    .text('')

  # a linear scale mapping the time difference (in UTC seconds)
  # to the length of the visualization playback (playbackTmax)
  tScale = d3.scale.linear()
    .domain(nested_min_max(data_daily.trips, 'stops', tVal))
    .range([0, playbackTmax])
  yScale = d3.scale.linear()
    .domain([0, 1])
    .range([height - margin.top, 0 + margin.bottom])
  rScale = d3.scale.linear()
    .domain(nested_min_max(data_daily.trips, 'stops', rVal))
    .range([30, 80])
    
  mostStopPgrs = nested_min_max(data_daily.trips, 'stops', (d) -> d.count_boarding)[1]
  sumPpl = data_daily.trips.map (trip) ->
    d3.sum(trip.stops.map (stop) -> stop.count_boarding)

  if d3.max(sumPpl) > 100 and map.city == 'geneva'
    # if number of passgengers on a trip is more than 100
    # each stop gets only one passenger circle 
    # but scaled to a radius representing how many passengers
    countScale = (c) -> 1 # Math.min(c, maxNpassengers)
    radiusPassengerScale = d3.scale.linear()
      .domain([1, mostStopPgrs+5])
      .range([radiusPassenger, 15])
  else
    # otherwise - one circle = one passenger 
    countScale = (c) -> c
    radiusPassengerScale = (c) -> radiusPassenger
  
  
  yPos = yScale(0.5)
  yPosPassengers = yScale(0.4)
  yValStop = (dir) ->
    if dir == 1 #inbound
      0.48
    else if dir == 0 # outbound
      0.52
    else
      0.5

  yValBus = (dir) ->
    if dir then 0.45 else 0.69

  yScaledValDoorsBus = (dir) ->
    yScale(yValBus(dir)) + (if dir then 0.5 * rScale.range()[1] else 0)

  yPosPassengers = (dir) ->
    if dir then yScale(0.20) else yScale(0.69)
  randomYpos = (trip_direction) ->
    # inbound enters/exits below, outbound enters/exits above
    if trip_direction
      getRandomRange(yScale(0), yScaledValDoorsBus(trip_direction))
    else
      getRandomRange(yScaledValDoorsBus(trip_direction), yScale(1))

  color_filler = d3.scale.category20()

  # setup the route line and stops
  line_maker = d3.svg.line()
    .x((d) -> d)
    .y((d) -> yPos)


  routePath = d3.select("path.bus-route-#{data_daily.id_route}")
  routePath.moveToFront()

  # define xVal to lookup the distance from the stops data
  stop_dists = {}  # make a hash keyed by stop id
  data_daily.stop_locations.forEach (d, i) ->
    stop_dists[d.id_stop] = +d.distance
  xVal = (d) -> stop_dists[d.id_stop]
  xScale = d3.scale.linear()
    .domain(d3.extent(d3.values(stop_dists)))
    .range([margin.left, width - margin.right])

  xScaledValBus = (d, dir) -> xScale(xVal(d)) - (if dir then rScale(rVal(d)) else 0)

  line = g.append("path")
    .datum(xScale.range())
    .attr
      d: line_maker
      class: "bus-line"
    .style
      stroke: map.g.select("path.bus-route-#{data_daily.id_route}").style('stroke')


  stops = g.selectAll("circle.bus-stop")
    .data(data_daily.stop_locations).enter()
    .append("circle").attr
      class: (d) -> "bus-stop bus-stop-#{d.id_stop}"
      r: visStopRadius
      cx: (d) -> xScale(d.distance)
      cy: (d) -> yScale(yValStop(d.direction))

  # add mouse interaction
  vis_highlight_stop = (d, elem) ->
    map_circle = map.g.selectAll("circle.bus-stop-#{d.id_stop}")
    map_circle
      .moveToFront()
      .classed('highlighted', true)
      .transition()
        .attr('r', map.busStopRadius * 3)
    if elem  # this is an acutal mouseover, not just bus motion
      map_circle.classed('user-highlighted', true)
      vis_circle = d3.select(elem)
      vis_circle
        .classed('user-highlighted', true)
        .moveToFront()
        .transition()
          .attr('r', visStopRadius*2)
      # show the stop name
      stopNameDisplay
        .text(map_circle.data()[0].properties.name_stop)
        .attr
          x: vis_circle.attr('cx')
          y: +vis_circle.attr('cy') - 20
    
  vis_unhighlight_stop = (d, elem) ->
    map_circle = map.g.selectAll("circle.bus-stop-#{d.id_stop}")
    map_circle
      .classed('highlighted', false)
      .transition()
        .attr('r', map.busStopRadius)
    if elem
      map_circle.classed('user-highlighted', false)
      d3.select(elem)
        .classed('user-highlighted', false)
        .transition()
          .attr('r', visStopRadius)
      stopNameDisplay.text('')


  stops
    .on('mouseover', (d) -> vis_highlight_stop(d, this))
    .on('mouseout', (d) -> vis_unhighlight_stop(d, this))


  # basic force layout
  force_layout = () ->
    d3.layout.force()
      .links([])
      .gravity(0)
      .friction(0.2)
      .charge(-80)
      .size([svg_route.width, svg_route.height])

  # create timers to start each bus trip
  all_timers = []
  data_daily.trips.forEach (data_trip, i) ->
    data_trip.realTimeStart = d3.min(data_trip.stops, tVal)
    data_trip.Tstart = tScale(data_trip.realTimeStart)

  data_daily.trips.forEach (data_trip, i) ->
    start_trip = () ->
      duration = (if i + 1 < data_daily.trips.length then data_daily.trips[i+1].Tstart - data_trip.Tstart else 0) 
      d3.select('#route_vis_panel')
        .transition().duration(duration)
          .style('background-color', colorOfDay(data_trip.realTimeStart))
          .style('color', colorOfText(data_trip.realTimeStart))

      d3.select("#weekday")
        .transition().duration(duration)
        .style('color', colorOfText(data_trip.realTimeStart))

      begin_bus_trip(data_trip, i)
    map.visTimers.push(setTimeout(start_trip, data_trip.Tstart))


  begin_bus_trip = (data_trip, tripNumber) ->
    id_trip = data_trip.id_trip
    data_stops = data_trip.stops
    current_bus_stop = 0
    # if departure time is not defined, the default is 30 seconds after arrival
    data_stops.forEach (d, i) ->
      d.time_departure or= tVal(d) + 30
      return

    durationScale = d3.scale.linear()
      .domain([0, d3.max(data_stops, tVal) - d3.min(data_stops, tVal)])
      .range([0, tScale(d3.max(data_stops, tVal)) - tScale(d3.min(data_stops, tVal))])

    bus = g.append('image')
      .style
        opacity: 0.8
      .attr
        'xlink:href': "img/bus-#{if data_trip.trip_direction then 'inbound' else 'outbound'}#{if isNight(data_trip.realTimeStart) then '-night' else ''}.png"
        class: "bus bus-" + data_trip.id_trip
        width: rScale(rVal(data_stops[0]))
        height: rScale(rVal(data_stops[0]))
        x: xScaledValBus(data_stops[0], data_trip.trip_direction)
        y: yScale(yValBus(data_trip.trip_direction))

    # setup the force layout for the people moving to the bus stops
    data_passengers = []
    passenger_circles = g.selectAll("circle.passenger-#{id_trip}")

    tick_fn = (e) ->
      # Push nodes toward their designated focus.
      k = .9 * e.alpha
      data_passengers.forEach (o, i) ->
        o.x += (xScale(xVal(data_stops[o.stop_number])) - o.x) * k
        o.y += (yPosPassengers(data_trip.trip_direction) - o.y) * k
      passenger_circles.attr
        cx: (d) -> d.x
        cy: (d) -> d.y
      return

    force = force_layout()
      .nodes(data_passengers)
      .on('tick', tick_fn)


    redraw_passengers = (boarding_duration) ->
      boarding_duration or= 100  # ms
      force.nodes(data_passengers)
      passenger_circles = passenger_circles.data(force.nodes(), (d) -> d.index)
      passenger_circles.enter()
        .append("circle").attr
          class: "passenger passenger-#{id_trip}"
          cx: (d) -> d.x
          cx: (d) -> d.y
          r: (d) -> radiusPassengerScale(d.nPassengers)
        .style
          fill: (d) -> color_filler(d.stop_number)
          stroke: (d) -> d3.rgb(color_filler(d.stop_number)).darker(2)
          "stroke-width": 1.5
        .call(force.drag)

      passenger_circles.exit()
        .transition(boarding_duration)
        .attr
          cx: (d) -> xScale(xVal(data_stops[d.stop_number]))
          cy: (d) -> yScale(yValBus(data_stops[d.stop_number]))
      drop_circles = () ->
        passenger_circles.exit().remove()
        # HACK - cleanup left behind passegers
        passenger_circles.filter((d) -> d.stop_number == current_bus_stop).remove()
        data_passengers = data_passengers.filter((d) -> d.stop_number != current_bus_stop)

      setTimeout(drop_circles, boarding_duration)

      force.start()
      return
  
    add_passenger_to_bus_stop = (psgr) ->
      return if current_bus_stop >= data_stops.length - 1
      stop_number = psgr.stop_number
      
      data_passengers.push
        stop_number: stop_number
        id_trip: id_trip
        # centered horizontally on the foci, but with some scatter to either side
        x: xScale(xVal(data_stops[stop_number])) + (Math.random() - 0.5) * width / data_stops.length
        y: randomYpos(data_trip.trip_direction)
        nPassengers: psgr.nPassengers

      redraw_passengers()


    show_departing_passengers = (stop_number) ->
      stop = data_stops[stop_number]
      departing_data = ({
        xEnd: xScale(xVal(stop)) + (Math.random() - 0.5) * width / data_stops.length,
        yEnd: randomYpos(data_trip.trip_direction)
        } for i in _.range(stop.count_exiting))
      # return if stop.count_exiting == 0
      departing_passengers = g.selectAll("circle.passenger-departing-#{id_trip}-#{stop_number}")
        .data(departing_data)
        .enter().append('circle')
      departing_passengers.attr
          class: "passenger-departing passenger-departing-#{id_trip}-#{stop_number}"
          cx: xScale(xVal(stop))
          cy: yScaledValDoorsBus(data_trip.trip_direction)
          r: 3
        .style
          fill: '#eee' # color_filler(stop_number)
          stroke: d3.rgb(color_filler(stop_number)).darker(2)
          "stroke-width": 1.5
      # set the duration of the departure
      duration = durationScale(tDepartureVal(stop) - tVal(stop)) + 1000
      # fade out and move to some random position near the stop
      departing_passengers.transition()
        .duration(duration)
        .attr
          cx: (d) -> d.xEnd
          cy: (d) -> d.yEnd
        .style
          'fill-opacity': 0.01

      # when transition ends - remove the data
      drop_data = () ->
        departing_passengers.data([]).exit().remove()
        return
      setTimeout(drop_data, duration)

    show_boarding_passengers = (stop_number, duration_stopped) ->
      # show the people to getting onto the bus
      return unless data_passengers.length > 0
      boarding_fn = () ->
        data_passengers = data_passengers.filter((p) -> p.stop_number != stop_number)
        # redraw the force layout without this stop's people
        redraw_passengers(duration_stopped * fraction_stopped_time.boarding )

      # first, wait for people to get off the bus (3/5ths of the time)
      setTimeout(boarding_fn, duration_stopped * fraction_stopped_time.deptaring)
      return

    move_bus = (stop_number) ->
      current_bus_stop = stop_number
      if stop_number == 0
        duration_motion = 50  # can't be zero, because d3 timer events take up to 10ms to fire
        duration_stopped = 100
      else
        # transition duration is the difference between prev. stop departure time and arrival
        duration_motion = durationScale( tVal(data_stops[stop_number]) - tDepartureVal(data_stops[stop_number - 1]) )
        duration_stopped = durationScale( tDepartureVal(data_stops[stop_number]) - tVal(data_stops[stop_number]) )

      # move bus to the current stop
      bus.transition()
        .duration(duration_motion)
        .attr
          x: xScaledValBus(data_stops[stop_number], data_trip.trip_direction)


      arrival_fn = () ->
        # upon arrival at stop
        if stop_number < (data_stops.length - 1)
          # update the clock display
          updateTime(timeDisplay, tVal(data_stops[stop_number]))
          # update highlighting on map
          vis_highlight_stop(data_stops[stop_number])
          # passengers get out
          show_departing_passengers(stop_number)
          # passengers get on
          show_boarding_passengers(stop_number, duration_stopped)
          # bus size updates
          bus.transition()
            .duration(duration_stopped)
            .attr
              height: rScale(rVal(data_stops[stop_number]))
              width: rScale(rVal(data_stops[stop_number]))
          # pause for the time the bus spends at the stop.
          # and then move the bus to the next stop
          move_to_next_fn = () ->
            vis_unhighlight_stop(data_stops[stop_number])
            move_bus(stop_number + 1)
            return
          map.visTimers.push(setTimeout(move_to_next_fn, duration_stopped))
        else
          # done with trip
          fadeDuration = 600
          bus.transition().duration(fadeDuration)
            .style('opacity', 0)
          rmFn = () -> bus.remove()
          setTimeout(rmFn, fadeDuration)
          
          # remove all passengers, if any left waiting
          remaining = d3.selectAll("circle.passenger-#{id_trip}")
          if remaining[0].length > 0
            #removing left behind passengers for the trip
            remaining.remove()
          
          if tripNumber == data_daily.trips.length - 1
            # done with all trips for the day
            map.advanceDate()
        return

      setTimeout(arrival_fn, duration_motion)


    # set up the passenger arrival timing
    data_passenger_timing = []
    data_stops.forEach (stop, s) ->
      # if stop.count_boarding > maxNpassengers
      _.range(countScale(stop.count_boarding)).forEach (el, i) -> 
        # make passengers equally likely that passeger arrives while 
        # bus is anywhere between 8 stops away and Tarrival - 100sec
        if s > 8
          tPrev = tVal(data_stops[s - 5])
        else
          tPrev = tVal(data_stops[0])
        data_passenger_timing.push
          time_appear: getRandomRange(tPrev, tVal(stop) - 100) - tVal(data_stops[0])
          stop_number: s
          nPassengers: stop.count_boarding
    # add the passengers to the stops as they arrive
    data_passenger_timing.forEach (psgr, p) ->
      adder_fn = () ->
        add_passenger_to_bus_stop(psgr)
        return true
      setTimeout(adder_fn, durationScale(psgr.time_appear))
      return

    # trigger the bus motion to the first stop
    move_bus(0)
    return

  return all_timers
