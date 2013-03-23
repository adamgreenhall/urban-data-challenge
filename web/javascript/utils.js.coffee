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
  
window.unique = (array) ->
  o = {}
  i = undefined
  l = @length
  r = []
  i = 0
  while i < l
    o[array[i]] = array[i]
    i += 1
  for i of o
    r.push o[i]
  return r