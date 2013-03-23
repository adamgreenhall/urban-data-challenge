window.translate = (x, y) ->
  "translate(#{x}, #{y})"


window.getRandomRange = (min, max) ->
  Math.random() * (max - min) + min
  
window.range = (end) ->
  array = new Array()
  i = 0

  while i < end
    array.push i
    i++
  array
  
window.nested_min_max = (data, nested_key, fn) -> 
  return [
    d3.min(data, (x) -> d3.min(x[nested_key], fn)),
    d3.max(data, (x) -> d3.max(x[nested_key], fn))
  ]


window.calcDistanceAlongPath = (points, path, Nsegments) ->
  Nsegments or= 1000
  # basic idea from: http://bl.ocks.org/duopixel/3824661

  pathLength = path.getTotalLength()
  BBox = path.getBBox()
  scale = pathLength / BBox.width
  
  segPoints = (path.getPointAtLength(pathLength / i) for i in [0...Nsegments])

  nearestNeighborIndex = (pt, points) ->
    dists = (Math.pow(pt.x - other.x, 2) + Math.pow(pt.y - other.y, 2) for other in points)
    return dists.indexOf(d3.min(dists))

  points.forEach (pt, i) ->
    pt.distance = nearestNeighborIndex(pt, segPoints) * pathLength / Nsegments
  
  # FIXME - still not quite working
  return points


d3.selection::moveToFront = ->
  @each ->
    @parentNode.appendChild this