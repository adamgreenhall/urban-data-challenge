# define the city 
city = "san-francisco"


projection = (x) ->
  # convert back to lat-long coordinates
  pt = map.latLngToLayerPoint(new L.LatLng(x[1], x[0]))
  return [pt.x, pt.y]

translate = (x, y) ->
  "translate(" + x + "," + y + ")"

map_redraw = ->
  # redraw the d3 objects on the map on zoom/pan
  return if bounds is `undefined`
  bottomLeft = projection(bounds[0])
  topRight = projection(bounds[1])
  svg
    .attr
      width: topRight[0] - bottomLeft[0]
      height: bottomLeft[1] - topRight[1]
    .style
      "margin-left": bottomLeft[0] + "px"
      "margin-top": topRight[1] + "px"
      
  g.attr("transform", translate(-bottomLeft[0], -topRight[1]))
  
  if bus_stops isnt `undefined`
    bus_stops.attr
      cx: (d, i) -> projection(stop_coordinates[i])[0]
      cy: (d, i) -> projection(stop_coordinates[i])[1]

  if bus_routes isnt `undefined`
    bus_routes.attr("d", path)


bus_stop_mouseover = (d) ->
    dot = d3.select(this)
    dot.attr("r", 10).classed("hover", true)
    xPosition = parseFloat(dot.attr("cx"))
    yPosition = parseFloat(dot.attr("cy"))
    tooltip.style
      left: (xPosition + 10) + "px"
      top: (yPosition + 10) + "px"
    tooltip.select(".route-name").text(d.properties.name_route)
    tooltip.select(".stop-name").text(d.properties.name_stop)
    tooltip.classed("hidden", false)

bus_stop_mouseout = (d) ->
    d3.select(this).attr("r", 5).classed "hover", false
    tooltip.classed "hidden", true
  
route_mouseover = (d) ->
  route = d3.select(this)
  route.classed "highlighted", true

route_mouseout = (d) ->      
  route = d3.select(this)
  route.classed "highlighted", false
  

centers =
  "san-francisco": [37.783333, -122.416667]
  geneva: [46.2, 6.15]
  zurich: [47.366667, 8.55]


# set up the leaflet map
map = L.map("map", {
  center: centers[city],
  zoom: 12})
  .addLayer(new L.tileLayer("http://{s}.tile.cloudmade.com/62541519723e4a6abd36d8a4bb4d6ac3/998/256/{z}/{x}/{y}.png", {
    attribution: "",
    maxZoom: 16
  }))
  
svg = d3.select(map.getPanes().overlayPane).append("svg")
g = svg.append("g").attr("class", "leaflet-zoom-hide")
path = d3.geo.path().projection(projection)
tooltip = d3.select("#tooltip")


bus_routes = `undefined`
bus_stops = `undefined`
stop_coordinates = `undefined`
bounds = `undefined`


d3.json "/data/" + city + "/stops.json", (stops) ->
  stop_coordinates = topojson.object(stops,
    type: "MultiPoint"
    coordinates: stops.objects.stops.geometries.map((d) -> d.coordinates)
  ).coordinates
  
  bus_stops = g.selectAll("circle")
    .data(stops.objects.stops.geometries).enter()
    .append("circle")
      .attr("r", 3)
      .on("mouseover", bus_stop_mouseover)
      .on("mouseout", bus_stop_mouseout)
  
  bounds = [
    [
      d3.min(stop_coordinates, (d) -> d[0]),
      d3.min(stop_coordinates, (d) -> d[1])
    ],
    [
      d3.max(stop_coordinates, (d) -> d[0]),
      d3.max(stop_coordinates, (d) -> d[1])
    ]
  ]

  map.on("viewreset", map_redraw)
  map_redraw()
  
  d3.json "/data/" + city + "/routes.json", (routes) ->
    bus_routes = g.selectAll("path.bus-route")
      .data(topojson.object(routes, routes.objects.routes).geometries).enter()
      .append("path").attr(
        class: "bus-route"
        d: path
      )
      .on("mouseover", route_mouseover)
      .on("mouseout", route_mouseout)