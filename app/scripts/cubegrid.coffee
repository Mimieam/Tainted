#
#  Code to generate cube grid to hexagon grid diagram on http://www.redblobgames.com/articles/grids/
#  Copyright 2012 Red Blob Games <redblobgames@gmail.com>
#  License: Apache v2.0 <http://www.apache.org/licenses/LICENSE-2.0.html>
#
`
var ScreenCoordinate = function(x,y) {
    this.x = x;
    this.y = y;
};
function makeCubeGridDiagram(id) {
    var SQRT_3_2 = Math.sqrt(3)/2;
    var limit = 7;
    var svg = d3.select("#" + id);
    var root = svg.append('svg:g')
        .attr('transform', "translate(125.5, 139.5)");

    var cubes = [];
    for (var q = -3; q < 3; q++) {
        for (var r = -3; r < 3; r++) {
            for (var s = -3; s < 3; s++) {
                var z = q + r + s;
                cubes.push({q: q, r: r, s: s, z: z});
            }
        }
    }

    var scale = 20;
    
    function toScreen(q, r, s) {
        return new ScreenCoordinate(scale * (r-q) * SQRT_3_2, scale * (0.5*(r+q) - s));
    }

    // Axes
    root.append('line')
        .attr('class', "z-axis")
        .attr('x1', toScreen(0, 0, -8).x).attr('y1', toScreen(0, 0, -8).y)
        .attr('x2', toScreen(0, 0, 8).x).attr('y2', toScreen(0, 0, 8).y);
    root.append('text')
        .text("-z")
        .attr('transform', "translate(" + toScreen(0, 0, 6.5) + ") translate(10, 0)");
    root.append('text')
        .text("+z")
        .attr('transform', "translate(" + toScreen(0, 0, -6.5) + ") translate(-10, 0)");
    root.append('line')
        .attr('class', "y-axis")
        .attr('x1', toScreen(0, -8, 0).x).attr('y1', toScreen(0, -8, 0).y)
        .attr('x2', toScreen(0, 8, 0).x).attr('y2', toScreen(0, 8, 0).y);
    root.append('text')
        .text("-y")
        .attr('transform', "translate(" + toScreen(0, 6.5, 0) + ") translate(-7, 7)");
    root.append('text')
        .text("+y")
        .attr('transform', "translate(" + toScreen(0, -6.5, 0) + ") translate(7, -7)");
    root.append('line')
        .attr('class', "x-axis")
        .attr('x1', toScreen(-8, 0, 0).x).attr('y1', toScreen(-8, 0, 0).y)
        .attr('x2', toScreen(8, 0, 0).x).attr('y2', toScreen(8, 0, 0).y);
    root.append('text')
        .text("-x")
        .attr('transform', "translate(" + toScreen(6.5, 0, 0) + ") translate(-7, -7)");
    root.append('text')
        .text("+x")
        .attr('transform', "translate(" + toScreen(-6.5, 0, 0) + ") translate(7, 7)");

    // Public API
    function redraw() {
        var local_limit = Math.max(-3, limit);
        var show_cubes = limit >= -3;

        var offsets = [[0, 0, 1], [0, 1, 1], [0, 1, 0], [1, 1, 0], [1, 0, 0], [1, 0, 1]];
        var g = root.selectAll('g').data(cubes.filter(function (cube) { return -4 <= cube.z && cube.z < local_limit; }),
                                         function(cube) { return cube.q + ":" + cube.r + ":" + cube.s; });
        var old_elements = g.exit().transition()
            .ease('linear')
            .duration(300)
            .delay(function(d,i) { return 30 * d.z; })
            .attr('transform', "translate(250, 0)")
            .remove();

        var new_elements = g.enter()
            .append('g')
            .attr('transform', "translate(0, -200)");
        new_elements.transition()
            .ease('linear')
            .duration(300)
            .delay(function(d,i) { return 50 * (i % 10); })
            .attr('transform', "translate(0, 0)");

        new_elements.append('polygon').attr('class', 'full');
        new_elements.append('polygon').attr('class', 'shade');
        new_elements.append('path');

        function coord(q, r, s) {
            var p = toScreen(q, r, s);
            return p.x + "," + p.y;
        }

        g.select('path')
            .attr('stroke', show_cubes? 'hsl(60, 10%, 80%)' : 'hsl(60, 10%, 85%)')
            .attr('stroke-width', 1.0)
            .attr('d', function (cube) {
                var p1 = toScreen(cube.q, cube.r, cube.s);
                var p2 = toScreen(cube.q + 1, cube.r + 1, cube.s);
                var p3 = toScreen(cube.q + 1, cube.r, cube.s + 1);
                var p4 = toScreen(cube.q, cube.r + 1, cube.s + 1);
                return ["M", p1.x, p1.y, "L", p2.x, p2.y,
                        "M", p1.x, p1.y, "L", p3.x, p3.y,
                        "M", p1.x, p1.y, "L", p4.x, p4.y].join(" ");
            });

        g.select('polygon.full')
            .attr('fill', 'hsl(60, 10%, 90%)')
            .attr('stroke', show_cubes? 'hsl(60, 10%, 70%)' : 'hsl(60, 10%, 65%)')
            .attr('stroke-width', '1.0')
            .attr('points', function(cube) {
                var points = [];
                offsets.forEach(function (offset) {
                    points.push(coord(cube.q + offset[0], cube.r + offset[1], cube.s + offset[2]));
                });
                return points.join(" ");
            });

        g.select('polygon.shade')
            .attr('fill', show_cubes? 'hsl(60, 10%, 80%)' : 'hsl(60, 10%, 90%)')
            .attr('stroke', show_cubes? 'hsl(60, 10%, 70%)' : 'hsl(60, 10%, 65%)')
            .attr('stroke-width', '1.0')
            .attr('points', function(cube) {
                var points = [coord(cube.q, cube.r, cube.s)];
                offsets.slice(3, 7).forEach(function (offset) {
                    points.push(coord(cube.q + offset[0], cube.r + offset[1], cube.s + offset[2]));
                });
                return points.join(" ");
            });
    }

    redraw.limit = function(_) {
        if (!arguments.length) { return limit; }
        if (Math.round(_) != Math.round(limit)) {
            limit = Math.round(_);
            redraw();
        }
        return redraw;
    }

    svg.attr('data-limit', limit);
    var animation_complete = true;
    function redraw_if_animating() {
        redraw.limit(svg.attr('data-limit'));
        redraw();
        if (animation_complete) { setTimeout(redraw, 1000); }
        return animation_complete;
    }

    redraw.to_cube = function() {
        animation_complete = false;
        svg.transition().ease('linear').duration(6000).attr('data-limit', 7)
            .each('end', function() { animation_complete = true; });
        d3.timer(redraw_if_animating);
        d3.selectAll("button.cube-to-hex-cubes").classed('highlight', true);
        d3.selectAll("button.cube-to-hex-hexagons").classed('highlight', false);
    }

    redraw.to_hex = function() {
        animation_complete = false;
        svg.transition().ease('linear').duration(6000).attr('data-limit', -4)
            .each('end', function() { animation_complete = true; });
        d3.timer(redraw_if_animating);
        d3.selectAll("button.cube-to-hex-cubes").classed('highlight', false);
        d3.selectAll("button.cube-to-hex-hexagons").classed('highlight', true);
    }

    d3.selectAll("button.cube-to-hex-cubes").classed('highlight', true);
    redraw();

    return redraw;
}


var diagram_cube_to_hex = makeCubeGridDiagram('cube-to-hex')
`