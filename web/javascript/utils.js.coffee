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


window.get_path_distance = (path, x, y) ->
  pathLength = path.getTotalLength()
  BBox = path.getBBox()
  scale = pathLength / BBox.width
  
  # do a simple binary search to find the point on the line
  beginning = 0
  end = pathLength
  target = undefined
  loop
    target = Math.floor((beginning + end) / 2)
    pos = path.getPointAtLength(target)
    break  if (target is end or target is beginning) and pos.x isnt x
    if pos.x > x
      end = target
    else if pos.x < x
      beginning = target
    else #position found
      break
  return target