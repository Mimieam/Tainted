hexToPolygon = (scale, x, y, orientation) ->
  
  # NOTE: the article says to use angles 0..300 or 30..330 (e.g. I
  # add 30 degrees for pointy top) but I instead use -30..270
  # (e.g. I subtract 30 degrees for pointy top) because it better
  # matches the animations I needed for my diagrams. They are
  # equivalent.
  
  points = []
  i = 0
  while i < 6
    angle = 2 * Math.PI * (2 * i - orientation) / 12
    points.push new ScreenCoordinate(x + 0.5 * scale * Math.cos(angle), y + 0.5 * scale * Math.sin(angle))
    i++
  points

`
var Cube = function(x,y,z) {
    this.v = [x,y,z];
    this._directions = [[1,-1,0],[1,0,-1],[0,1,-1],[-1,1,0],[-1,0,1],[0,-1,1]];  // possible neighbor of a cube
};

Cube.direction = function(i) {
    return new Cube(Cube._directions[i][0],Cube._directions[i][1],Cube._directions[i][2]);
}

Cube.prototype = {
    toString: function() {
        return this.v.join(",");
    }
    ,scale: function(f) {
        return new Cube(f * this.v[0],f * this.v[1],f * this.v[2]);
    }
    ,length: function() {
        var len = 0.0;
        var _g = 0;
        while(_g < 3) {
            var i = _g++;
            if(Math.abs(this.v[i]) > len) len = Math.abs(this.v[i]);
        }
        return len;
    }
}

var Grid = function(scale,orientation,shape) {
    this.scale = scale;
    this.orientation = orientation;
    this.hexes = shape;
};

Grid.twoAxisToCube = function(hex) {
    return new Cube(hex.q,-hex.r - hex.q,hex.r);
}
Grid.cubeToTwoAxis = function(cube) {
    return new Hex(cube.v[0] | 0,cube.v[2] | 0);
}

Grid.hexagonalShape = function(size) {
    var hexes = [];
    var _g1 = -size, _g = size + 1;
    while(_g1 < _g) {
        var x = _g1++;
        console.log("----X---<<", x)
        var _g3 = -size, _g2 = size + 1;
        while(_g3 < _g2) {
            var y = _g3++;
            var z = -x - y;
            console.log(" stuff ",x,y,z);
            if(Math.abs(x) <= size && Math.abs(y) <= size && Math.abs(z) <= size) hexes.push(new Cube(x,y,z));
        }
    }
    return hexes;
}
Grid.prototype = {
    hexToCenter: function(cube) {
        if(this.orientation) return new ScreenCoordinate(this.scale * (Grid.SQRT_3_2 * (cube.v[0] + 0.5 * cube.v[2])),this.scale * (0.75 * cube.v[2])); else return new ScreenCoordinate(this.scale * (0.75 * cube.v[0]),this.scale * (Grid.SQRT_3_2 * (cube.v[2] + 0.5 * cube.v[0])));
    }
}
var Hex = function(q,r) {
    this.q = q;
    this.r = r;
};
Hex.prototype = {
    toString: function() {
        return this.q + ":" + this.r;
    }
}
// var HxOverrides = function() { }
// HxOverrides.iter = function(a) {
//     return { cur : 0, arr : a, hasNext : function() {
//         return this.cur < this.arr.length;
//     }, next : function() {
//         return this.arr[this.cur++];
//     }};
// }
// var Lambda = function() { }
// Lambda.array = function(it) {
//     var a = new Array();
//     var $it0 = $iterator(it)();
//     while( $it0.hasNext() ) {
//         var i = $it0.next();
//         a.push(i);
//     }
//     return a;
// }
// Lambda.map = function(it,f) {
//     var l = new List();
//     var $it0 = $iterator(it)();
//     while( $it0.hasNext() ) {
//         var x = $it0.next();
//         l.add(f(x));
//     }
//     return l;
// }
// var List = function() {
//     this.length = 0;
// };
// List.prototype = {
//     add: function(item) {
//         var x = [item];
//         if(this.h == null) this.h = x; else this.q[1] = x;
//         this.q = x;
//         this.length++;
//     }
//     ,iterator: function() {
//         return { h : this.h, hasNext : function() {
//             return this.h != null;
//         }, next : function() {
//             if(this.h == null) return null;
//             var x = this.h[0];
//             this.h = this.h[1];
//             return x;
//         }};
//     }
// }
var ScreenCoordinate = function(x,y) {
    this.x = x;
    this.y = y;
};
ScreenCoordinate.prototype = {
    equals: function(p) {
        return this.x == p.x && this.y == p.y;
    }
    ,toString: function() {
        return this.x + "," + this.y;
    }
    ,length_squared: function() {
        return this.x * this.x + this.y * this.y;
    }
    ,length: function() {
        return Math.sqrt(this.length_squared());
    }
    ,normalize: function() {
        var d = this.length();
        return new ScreenCoordinate(this.x / d,this.y / d);
    }
    ,scale: function(d) {
        return new ScreenCoordinate(this.x * d,this.y * d);
    }
    ,rotateLeft: function() {
        return new ScreenCoordinate(this.y,-this.x);
    }
    ,rotateRight: function() {
        return new ScreenCoordinate(-this.y,this.x);
    }
    ,add: function(p) {
        return new ScreenCoordinate(this.x + p.x,this.y + p.y);
    }
    ,subtract: function(p) {
        return new ScreenCoordinate(this.x - p.x,this.y - p.y);
    }
    ,dot: function(p) {
        return this.x * p.x + this.y * p.y;
    }
    ,cross: function(p) {
        return this.x * p.y - this.y * p.x;
    }
    ,distance: function(p) {
        return this.subtract(p).length();
    }
}
// var Std = function() { }
// function $iterator(o) { if( o instanceof Array ) return function() { return HxOverrides.iter(o); }; return typeof(o.iterator) == 'function' ? $bind(o,o.iterator) : o.iterator; };
// var $_;
// function $bind(o,m) { var f = function(){ return f.method.apply(f.scope, arguments); }; f.scope = o; f.method = m; return f; };
// Math.__name__ = ["Math"];
// Math.NaN = Number.NaN;
// Math.NEGATIVE_INFINITY = Number.NEGATIVE_INFINITY;
// Math.POSITIVE_INFINITY = Number.POSITIVE_INFINITY;
// Math.isFinite = function(i) {
//     return isFinite(i);
// };
// Math.isNaN = function(i) {
//     return isNaN(i);
// };
// Cube._directions = [[1,-1,0],[1,0,-1],[0,1,-1],[-1,1,0],[-1,0,1],[0,-1,1]];
Grid.SQRT_3_2 = Math.sqrt(3) / 2;







// The shape of a hexagon is fixed by the scale and orientation
function makeHexagonShape(scale, orientation) {
    var points = hexToPolygon(scale, 0, 0, orientation);
    var svg_coord = "";
    points.forEach(function(p) {
        svg_coord += p + " ";
    });
    return svg_coord;
}


/* A grid diagram will be an object with
   1. nodes = { cube: Cube object, key: string, node: d3 selection of <g> containing polygon }
   2. grid = Grid object
   3. root = d3 selection of root <g> of diagram
   4. polygons = d3 selection of the hexagons inside the <g> per tile
   5. update = function(scale, orientation) to call any time orientation changes, including initialization
   6. onLayout = callback function that will be called before an update (to assign new cube coordinates)
      - this will be called immediately on update
   7. onUpdate = callback function that will be called after an update
      - this will be called after a delay, and only if there hasn't been another update
      - since it may not be called, this function should only affect the visuals and not data
*/
function makeGridDiagram(svg, cubes) {
    var diagram = {};

    diagram.nodes = cubes.map(function(n) { return {cube: n, key: n.toString()}; });
    diagram.root = svg.append('g');
    diagram.tiles = diagram.root.selectAll("g.tile").data(diagram.nodes, function(node) { return node.key; });
    diagram.tiles.enter()
        .append('g').attr('class', "tile")
        .each(function(d) { d.node = d3.select(this); });
    diagram.polygons = diagram.tiles.append('polygon');


    diagram.makeTilesSelectable = function(callback) {
        diagram.selected = d3.set();
        diagram.toggle = function(cube) {
            if (diagram.selected.has(cube)) {
                diagram.selected.remove(cube);
            } else {
                diagram.selected.add(cube);
            }
       };
        diagram.tiles
            .on('click', function(d) {
                d3.event.preventDefault();
                diagram.toggle(d.cube);
                callback();
            });
        // TODO: it'd be nice to be able to click and drag, or touch and drag
    };

    diagram.addHexCoordinates = function(converter, withMouseover) {
        diagram.nodes.forEach(function (n) { n.hex = converter(n.cube); });
        diagram.tiles.append('text')
            .attr('y', "0.4em")
            .each(function(d) {
                var selection = d3.select(this);
                selection.append('tspan').attr('class', "q").text(d.hex.q);
                selection.append('tspan').text(", ");
                selection.append('tspan').attr('class', "r").text(d.hex.r);
            });

        function setSelection(hex) {
            diagram.tiles
                .classed('q-axis-same', function(other) { return hex.q == other.hex.q; })
                .classed('r-axis-same', function(other) { return hex.r == other.hex.r; });
        }

        if (withMouseover) {
            diagram.tiles
                .on('mouseover', function(d) { setSelection(d.hex); })
                .on('touchstart', function(d) { setSelection(d.hex); });
        }

        return diagram;
    };


    var pre_callbacks = [];
    var post_callbacks = [];
    diagram.onLayout = function(callback) { pre_callbacks.push(callback); }
    diagram.onUpdate = function(callback) { post_callbacks.push(callback); }

    diagram.update = function(scale, orientation) {
        diagram.scale = scale;
        diagram.orientation = orientation;

        var grid = new Grid(scale, orientation, diagram.nodes.map(function(node) { return node.cube; }));
        var bounds = { minX :0, maxX : 20, minY :0, maxY : 20}
        var first_draw = !diagram.grid;
        diagram.grid = grid;
        // grid.cubeToTwoAxis;
        var hexagon_points = makeHexagonShape(scale, orientation);

        (function(animate) {
            if (first_draw) { animate = function(selection) { return selection; }; }

            // NOTE: In Webkit I can use svg.node().clientWidth but in Gecko that returns 0 :(
                diagram.translate = {x:300,y:300};
            // diagram.translate = new ScreenCoordinate((parseFloat(svg.attr('width')) - bounds.minX - bounds.maxX)/2,
            //                                          (parseFloat(svg.attr('height')) - bounds.minY - bounds.maxY)/2);

            console.log(diagram.translate);

            animate(diagram.root)   // PLACE ROOT NODE SOMEWHERE
                .attr('transform', "translate(300,300)");

            animate(diagram.tiles)   // ALIGN ANOTHER NODE AROUND ROOT NODE
                .attr('transform', function(node) {
                    var center = grid.hexToCenter(node.cube);
                    return "translate(" + center.x + "," + center.y + ")";
                });

            animate(diagram.polygons)  
                .attr('points', hexagon_points);

        })();

        return diagram;
    };

    return diagram;
}


// Helper function used for hex regions. A hex shaped region is the
// subset of hexes where a <= x <= b, c <= y <= d, e <= z <= f
function colorRegion(diagram, xmin, xmax, ymin, ymax, zmin, zmax, label) {
    // Here's the range algorithm as described in the article
    var results = d3.set();
    for (var x = xmin; x <= xmax; x++) {
        for (var y = Math.max(ymin, -x-zmax); y <= Math.min(ymax, -x-zmin); y++) {
            var z = -x-y;
            results.add(new Cube(x, y, z));
        }
    }

    diagram.tiles.classed(label, function(d) { return results.has(d.cube); });
}

function makeHexRegion() {
    var diagram = makeGridDiagram(d3.select("#diagram-hex-range"), Grid.hexagonalShape(1));

    var N = 0;
    diagram.tiles
        .on('click', function(d) { N = d.cube.length(); redraw(); })
        .on('touchstart', function(d) { N = d.cube.length(); redraw(); })
        .on('touchmove', function(d) { N = d.cube.length(); redraw(); });

    function redraw() {
        colorRegion(diagram, -N, N, -N, N, -N, N, 'region');
    }

    diagram.onUpdate(redraw);
    return diagram;
}

console.log("all done");

var diagram_hex_region = makeHexRegion();
    diagram_hex_region.update(45, true);

`
