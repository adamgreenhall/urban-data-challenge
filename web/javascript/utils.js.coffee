window.translate = (x, y) ->
  "translate(" + x + "," + y + ")"


window.getRandomInt = (min, max) ->
  Math.floor(Math.random() * (max - min + 1)) + min