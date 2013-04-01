class LeafletMap
  CITY_CENTER =
    "san-francisco": [37.783333, -122.416667]
    geneva: [46.2, 6.15]
    zurich: [47.366667, 8.55]

  constructor: (@mapContainerId, @city) ->
    @_generateMap()
    @_generateSvg()
    @_generateMapData()

    @_loadData()
    @busStopRadius = 3
    @currentRouteID = null
    
  # Convert back to lat-long coordinates
  projection: (x) ->
    point = @_map.latLngToLayerPoint(new L.LatLng(x[1], x[0]))
    [point.x, point.y]

  getWidth: ->
    $('#' + @mapContainerId).width()    
  getHeight: ->
    $('#' + @mapContainerId).height()

  redraw: ->
    return if @_bounds is `undefined`

    bottomLeft = @projection(@_bounds[0])
    topRight   = @projection(@_bounds[1])

    @_svgMap
      .attr
        width:  topRight[0] - bottomLeft[0]
        height: bottomLeft[1] - topRight[1]
      .style
        "margin-left": "#{bottomLeft[0]}px"
        "margin-top":  "#{topRight[1]}px"


    @g.attr("transform", translate(-bottomLeft[0], -topRight[1]))

    if @_busStops isnt `undefined`
      @_busStops.attr
        cx: (d, i) => @projection(@_stopCoordinates[i])[0]
        cy: (d, i) => @projection(@_stopCoordinates[i])[1]

    if @_busRoutes isnt `undefined`
      @_busRoutes.attr("d", @_path)

    return
      
  
  _generateMap: ->   
    @_map = L.map(@mapContainerId, {
      center: CITY_CENTER[@city],
      zoom:   13
      zoomControl: false}).addLayer(new L.tileLayer("http://{s}.tile.cloudmade.com/62541519723e4a6abd36d8a4bb4d6ac3/998/256/{z}/{x}/{y}.png", {
        attribution: "",
        maxZoom: 16,
    }))

    @_layerControl = new L.Control.Zoom({ position: 'bottomleft' })
    @_layerControl.addTo(@_map)
    
    d3.select('.leaflet-control-attribution').remove()
    return

  _generateSvg: ->
    __this = @
    @_svgMap     = d3.select(@_map.getPanes().overlayPane).append("svg")
    @g          = @_svgMap.append("g").attr("class", "leaflet-zoom-hide")
    @_path       = d3.geo.path().projection((x) -> __this.projection(x))
    @_tooltip    = d3.select("#tooltip")
    return

  _colorScale: (d) ->
    if @__colorScale is `undefined`
      @__colorScale = d3.scale.category20()

    @__colorScale(d)

  _generateMapData: ->
    @_busRoutes       = `undefined`
    @_busStops        = `undefined`
    @_stopCoordinates = `undefined`
    @_bounds          = `undefined`
    @_remoteRequests  = []
    @visTimers = []
    return

  _busStopMouseover: (elem, d) ->
    dot = d3.select(elem)
    dot.attr("r", 10).classed("hover", true)
    xPosition = parseFloat(dot.attr("cx"))
    yPosition = parseFloat(dot.attr("cy"))
    @_tooltip.style
      left: (xPosition + 10) + "px"
      top: (yPosition + 10) + "px"
    @_tooltip.select(".route-name").text(d.properties.name_route)
    @_tooltip.select(".stop-name").text(d.properties.name_stop)
    @_tooltip.classed("hidden", false)

  _busStopMouseout: (elem, d) ->
    d3.select(elem).attr("r", 5).classed "hover", false
    @_tooltip.classed "hidden", true

  _routeMouseover: (elem, d) ->
    route = d3.select(elem)
    route.classed "highlighted", true

  _routeMouseout: (elem, d) ->
    route = d3.select(elem)
    route.classed "highlighted", false

  cancelOtherVis: () =>
    # stop loading any other route data
    req.abort() for req in @_remoteRequests
    # cancel the timers from existing visualizations
    clearTimeout(timerId) for timerId in @visTimers
    @_remoteRequests = []
    @visTimers = []

    # clear out any existing visualizations
    d3.selectAll('#route_vis > svg').remove()
  
    #unhighight stops
    @g.selectAll("circle.bus-stop")
      .classed('highlighted', false)
    
  
  newRouteVis: (filename) =>
    self = @
    console.log('loading', filename)
    
    call_ts_vis = (error, data) -> show_ts(error, data, self)
    @_remoteRequests.push(d3.json(filename, call_ts_vis))

  dateChange: () =>
    __this = @
    @cancelOtherVis()
    
    date = $('select#weekday option:selected').val()    
    filename = "/data/#{@city}/timeseries/#{date}_#{@currentRouteID}.json"
    @newRouteVis(filename)

  _routeClick: (elem, d) =>
    __this = @
    route = d3.select(elem)
    id_route = d.properties.id_route
    @currentRouteID = id_route
    d3.selectAll('#route_name').text(toTitleCase(d.properties.name_route))

    @cancelOtherVis()

    # load up the timeseries data for the route
    # TODO - date picker
    date = $('select#weekday option:selected').val()    
    filename = "/data/#{@city}/timeseries/#{date}_#{id_route}.json"
    @newRouteVis(filename)      

  _loadData: ->
    d3.json "/data/#{@city}/stops.json", (stops) =>
      __this = @
      @_stopCoordinates = topojson.object(stops,
        type: "MultiPoint"
        coordinates: stops.objects.stops.geometries.map((d) -> d.coordinates)
      ).coordinates

      @_busStops = @g.selectAll("circle.bus-stop")
        .data(stops.objects.stops.geometries).enter()
        .append("circle")
          .attr
            r: @busStopRadius
            class: (d) -> "bus-stop bus-stop-#{d.properties.id_stop}"
          .on("mouseover", (d) -> __this._busStopMouseover(this, d))
          .on("mouseout",  (d) -> __this._busStopMouseout(this, d))

      @_bounds = [
        [
          d3.min(@_stopCoordinates, (d) -> d[0]),
          d3.min(@_stopCoordinates, (d) -> d[1])
        ],
        [
          d3.max(@_stopCoordinates, (d) -> d[0]),
          d3.max(@_stopCoordinates, (d) -> d[1])
        ]
      ]

      @_map.on("viewreset", () -> __this.redraw())
      @redraw()
      
      d3.json "/data/#{@city}/routes.json", (routes) =>
        @_busRoutes = @g.selectAll("path.bus-route")
          .data(topojson.object(routes, routes.objects.routes).geometries).enter()
          .append("path").attr(
            class: (d) -> "bus-route bus-route-#{d.properties.id_route}"
            d: @_path
          )
            .style("stroke", (d) -> __this._colorScale(d.properties.id_route))
            .on("mouseover", (d) -> __this._routeMouseover(this, d))
            .on("mouseout", (d) -> __this._routeMouseout(this, d))
            .on("click", (d) -> __this._routeClick(this, d))
            
        # set up a date picker 
        $('select#weekday').change(@dateChange)
        # start the thing off with a default route
        @_routeClick(null, routes.objects.routes.geometries[0])
        return
      return

new LeafletMap "map", window.city_name
