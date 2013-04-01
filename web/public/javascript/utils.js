(function() {
  window.translate = function(x, y) {
    return "translate(" + x + ", " + y + ")";
  };

  window.getRandomRange = function(min, max) {
    return Math.random() * (max - min) + min;
  };

  window.nested_min_max = function(data, nested_key, fn) {
    return [
      d3.min(data, function(x) {
        return d3.min(x[nested_key], fn);
      }), d3.max(data, function(x) {
        return d3.max(x[nested_key], fn);
      })
    ];
  };

  window.calcDistanceAlongPath = function(points, path, Nsegments) {
    var BBox, i, nearestNeighborIndex, pathLength, segPoints;

    Nsegments || (Nsegments = 5000);
    pathLength = path.getTotalLength();
    BBox = path.getBBox();
    segPoints = (function() {
      var _i, _results;

      _results = [];
      for (i = _i = 1; 1 <= Nsegments ? _i < Nsegments : _i > Nsegments; i = 1 <= Nsegments ? ++_i : --_i) {
        _results.push(path.getPointAtLength(pathLength * i / Nsegments));
      }
      return _results;
    })();
    if (BBox.width > BBox.height) {
      segPoints.sort(function(a, b) {
        return d3.ascending(a.x + 0.1 * a.y, b.x + 0.1 * b.y);
      });
    } else {
      segPoints.sort(function(a, b) {
        return d3.ascending(0.1 * a.x + a.y, 0.1 * b.x + b.y);
      });
    }
    nearestNeighborIndex = function(pt, points) {
      var dists, other;

      dists = (function() {
        var _i, _len, _results;

        _results = [];
        for (_i = 0, _len = points.length; _i < _len; _i++) {
          other = points[_i];
          _results.push(Math.pow(pt.x - other.x, 2) + Math.pow(pt.y - other.y, 2));
        }
        return _results;
      })();
      return dists.indexOf(d3.min(dists));
    };
    points.forEach(function(pt, i) {
      var idx;

      idx = nearestNeighborIndex(pt, segPoints);
      return pt.distance = pathLength * idx / Nsegments;
    });
    return points;
  };

  window.toTitleCase = function(str) {
    return str.replace(/\w\S*/g, function(txt) {
      return txt.charAt(0).toUpperCase() + txt.substr(1).toLowerCase();
    });
  };

  d3.selection.prototype.moveToFront = function() {
    return this.each(function() {
      return this.parentNode.appendChild(this);
    });
  };

}).call(this);
