window.show_ts = (data) ->
  xVal = (d) -> d.distance
  tVal = (d) -> d.time
  rVal = (d) -> d.count  # passenger count
  
  margin =
    top: 20
    right: 20
    bottom: 20
    left: 20

  width = 600 - margin.left - margin.right
  height = 300 - margin.top - margin.bottom

  # takes timeseries data
  svg_route = d3.select('#route_vis').append('svg').attr
    width: width + margin.left + margin.right
    height: height + margin.top + margin.bottom
  
  g = svg_route.append("g").attr
    transform: translate(margin.left, margin.top)
  
  Tmax = 2000
  # the linear scale only works with UTC timestamps
  tScale = d3.scale.linear()
    .domain(d3.extent(data, tVal))
    .range([0, Tmax])
  
  xScale = d3.scale.linear()
    .domain(d3.extent(data, xVal))
    .range([0, width])
    
  rScale = d3.scale.linear()
    .domain(d3.extent(data, rVal))
    .range([3, 20])

    
  yPos = height / 2
  line = g.append("line").attr
    x1: xScale.range()[0]
    x2: xScale.range()[1]
    y1: yPos
    y2: yPos
    class: "bus-line"
      
  stops = g.selectAll("circle")
    .data(data).enter()
    .append("circle").attr
      class: "bus-stop"
      r: 3
      cx: (d) -> xScale(xVal(d))
      cy: yPos
  
  bus = g.append("circle").attr
    class: "bus"
    r: rScale(rVal(data[0]))
    cx: xScale(xVal(data[0]))
    cy: yPos
  
  

  trigger_event = (event_number) ->
    event_length = tScale(tVal(data[event_number]))
    bus.transition()
      .duration(event_length)
      .attr
        cx: xScale(xVal(data[event_number]))
        r: rScale(rVal(data[event_number]))
    
    # trigger next after transition is done
    timer_fn = () ->  
      if event_number < (data.length - 1)
        trigger_event(event_number + 1)
      else
        reset_to_beginning()
      return true
      
    d3.timer(timer_fn, event_length)
  

  reset_to_beginning = (reset_duration) ->
    reset_duration = reset_duration or 2000
  
    fade_end_fn = () ->
      # reset the position to t0
      bus.attr "cx", xScale(xVal(data[0]))
    
      # fade the bus back in
      bus.transition()
        .duration(reset_duration / 5)
        .style("fill-opacity", 0.8)
    
    bus.transition()
      .duration(reset_duration * 4 / 5)
      .style("fill-opacity", 0)
      .each("end", fade_end_fn)  # at the end of the fade out
    
    # after the transition back to t0
    restart_fn = () ->
      # re-trigger the first event
      trigger_event(0)
      return true      
    d3.timer(restart_fn, reset_duration)


  # start things moving
  trigger_event(0)
