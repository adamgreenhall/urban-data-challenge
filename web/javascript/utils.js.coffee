window.translate = (x, y) ->
  "translate(#{x}, #{y})"


window.getRandomRange = (min, max) ->
  Math.random() * (max - min) + min
    
window.nested_min_max = (data, nested_key, fn) -> 
  return [
    d3.min(data, (x) -> d3.min(x[nested_key], fn)),
    d3.max(data, (x) -> d3.max(x[nested_key], fn))
  ]


window.calcDistanceAlongPath = (points, path, Nsegments) ->
  Nsegments or= 5000
  # basic idea from: http://bl.ocks.org/duopixel/3824661

  pathLength = path.getTotalLength()
  BBox = path.getBBox()
  segPoints = (path.getPointAtLength(pathLength * i / Nsegments) for i in [1...Nsegments])

  # HACK - probably could use a real projection instead, but this seems to 
  # work for relatively straight routes
  # 
  # multi line strings may not have the most logical ordering of their segments
  # so here we sort them by their larger axis direction (x or y)
  if BBox.width > BBox.height
    # sort primarily by x
    segPoints.sort( (a, b) -> d3.ascending(a.x  + 0.1 * a.y, b.x + 0.1 * b.y))
  else
    #sort primarily by y
    segPoints.sort( (a, b) -> d3.ascending(0.1 * a.x  + a.y, 0.1 * b.x + b.y))
    
  nearestNeighborIndex = (pt, points) ->
    dists = (Math.pow(pt.x - other.x, 2) + Math.pow(pt.y - other.y, 2) for other in points)
    return dists.indexOf(d3.min(dists))

  points.forEach (pt, i) ->
    idx = nearestNeighborIndex(pt, segPoints)
    pt.distance =  pathLength * idx / Nsegments
  
  return points

window.toTitleCase = (str) ->
  str.replace /\w\S*/g, (txt) ->
    txt.charAt(0).toUpperCase() + txt.substr(1).toLowerCase()

d3.selection::moveToFront = ->
  @each ->
    @parentNode.appendChild this
