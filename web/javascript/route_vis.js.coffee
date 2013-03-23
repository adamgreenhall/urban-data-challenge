window.show_ts = (error, data_daily_trips, data_stop_locations, map) ->
  if error
    console.log(error.statusText)
    # TODO - warn user
    return
  xVal = (d) -> d.distance
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
  xScale = d3.scale.linear()
    .domain(nested_min_max(data_daily_trips, 'stops', xVal))
    .range([margin.left, width - margin.right])
  yScale = d3.scale.linear()
    .domain([0, 1])
    .range([height - margin.top, 0 + margin.bottom])
  rScale = d3.scale.linear()
    .domain(nested_min_max(data_daily_trips, 'stops', rVal))
    .range([3, 20])

  
  yPos = yScale(0.5)
  yPosPassengers = yScale(0.4)
  color_filler = d3.scale.category20()
  
  # setup the route line and stops
  line_maker = d3.svg.line()
    .x((d) -> d)
    .y((d) -> yPos)
  line = g.append("path")
    .datum(xScale.range())
    .attr
      d: line_maker
    class: "bus-line"
      
  ## PENDING - try to measure the stop distances in d3
  ## see: http://bl.ocks.org/duopixel/3824661
  # route_path = d3.select("path.bus-route-#{data_daily_trips[0].id_route}").node()
  # 
  # id_stops = data_daily_trips[0].stops.map((d) -> d.id_stop)
  # stop_distances = {}
  # 
  # id_stops.forEach (sid, i) ->
  #   circ = d3.select('circle.bus-stop-'+sid)
  #   stop_distances[sid] = get_path_distance(route_path, circ.attr('cx'), circ.attr('cy'))
  # debugger

  # FIXME!! - routes are bidirectional!!!!!
  # TODO - need a unique list of stops over all the trips, not just the first trip

  # all_stops = _.flatten data_daily_trips.map (d) ->
  #   d.stops.map (s) ->
  #     id_stop: s.id_stop
  #     distance: s.distance
  # 
  # all_stop_ids = _.unique(all_stops.map (s) -> s.id_stop)

  all_stops_data = data_daily_trips[0].stops.map (d) -> 
    distance: d.distance
    id_stop: d.id_stop
    
  debugger
  stops = g.selectAll("circle.bus-stop")
    .data(all_stops_data).enter()
    .append("circle").attr
      class: (d) -> "bus-stop bus-stop-#{d.id_stop}"
      r: 4
      cx: (d) -> xScale(xVal(d))
      cy: yPos
        
  # basic force layout
  force_layout = () -> 
    d3.layout.force()
      .links([])
      .gravity(0)
      .friction(0.2)
      .charge(-80)
      .size([svg_route.width, svg_route.height])

  # create timers to start each bus trip 
  data_daily_trips.forEach (data_trip, i) ->  
    data_trip.Tstart = tScale(d3.min(data_trip.stops, tVal))
    
    # debugging HACK
    # return unless i<=1
    
    # TODO - might need to use setInterval, clearInterval to be able to cancel these 
    start_trip = () -> begin_bus_trip(data_trip)
    d3.timer(start_trip, data_trip.Tstart)

  
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
      class: "bus-" + data_trip.id_trip
      r: rScale(rVal(data_stops[0]))
      cx: xScale(xVal(data_stops[0]))
      cy: yPos

    # setup the force layout for the people moving to the bus stops
    data_passengers = []
    passenger_circles = g.selectAll("circle.passenger-#{id_trip}")

    tick_fn = (e) ->
      # Push nodes toward their designated focus.
      k = .9 * e.alpha
      data_passengers.forEach (o, i) ->
        o.x += (xScale(xVal(data_stops[o.stop_number])) - o.x) * k
        o.y += (yPosPassengers - o.y) * k
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
          cy: yPos
      drop_circles = () ->
        passenger_circles.exit().remove()
        return true
      d3.timer(drop_circles, boarding_duration)
      
      force.start()
      return
  
    add_passenger_to_bus_stop = (stop_number) -> 
      return if current_bus_stop >= data_stops.length - 1
      data_passengers.push 
        stop_number: stop_number
        id_trip: id_trip
        # centered horizontally on the foci, but with some scatter to either side 
        x: xScale(xVal(data_stops[stop_number])) + (Math.random() - 0.5) * width / data_stops.length
        y: getRandomRange(yScale(0.25), yScale(0.75))
    
      redraw_passengers()

  
    show_departing_passengers = (stop_number) ->
      stop = data_stops[stop_number]
    
      departing_data = ({
        xEnd: xScale(xVal(stop)) + (Math.random() - 0.5) * width / data_stops.length,
        yEnd: Math.random() * height
        } for i in range(stop.count_exiting))
    
      # return if stop.count_exiting == 0
      departing_passengers = g.selectAll("circle.passenger-departing-#{id_trip}-#{stop_number}")
        .data(departing_data) 
        .enter().append('circle')
      departing_passengers.attr
          class: "passenger-departing passenger-departing-#{id_trip}-#{stop_number}"
          cx: xScale(xVal(stop))
          cy: yPos
          r: 3
        .style
          fill: color_filler(stop_number)
          stroke: d3.rgb(color_filler(stop_number)).darker(2)
          "stroke-width": 1.5        
      departing_passengers.style
          fill: color_filler(stop_number)
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
      d3.timer(drop_data, duration)
    
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
            move_bus(stop_number + 1)
            return true
          d3.timer(move_to_next_fn, duration_stopped)
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
          
        return true
      
      d3.timer(arrival_fn, duration_motion)
  

    # set up the passenger arrival timing
    data_passenger_timing = []
    data_stops.forEach (stop, s) ->
      range(stop.count_boarding).forEach (el, i) -> 
        # TODO make the passenger more likely to get to stop just before bus arrives
        # currently equally likely that passeger arrives while 
        # bus is anywhere between 5 and 1 stop away
        if s > 5
          tPrev = tVal(data_stops[s - 5])
        else
          tPrev = tVal(data_stops[0])
        data_passenger_timing.push
          time_appear: getRandomRange(tVal(stop), tPrev) - tVal(data_stops[0])
          stop_number: s
          
    # add the passengers to the stops as they arrive
    data_passenger_timing.forEach (psgr, p) ->
      adder_fn = () ->
        add_passenger_to_bus_stop(psgr.stop_number)
        return true
      d3.timer(adder_fn, durationScale(psgr.time_appear))
      return

    # trigger the bus motion to the first stop
    move_bus(0)
    
    return true
