window.show_ts = (error, data_daily) ->
  if error
    console.log(error.statusText)
    # TODO - warn user
    return

  xVal = (d) -> d.distance
  tVal = (d) -> d.time_arrival
  tDepartureVal = (d) -> d.time_departure
  rVal = (d) -> d.count  # passenger count
  
  margin =
    top: 20
    right: 20
    bottom: 20
    left: 20

  width = 1200 - margin.left - margin.right
  height = 300 - margin.top - margin.bottom
  bus_color = 'steel-blue'

  # HACK
  # TODO - add time selection and multple buses on the same line
  data_stops = data_daily[0].stops
  console.log(data_stops)
  
  # if departure time is not defined, the default is 30 seconds after arrival
  d.time_departure or= tVal(d) + 30 for d in data_stops


  svg_route = d3.select('#route_vis').append('svg').attr
    width: width + margin.left + margin.right
    height: height + margin.top + margin.bottom
  
  g = svg_route.append("g").attr
    transform: translate(margin.left, margin.top)
  
  Tmax = 20000
  # a linear scale mapping the time difference (in UTC seconds)
  # to the length of the visualization playback (2sec)
  
  tScale = d3.scale.linear()
    .domain([0, d3.max(data_stops, tVal) - d3.min(data_stops, tVal)])
    .range([0, Tmax])
  
  xScale = d3.scale.linear()
    .domain(d3.extent(data_stops, xVal))
    .range([0, width])
    
  rScale = d3.scale.linear()
    .domain(d3.extent(data_stops, rVal))
    .range([3, 20])

    
  yPos = height / 2
  line = g.append("line").attr
    x1: xScale.range()[0]
    x2: xScale.range()[1]
    y1: yPos
    y2: yPos
    class: "bus-line"
      
  stops = g.selectAll("circle")
    .data(data_stops).enter()
    .append("circle").attr
      class: "bus-stop"
      r: 3
      cx: (d) -> xScale(xVal(d))
      cy: yPos
  
  
  
  bus = g.append("circle").attr
    class: "bus"
    r: rScale(rVal(data_stops[0]))
    cx: xScale(xVal(data_stops[0]))
    cy: yPos

  # setup the force layout for the people moving to the bus stops
  data_passengers = []
  passenger_circles = g.selectAll("circle.passenger")

  tick_fn = (e) ->
    # Push nodes toward their designated focus.
    k = .9 * e.alpha
    data_passengers.forEach (o, i) ->
      o.x += (xScale(xVal(data_stops[o.stop_number])) - o.x) * k
      o.y += (yPos - o.y) * k
    passenger_circles.attr
      cx: (d) -> d.x
      cy: (d) -> d.y
    return
      
  force = d3.layout.force()
    .nodes(data_passengers)
    .links([])
    .gravity(0)
    .friction(0.2)
    .charge(-80)
    .size([svg_route.width, svg_route.height])
    .on('tick', tick_fn)
    



  
  
  color_filler = d3.scale.category20()
  
  current_bus_stop = 0

  redraw_passengers = (boarding_duration) ->
    boarding_duration or= 500  # ms
    force.nodes(data_passengers)
    passenger_circles = passenger_circles.data(force.nodes(), (d) -> d.index)
    passenger_circles.enter()
      .append("circle").attr
        class: "passenger"
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
      return
    d3.timer(drop_circles, boarding_duration)
      
    force.start()
    return
  
  add_passenger_to_bus_stop = (stop_number) -> 
    return if current_bus_stop >= data_stops.length - 1
    data_passengers.push 
      stop_number: stop_number
      # centered horizontally on the foci, but with some scatter to either side 
      x: xScale(xVal(data_stops[stop_number])) + (Math.random() - 0.5) * width / data_stops.length
      y: getRandomRange(yPos - height/4, yPos + height/4)
    
    redraw_passengers()

  
  show_departing_passengers = (stop_number) ->
    stop = data_stops[stop_number]
    
    departing_data = ({
      xEnd: xScale(xVal(stop)) + (Math.random() - 0.5) * width / data_stops.length,
      yEnd: Math.random() * height
      } for i in range(stop.count_exiting))
    
    # return if stop.count_exiting == 0
    departing_passengers = g.selectAll('circle.passenger-departing-' + stop_number)
      .data(departing_data) 
      .enter().append('circle')
    departing_passengers.attr
        class: 'passenger-departing-' + stop_number
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
    duration = tScale(tDepartureVal(stop) - tVal(stop)) + 1000
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
    # TODO - transition the people to get onto the bus
    if data_passengers.length > 0
      data_passengers = data_passengers.filter((p) -> p.stop_number != stop_number)
      # redraw the force layout without this stop's people
      redraw_passengers(duration_boarding)
      return

  move_bus = (stop_number) ->
    current_bus_stop = stop_number
    if stop_number == 0
      duration_motion = 0
      duration_stopped = 0
    else
      # transition duration is the difference between prev. stop departure time and arrival
      duration_motion = tScale( tVal(data_stops[stop_number]) - tDepartureVal(data_stops[stop_number - 1]) )
      duration_stopped = tScale( tDepartureVal(data_stops[stop_number]) - tVal(data_stops[stop_number]) )
      
    # move bus to 
    bus.transition()
      .duration(duration_motion)
      .attr
        cx: xScale(xVal(data_stops[stop_number]))
        r: rScale(rVal(data_stops[stop_number]))
    
    # after transition to the stop is done
    timer_fn = () ->  
      if stop_number < (data_stops.length - 1)
        # passengers get out
        show_departing_passengers(stop_number)
        
        # passengers get on
        show_boarding_passengers(stop_number, duration_stopped)
        
        # pause for the time the bus spends at the stop.
        # and then move the bus to the next stop
        move_fn = () ->
          move_bus(stop_number + 1)
          return true
        d3.timer(move_fn, 
          tScale( tDepartureVal(data_stops[stop_number]) - tVal(data_stops[stop_number]) ))
      else
        reset_to_beginning()
      return true
      
    d3.timer(timer_fn, duration_motion)
  

  reset_to_beginning = (reset_duration) ->
    reset_duration = reset_duration or 2000
    
    # clearInterval(passenger_adder) # HACK - clear out passengers
    
    
    fade_end_fn = () ->
      # reset the position to t0
      bus.attr "cx", xScale(xVal(data_stops[0]))
    
      # fade the bus back in
      bus.transition()
        .duration(reset_duration / 5)
        .style("fill-opacity", 0.8)
    
    bus.transition()
      .duration(reset_duration * 4 / 5)
      .style("fill-opacity", 0)
      .each("end", fade_end_fn)  # at the end of the fade out
    
    d3.timer(starter_fn, reset_duration)

  # after the transition back to t0
  starter_fn = () ->
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
      d3.timer(adder_fn, tScale(psgr.time_appear))
      return
    # re-trigger the first event
    move_bus(0)
    return true      


  # start the bus moving
  starter_fn()
  return
