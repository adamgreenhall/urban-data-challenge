window.show_ts = (error, data_daily_trips, data_stop_locations, map) ->
  if error
    console.log(error.statusText)
    # TODO - warn user
    return
  tVal = (d) -> d.time_arrival
  tDepartureVal = (d) -> d.time_departure
  rVal = (d) -> d.count  # passenger count
  
  time_formatter = (t) ->
    d3.time.format('%I:%M%p on a %A ')(new Date(t * 1000))
  # setup container
  margin =
    top: 20
    right: 20
    bottom: 20
    left: 20
  width = 1200 - margin.left - margin.right
  height = 300 - margin.top - margin.bottom
  svg_route = d3.select('#route_vis').append('svg').attr
    width: width + margin.left + margin.right
    height: height + margin.top + margin.bottom
  g = svg_route.append("g").attr
    transform: translate(margin.left, margin.top)
  
  time_display = d3.select('#time_display')
  
  # a linear scale mapping the time difference (in UTC seconds)
  # to the length of the visualization playback (Tmax)
  Tmax = 5 * 60 * 1000  # 5min
  tScale = d3.scale.linear()
    .domain(nested_min_max(data_daily_trips, 'stops', tVal))
    .range([0, Tmax])
  yScale = d3.scale.linear()
    .domain([0, 1])
    .range([height - margin.top, 0 + margin.bottom])
  rScale = d3.scale.linear()
    .domain(nested_min_max(data_daily_trips, 'stops', rVal))
    .range([3, 20])

  
  yPos = yScale(0.5)
  yPosPassengers = yScale(0.4)
  yValBus = (dir) ->
    if dir then 0.45 else 0.55
  yPosPassengers = (dir) -> 
    if dir then yScale(0.38) else yScale(0.62)
  randomYpos = (trip_direction) ->
    # inbound enters/exits below, outbound enters/exits above
    if trip_direction
      yScale(getRandomRange(0, yValBus(trip_direction)))
    else
      yScale(getRandomRange(yValBus(trip_direction), 1))
            
  color_filler = d3.scale.category20()
  
  # setup the route line and stops
  line_maker = d3.svg.line()
    .x((d) -> d)
    .y((d) -> yPos)
      
  # FIXME!! - routes are bidirectional!!!!!

  # measure the stop distances in d3
  all_stop_ids = _.unique _.flatten data_daily_trips.map (d) ->
    d.stops.map (s) -> s.id_stop
  
  data_stop_positions = {}
  all_stop_ids.forEach (sid, i) ->
    circ = d3.select("circle.bus-stop-#{sid}")
    data_stop_positions[sid] = 
      id_stop: sid
      x: +circ.attr('cx') 
      y: +circ.attr('cy')
    return
  
  route_path = d3.select("path.bus-route-#{data_daily_trips[0].id_route}").node()
  calcDistanceAlongPath(d3.values(data_stop_positions), route_path)
  
  # define xVal to lookup the distance from the stops data
  xVal = (d) -> 
    data_stop_positions[d.id_stop].distance
  xScale = d3.scale.linear()
    .domain(d3.extent(d3.values(data_stop_positions), (d) -> d.distance))
    .range([margin.left, width - margin.right])


    
  stops = g.selectAll("circle.bus-stop")
    .data(d3.values(data_stop_positions)).enter()
    .append("circle").attr
      class: (d) -> "bus-stop bus-stop-#{d.id_stop}"
      r: 4
      cx: (d) -> xScale(d.distance)
      cy: yPos

  # add mouse interaction 
  vis_highlight_stop = (d) -> 
    map._g.select("circle.bus-stop-#{d.id_stop}")
      .moveToFront()
      .classed('highlighted', true)
      .transition()
        .attr('r', map.busStopRadius * 3)


      
  vis_unhighlight_stop = (d) ->
    map._g.select("circle.bus-stop-#{d.id_stop}")
      .classed('highlighted', false)
      .transition()
        .attr('r', map.busStopRadius)


  stops
    .on('mouseover', vis_highlight_stop)
    .on('mouseout', vis_unhighlight_stop)
    
  line = g.append("path")
    .datum(xScale.range())
    .attr
      d: line_maker
      class: "bus-line"

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
  data_daily_trips.forEach (data_trip, i) ->  
    data_trip.Tstart = tScale(d3.min(data_trip.stops, tVal))
    
    # debugging HACK - only run 2 trips
    # return unless i<=1
    
    # TODO - make sure the cancelling the timers is working 
    start_trip = () -> begin_bus_trip(data_trip)
    map.visTimers.push(setTimeout(start_trip, data_trip.Tstart))

  
  begin_bus_trip = (data_trip) ->
    id_trip = data_trip.id_trip
    console.log('begin trip ', id_trip)
    # console.log(data_trip.stops)
    data_stops = data_trip.stops
    current_bus_stop = 0
    # if departure time is not defined, the default is 30 seconds after arrival
    data_stops.forEach (d, i) -> 
      d.time_departure or= tVal(d) + 30
      return
      
    durationScale = d3.scale.linear()
      .domain([0, d3.max(data_stops, tVal) - d3.min(data_stops, tVal)])
      .range([0, tScale(d3.max(data_stops, tVal)) - tScale(d3.min(data_stops, tVal))])
          
    bus = g.append("circle").attr
      class: "bus bus-" + data_trip.id_trip
      r: rScale(rVal(data_stops[0]))
      cx: xScale(xVal(data_stops[0]))
      cy: yScale(yValBus(data_trip.trip_direction))

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
      boarding_duration or= 500  # ms
      force.nodes(data_passengers)
      passenger_circles = passenger_circles.data(force.nodes(), (d) -> d.index)
      passenger_circles.enter()
        .append("circle").attr
          class: "passenger passenger-#{id_trip}"
          cx: (d) -> d.x
          cx: (d) -> d.y
          r: 3
        .style
          fill: (d) -> color_filler(d.stop_number)
          stroke: (d) -> d3.rgb(color_filler(d.stop_number)).darker(2)
          "stroke-width": 1.5
        .call(force.drag)

      passenger_circles.exit()
        .transition(boarding_duration)
        .attr
          cx: (d) -> xScale(xVal(data_stops[d.stop_number]))
          cy: randomYpos(data_trip.trip_direction)
      drop_circles = () -> passenger_circles.exit().remove()
      setTimeout(drop_circles, boarding_duration)
      
      force.start()
      return
  
    add_passenger_to_bus_stop = (stop_number) -> 
      return if current_bus_stop >= data_stops.length - 1
      data_passengers.push 
        stop_number: stop_number
        id_trip: id_trip
        # centered horizontally on the foci, but with some scatter to either side 
        x: xScale(xVal(data_stops[stop_number])) + (Math.random() - 0.5) * width / data_stops.length
        y: randomYpos(data_trip.trip_direction)
    
      redraw_passengers()

  
    show_departing_passengers = (stop_number) ->
      stop = data_stops[stop_number]
    
      departing_data = ({
        xEnd: xScale(xVal(stop)) + (Math.random() - 0.5) * width / data_stops.length,
        yEnd: randomYpos(data_trip.trip_direction)
        } for i in range(stop.count_exiting))
    
      # return if stop.count_exiting == 0
      departing_passengers = g.selectAll("circle.passenger-departing-#{id_trip}-#{stop_number}")
        .data(departing_data)
        .enter().append('circle')
      departing_passengers.attr
          class: "passenger-departing passenger-departing-#{id_trip}-#{stop_number}"
          cx: xScale(xVal(stop))
          cy: yScale(yValBus(data_trip.trip_direction))
          r: 3
        .style
          fill: color_filler(stop_number)
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
    
    show_boarding_passengers = (stop_number, duration_boarding) ->
      # show the people to getting onto the bus
      return unless data_passengers.length > 0
      data_passengers = data_passengers.filter((p) -> p.stop_number != stop_number)
      # redraw the force layout without this stop's people
      redraw_passengers(duration_boarding)
      return

    move_bus = (stop_number) ->
      current_bus_stop = stop_number
      if stop_number == 0
        duration_motion = 50  # can't be zero, because d3 timer events take up to 10ms to fire
        duration_stopped = 50
      else
        # transition duration is the difference between prev. stop departure time and arrival
        duration_motion = durationScale( tVal(data_stops[stop_number]) - tDepartureVal(data_stops[stop_number - 1]) )
        duration_stopped = durationScale( tDepartureVal(data_stops[stop_number]) - tVal(data_stops[stop_number]) )

      # move bus to the current stop
      bus.transition()
        .duration(duration_motion)
        .attr
          cx: xScale(xVal(data_stops[stop_number]))
    

      arrival_fn = () ->  
        # upon arrival at stop
        if stop_number < (data_stops.length - 1)
          # update the clock display
          time_display.text(time_formatter(tVal(data_stops[stop_number])))
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
              r: rScale(rVal(data_stops[stop_number]))
        
          # pause for the time the bus spends at the stop.
          # and then move the bus to the next stop
          move_to_next_fn = () ->
            vis_unhighlight_stop(data_stops[stop_number])
            move_bus(stop_number + 1)
            return
          setTimeout(move_to_next_fn, duration_stopped)
        else
          # done with trip
          bus.remove() 
          # remove all passengers, if any left waiting
          remaining = d3.selectAll("circle.passenger-#{id_trip}")
          if passenger_circles[0].length == 0 and remaining[0].length > 0
            console.log('WARNING: remaining not all in passenger circles')
          if remaining[0].length > 0
            console.log("removing #{remaining[0].length} left behind passengers for #{id_trip}")
            remaining.remove()
          
        return
      
      setTimeout(arrival_fn, duration_motion)
  

    # set up the passenger arrival timing
    data_passenger_timing = []
    data_stops.forEach (stop, s) ->
      range(stop.count_boarding).forEach (el, i) -> 
        # TODO make the passenger more likely to get to stop just before bus arrives
        # currently equally likely that passeger arrives while 
        # bus is anywhere between 5 stops away and Tarrival - 30sec
        if s > 5
          tPrev = tVal(data_stops[s - 5])
        else
          tPrev = tVal(data_stops[0])
        data_passenger_timing.push
          time_appear: getRandomRange(tPrev, tVal(stop) - 30) - tVal(data_stops[0])
          stop_number: s
    # add the passengers to the stops as they arrive
    data_passenger_timing.forEach (psgr, p) ->
      adder_fn = () ->
        add_passenger_to_bus_stop(psgr.stop_number)
        return true
      # FIXME - this seems to be leaving passengers behind
      # try using a d3 timer  -- setTimeout is too slow???
      d3.timer(adder_fn, durationScale(psgr.time_appear))
      return

    # trigger the bus motion to the first stop
    move_bus(0)
    return

  return all_timers
