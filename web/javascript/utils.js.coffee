window.translate = (x, y) ->
  "translate(" + x + "," + y + ")"


window.getRandomInt = (min, max) ->
  Math.floor(Math.random() * (max - min + 1)) + min
  
window.range = (end) ->
  array = new Array()
  i = 0

  while i < end
    array.push i
    i++
  array