window.translate = (x, y) ->
  "translate(" + x + "," + y + ")"


window.getRandomRange = (min, max) ->
  Math.random() * (max - min) + min
  
window.range = (end) ->
  array = new Array()
  i = 0

  while i < end
    array.push i
    i++
  array