(function() {
  var colorOfDay, colorOfDayScale, colorOfText, colorOfTextScale, isNight, maxNpassengers, playbackTmax, radiusPassenger, updateTime;

  playbackTmax = 3 * 60 * 1000;

  colorOfDayScale = d3.scale.linear().domain([0, 23]);

  colorOfDayScale.domain([0.0, 0.20, 0.21875, 0.23958333333333334, 0.25, 0.2708333333333333, 0.2916666666666667, 0.3125, 0.3333333333333333, 0.375, 0.4166666666666667, 0.5, 0.5416666666666666, 0.5833333333333334, 0.625, 0.6666666666666666, 0.7083333333333334, 0.75, 0.7708333333333334, 0.7916666666666666, 0.8125, 0.8333333333333334, 0.8541666666666666, 0.875, 0.916].map(colorOfDayScale.invert));

  colorOfDayScale.range(["#01062d", "#2b1782", "#600eae", "#9b13bb", "#b13daf", "#d086b5", "#dfa7ac", "#ebc8ab", "#f3dfbc", "#fef6aa", "#fefdea", "#fbf4a5", "#f0d681", "#fbf8da", "#f5f1ba", "#f0e435", "#f4be51", "#ec2523", "#a82358", "#712b80", "#4a3f96", "#188dba", "#1c71a3", "#173460", "#020b2f"]);

  colorOfDay = function(t) {
    return d3.rgb(colorOfDayScale(+d3.time.format.utc('%H')(new Date(t * 1000))));
  };

  colorOfTextScale = d3.scale.linear().domain([0, 23]);

  colorOfTextScale.domain([0.0, 0.20, 0.21875, 0.23958333333333334, 0.25, 0.2708333333333333, 0.2916666666666667, 0.3125, 0.3333333333333333, 0.375, 0.4166666666666667, 0.5, 0.5416666666666666, 0.5833333333333334, 0.625, 0.6666666666666666, 0.7083333333333334, 0.75, 0.7708333333333334, 0.7916666666666666, 0.8125, 0.8333333333333334, 0.8541666666666666, 0.875, 0.916].map(colorOfTextScale.invert));

  colorOfTextScale.range(["#e5e7f8", "#e5e7f8", "#f6f2f8", "#f6f2f8", "#f6f2f8", "#d086b5", "#2c0938", "#2c0938", "#2c0938", "#2c0938", "#2c0938", "#2c0938", "#2c0938", "#2c0938", "#2c0938", "#2c0938", "#2c0938", "#2c0938", "#2c0938", "#2c0938", "#f6f2f8", "#f6f2f8", "#f6f2f8", "#f6f2f8", "#f6f2f8"]);

  colorOfText = function(t) {
    return d3.rgb(colorOfTextScale(+d3.time.format.utc('%H')(new Date(t * 1000))));
  };

  updateTime = function(timeDisplay, t) {
    var curTime;

    curTime = new Date(t * 1000);
    timeDisplay.time.text(d3.time.format.utc('%I:%M')(curTime));
    return timeDisplay.ampm.text(d3.time.format.utc('%p')(curTime));
  };

  isNight = function(t) {
    var hour;

    hour = +d3.time.format.utc('%H')(new Date(t * 1000));
    return (0 <= hour && hour < 7) || hour >= 19;
  };

  radiusPassenger = 3;

  maxNpassengers = 5;

  window.show_ts = function(error, data_daily, map) {
    var all_timers, begin_bus_trip, color_filler, countScale, force_layout, fraction_stopped_time, g, height, line, line_maker, margin, mostStopPgrs, rScale, rVal, radiusPassengerScale, randomYpos, routePath, stopNameDisplay, stop_dists, stops, sumPpl, svg_route, tDepartureVal, tScale, tVal, timeDisplay, visStopRadius, vis_highlight_stop, vis_unhighlight_stop, width, xScale, xScaledValBus, xVal, yPos, yPosPassengers, yScale, yScaledValDoorsBus, yValBus, yValStop;

    if (error) {
      console.log(error.statusText);
      d3.selectAll('.normalOperation').classed('hidden', true);
      d3.selectAll('.errorState').classed('hidden', false);
      return;
    } else {
      d3.selectAll('.errorState').classed('hidden', true);
      d3.selectAll('.normalOperation').classed('hidden', false);
    }
    tVal = function(d) {
      return d.time_arrival;
    };
    tDepartureVal = function(d) {
      return d.time_departure;
    };
    rVal = function(d) {
      return d.count;
    };
    fraction_stopped_time = {
      deptaring: 2 / 5,
      boarding: 3 / 5
    };
    visStopRadius = 3;
    margin = {
      top: 3,
      right: 20,
      bottom: 3,
      left: 20
    };
    width = map.getWidth() - margin.left - margin.right;
    height = map.getHeight() / 4 - margin.top - margin.bottom;
    svg_route = d3.select('#route_vis').append('svg').attr({
      width: width + margin.left + margin.right,
      height: height + margin.top + margin.bottom
    });
    g = svg_route.append("g").attr({
      transform: translate(margin.left, margin.top)
    });
    timeDisplay = {
      time: d3.select('#time-display > .time'),
      ampm: d3.select('#time-display > .ampm'),
      weekday: d3.select('#time-display > .weekday')
    };
    stopNameDisplay = g.append('text').attr({
      id: 'stop-name-sign',
      x: 0,
      y: 0
    }).text('');
    tScale = d3.scale.linear().domain(nested_min_max(data_daily.trips, 'stops', tVal)).range([0, playbackTmax]);
    yScale = d3.scale.linear().domain([0, 1]).range([height - margin.top, 0 + margin.bottom]);
    rScale = d3.scale.linear().domain(nested_min_max(data_daily.trips, 'stops', rVal)).range([30, 80]);
    mostStopPgrs = nested_min_max(data_daily.trips, 'stops', function(d) {
      return d.count_boarding;
    })[1];
    sumPpl = data_daily.trips.map(function(trip) {
      return d3.sum(trip.stops.map(function(stop) {
        return stop.count_boarding;
      }));
    });
    if (d3.max(sumPpl) > 100 && map.city === 'geneva') {
      countScale = function(c) {
        return 1;
      };
      radiusPassengerScale = d3.scale.linear().domain([1, mostStopPgrs + 5]).range([radiusPassenger, 15]);
    } else {
      countScale = function(c) {
        return c;
      };
      radiusPassengerScale = function(c) {
        return radiusPassenger;
      };
    }
    yPos = yScale(0.5);
    yPosPassengers = yScale(0.4);
    yValStop = function(dir) {
      if (dir === 1) {
        return 0.48;
      } else if (dir === 0) {
        return 0.52;
      } else {
        return 0.5;
      }
    };
    yValBus = function(dir) {
      if (dir) {
        return 0.45;
      } else {
        return 0.69;
      }
    };
    yScaledValDoorsBus = function(dir) {
      return yScale(yValBus(dir)) + (dir ? 0.5 * rScale.range()[1] : 0);
    };
    yPosPassengers = function(dir) {
      if (dir) {
        return yScale(0.20);
      } else {
        return yScale(0.69);
      }
    };
    randomYpos = function(trip_direction) {
      if (trip_direction) {
        return getRandomRange(yScale(0), yScaledValDoorsBus(trip_direction));
      } else {
        return getRandomRange(yScaledValDoorsBus(trip_direction), yScale(1));
      }
    };
    color_filler = d3.scale.category20();
    line_maker = d3.svg.line().x(function(d) {
      return d;
    }).y(function(d) {
      return yPos;
    });
    routePath = d3.select("path.bus-route-" + data_daily.id_route);
    routePath.moveToFront();
    stop_dists = {};
    data_daily.stop_locations.forEach(function(d, i) {
      return stop_dists[d.id_stop] = +d.distance;
    });
    xVal = function(d) {
      return stop_dists[d.id_stop];
    };
    xScale = d3.scale.linear().domain(d3.extent(d3.values(stop_dists))).range([margin.left, width - margin.right]);
    xScaledValBus = function(d, dir) {
      return xScale(xVal(d)) - (dir ? rScale(rVal(d)) : 0);
    };
    line = g.append("path").datum(xScale.range()).attr({
      d: line_maker,
      "class": "bus-line"
    }).style({
      stroke: map.g.select("path.bus-route-" + data_daily.id_route).style('stroke')
    });
    stops = g.selectAll("circle.bus-stop").data(data_daily.stop_locations).enter().append("circle").attr({
      "class": function(d) {
        return "bus-stop bus-stop-" + d.id_stop;
      },
      r: visStopRadius,
      cx: function(d) {
        return xScale(d.distance);
      },
      cy: function(d) {
        return yScale(yValStop(d.direction));
      }
    });
    vis_highlight_stop = function(d, elem) {
      var map_circle, vis_circle;

      map_circle = map.g.selectAll("circle.bus-stop-" + d.id_stop);
      map_circle.moveToFront().classed('highlighted', true).transition().attr('r', map.busStopRadius * 3);
      if (elem) {
        map_circle.classed('user-highlighted', true);
        vis_circle = d3.select(elem);
        vis_circle.classed('user-highlighted', true).moveToFront().transition().attr('r', visStopRadius * 2);
        return stopNameDisplay.text(map_circle.data()[0].properties.name_stop).attr({
          x: vis_circle.attr('cx'),
          y: +vis_circle.attr('cy') - 20
        });
      }
    };
    vis_unhighlight_stop = function(d, elem) {
      var map_circle;

      map_circle = map.g.selectAll("circle.bus-stop-" + d.id_stop);
      map_circle.classed('highlighted', false).transition().attr('r', map.busStopRadius);
      if (elem) {
        map_circle.classed('user-highlighted', false);
        d3.select(elem).classed('user-highlighted', false).transition().attr('r', visStopRadius);
        return stopNameDisplay.text('');
      }
    };
    stops.on('mouseover', function(d) {
      return vis_highlight_stop(d, this);
    }).on('mouseout', function(d) {
      return vis_unhighlight_stop(d, this);
    });
    force_layout = function() {
      return d3.layout.force().links([]).gravity(0).friction(0.2).charge(-80).size([svg_route.width, svg_route.height]);
    };
    all_timers = [];
    data_daily.trips.forEach(function(data_trip, i) {
      data_trip.realTimeStart = d3.min(data_trip.stops, tVal);
      return data_trip.Tstart = tScale(data_trip.realTimeStart);
    });
    data_daily.trips.forEach(function(data_trip, i) {
      var start_trip;

      start_trip = function() {
        var duration;

        duration = (i + 1 < data_daily.trips.length ? data_daily.trips[i + 1].Tstart - data_trip.Tstart : 0);
        d3.select('#route_vis_panel').transition().duration(duration).style('background-color', colorOfDay(data_trip.realTimeStart)).style('color', colorOfText(data_trip.realTimeStart));
        d3.select("#weekday").transition().duration(duration).style('color', colorOfText(data_trip.realTimeStart));
        return begin_bus_trip(data_trip, i);
      };
      return map.visTimers.push(setTimeout(start_trip, data_trip.Tstart));
    });
    begin_bus_trip = function(data_trip, tripNumber) {
      var add_passenger_to_bus_stop, bus, current_bus_stop, data_passenger_timing, data_passengers, data_stops, durationScale, force, id_trip, move_bus, passenger_circles, redraw_passengers, show_boarding_passengers, show_departing_passengers, tick_fn;

      id_trip = data_trip.id_trip;
      data_stops = data_trip.stops;
      current_bus_stop = 0;
      data_stops.forEach(function(d, i) {
        d.time_departure || (d.time_departure = tVal(d) + 30);
      });
      durationScale = d3.scale.linear().domain([0, d3.max(data_stops, tVal) - d3.min(data_stops, tVal)]).range([0, tScale(d3.max(data_stops, tVal)) - tScale(d3.min(data_stops, tVal))]);
      bus = g.append('image').style({
        opacity: 0.8
      }).attr({
        'xlink:href': "img/bus-" + (data_trip.trip_direction ? 'inbound' : 'outbound') + (isNight(data_trip.realTimeStart) ? '-night' : '') + ".png",
        "class": "bus bus-" + data_trip.id_trip,
        width: rScale(rVal(data_stops[0])),
        height: rScale(rVal(data_stops[0])),
        x: xScaledValBus(data_stops[0], data_trip.trip_direction),
        y: yScale(yValBus(data_trip.trip_direction))
      });
      data_passengers = [];
      passenger_circles = g.selectAll("circle.passenger-" + id_trip);
      tick_fn = function(e) {
        var k;

        k = .9 * e.alpha;
        data_passengers.forEach(function(o, i) {
          o.x += (xScale(xVal(data_stops[o.stop_number])) - o.x) * k;
          return o.y += (yPosPassengers(data_trip.trip_direction) - o.y) * k;
        });
        passenger_circles.attr({
          cx: function(d) {
            return d.x;
          },
          cy: function(d) {
            return d.y;
          }
        });
      };
      force = force_layout().nodes(data_passengers).on('tick', tick_fn);
      redraw_passengers = function(boarding_duration) {
        var drop_circles;

        boarding_duration || (boarding_duration = 100);
        force.nodes(data_passengers);
        passenger_circles = passenger_circles.data(force.nodes(), function(d) {
          return d.index;
        });
        passenger_circles.enter().append("circle").attr({
          "class": "passenger passenger-" + id_trip,
          cx: function(d) {
            return d.x;
          },
          cx: function(d) {
            return d.y;
          },
          r: function(d) {
            return radiusPassengerScale(d.nPassengers);
          }
        }).style({
          fill: function(d) {
            return color_filler(d.stop_number);
          },
          stroke: function(d) {
            return d3.rgb(color_filler(d.stop_number)).darker(2);
          },
          "stroke-width": 1.5
        }).call(force.drag);
        passenger_circles.exit().transition(boarding_duration).attr({
          cx: function(d) {
            return xScale(xVal(data_stops[d.stop_number]));
          },
          cy: function(d) {
            return yScale(yValBus(data_stops[d.stop_number]));
          }
        });
        drop_circles = function() {
          passenger_circles.exit().remove();
          passenger_circles.filter(function(d) {
            return d.stop_number === current_bus_stop;
          }).remove();
          return data_passengers = data_passengers.filter(function(d) {
            return d.stop_number !== current_bus_stop;
          });
        };
        setTimeout(drop_circles, boarding_duration);
        force.start();
      };
      add_passenger_to_bus_stop = function(psgr) {
        var stop_number;

        if (current_bus_stop >= data_stops.length - 1) {
          return;
        }
        stop_number = psgr.stop_number;
        data_passengers.push({
          stop_number: stop_number,
          id_trip: id_trip,
          x: xScale(xVal(data_stops[stop_number])) + (Math.random() - 0.5) * width / data_stops.length,
          y: randomYpos(data_trip.trip_direction),
          nPassengers: psgr.nPassengers
        });
        return redraw_passengers();
      };
      show_departing_passengers = function(stop_number) {
        var departing_data, departing_passengers, drop_data, duration, i, stop;

        stop = data_stops[stop_number];
        departing_data = (function() {
          var _i, _len, _ref, _results;

          _ref = _.range(stop.count_exiting);
          _results = [];
          for (_i = 0, _len = _ref.length; _i < _len; _i++) {
            i = _ref[_i];
            _results.push({
              xEnd: xScale(xVal(stop)) + (Math.random() - 0.5) * width / data_stops.length,
              yEnd: randomYpos(data_trip.trip_direction)
            });
          }
          return _results;
        })();
        departing_passengers = g.selectAll("circle.passenger-departing-" + id_trip + "-" + stop_number).data(departing_data).enter().append('circle');
        departing_passengers.attr({
          "class": "passenger-departing passenger-departing-" + id_trip + "-" + stop_number,
          cx: xScale(xVal(stop)),
          cy: yScaledValDoorsBus(data_trip.trip_direction),
          r: 3
        }).style({
          fill: '#eee',
          stroke: d3.rgb(color_filler(stop_number)).darker(2),
          "stroke-width": 1.5
        });
        duration = durationScale(tDepartureVal(stop) - tVal(stop)) + 1000;
        departing_passengers.transition().duration(duration).attr({
          cx: function(d) {
            return d.xEnd;
          },
          cy: function(d) {
            return d.yEnd;
          }
        }).style({
          'fill-opacity': 0.01
        });
        drop_data = function() {
          departing_passengers.data([]).exit().remove();
        };
        return setTimeout(drop_data, duration);
      };
      show_boarding_passengers = function(stop_number, duration_stopped) {
        var boarding_fn;

        if (!(data_passengers.length > 0)) {
          return;
        }
        boarding_fn = function() {
          data_passengers = data_passengers.filter(function(p) {
            return p.stop_number !== stop_number;
          });
          return redraw_passengers(duration_stopped * fraction_stopped_time.boarding);
        };
        setTimeout(boarding_fn, duration_stopped * fraction_stopped_time.deptaring);
      };
      move_bus = function(stop_number) {
        var arrival_fn, duration_motion, duration_stopped;

        current_bus_stop = stop_number;
        if (stop_number === 0) {
          duration_motion = 50;
          duration_stopped = 100;
        } else {
          duration_motion = durationScale(tVal(data_stops[stop_number]) - tDepartureVal(data_stops[stop_number - 1]));
          duration_stopped = durationScale(tDepartureVal(data_stops[stop_number]) - tVal(data_stops[stop_number]));
        }
        bus.transition().duration(duration_motion).attr({
          x: xScaledValBus(data_stops[stop_number], data_trip.trip_direction)
        });
        arrival_fn = function() {
          var fadeDuration, move_to_next_fn, remaining, rmFn;

          if (stop_number < (data_stops.length - 1)) {
            updateTime(timeDisplay, tVal(data_stops[stop_number]));
            vis_highlight_stop(data_stops[stop_number]);
            show_departing_passengers(stop_number);
            show_boarding_passengers(stop_number, duration_stopped);
            bus.transition().duration(duration_stopped).attr({
              height: rScale(rVal(data_stops[stop_number])),
              width: rScale(rVal(data_stops[stop_number]))
            });
            move_to_next_fn = function() {
              vis_unhighlight_stop(data_stops[stop_number]);
              move_bus(stop_number + 1);
            };
            map.visTimers.push(setTimeout(move_to_next_fn, duration_stopped));
          } else {
            fadeDuration = 600;
            bus.transition().duration(fadeDuration).style('opacity', 0);
            rmFn = function() {
              return bus.remove();
            };
            setTimeout(rmFn, fadeDuration);
            remaining = d3.selectAll("circle.passenger-" + id_trip);
            if (remaining[0].length > 0) {
              remaining.remove();
            }
            if (tripNumber === data_daily.trips.length - 1) {
              map.advanceDate();
            }
          }
        };
        return setTimeout(arrival_fn, duration_motion);
      };
      data_passenger_timing = [];
      data_stops.forEach(function(stop, s) {
        return _.range(countScale(stop.count_boarding)).forEach(function(el, i) {
          var tPrev;

          if (s > 8) {
            tPrev = tVal(data_stops[s - 5]);
          } else {
            tPrev = tVal(data_stops[0]);
          }
          return data_passenger_timing.push({
            time_appear: getRandomRange(tPrev, tVal(stop) - 100) - tVal(data_stops[0]),
            stop_number: s,
            nPassengers: stop.count_boarding
          });
        });
      });
      data_passenger_timing.forEach(function(psgr, p) {
        var adder_fn;

        adder_fn = function() {
          add_passenger_to_bus_stop(psgr);
          return true;
        };
        setTimeout(adder_fn, durationScale(psgr.time_appear));
      });
      move_bus(0);
    };
    return all_timers;
  };

}).call(this);
