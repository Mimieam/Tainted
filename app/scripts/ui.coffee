# Hexagonal grid functions
# From http://www.redblobgames.com/grids/hexagons.html
# Copyright 2013 Red Blob Games <redblobgames@gmail.com>
# License: Apache v2.0 <http://www.apache.org/licenses/LICENSE-2.0.html>

# There are lots of diagrams on the page and many of them get updated
# * at the same time, on a button press. Drawing them all is slow; let's
# * delay the drawing.
# *
# * The logic is:
# * 1. If a diagram is updated, put it in a queue.
# * 2. If a diagram is in the queue and is on screen,
# *    a. if it's the first time drawing it, draw it immediately
# *    b. otherwise, animate the transition from previous state
# * 3. If a diagram is in the queue and is not on screen,
# *    draw it in the background (if the user is idle)
# 

# The idle tracker will call a callback when the user is idle 1000,
# 1100, 1200, etc. milliseconds. I use this to draw off-screen
# diagrams in the background. If there are no diagrams to redraw,
# call idle_tracker.stop() to remove the interval and event handlers.

# There is no loop running so start it, and also start tracking user idle

# There's a loop scheduled but I want it to run immediately

# Stop tracking user idle when we don't need to (performance)

# How far outside the viewport is this element? 0 if it's visible even partially.
distanceToScreen = (node) ->
  
  # Compare two ranges: the top:bottom of the browser window and
  # the top:bottom of the element
  viewTop = window.pageYOffset
  viewBottom = viewTop + window.innerHeight
  
  # Workaround for Firefox: SVG nodes have no
  # offsetTop/offsetHeight so I check the parent instead
  node = node.parentNode  if node.offsetTop is `undefined`
  elementTop = node.offsetTop
  elementBottom = elementTop + node.offsetHeight
  Math.max 0, elementTop - viewBottom, viewTop - elementBottom

# Draw all the on-screen elements that are queued up, and anything
# else if we're idle
_delayedDraw = ->
  actions = []
  idle_draws_allowed = 4
  
  # First evaluate all the actions and how far the elements are from being viewed
  delay.queue.forEach (id, ea) ->
    element = ea[0]
    action = ea[1]
    d = distanceToScreen(element.node())
    actions.push [
      id
      action
      d
    ]
    return

  
  # Sort so that the ones closest to the viewport are first
  actions.sort (a, b) ->
    a[2] - b[2]

  
  # Draw all the ones that are visible now, or up to
  # idle_draws_allowed that aren't visible now
  actions.forEach (ia) ->
    id = ia[0]
    action = ia[1]
    d = ia[2]
    if d is 0 or idle_draws_allowed > 0
      --idle_draws_allowed  unless d is 0
      delay.queue.remove id
      delay.refresh.add id
      animate = delay.refresh.has(id) and d is 0
      action (selection) ->
        (if animate then selection.transition().duration(200) else selection)

    return

  return

# Function for use with d3.timer
_delayDrawOnTimeout = ->
  _delayedDraw()
  idle_tracker.stop()  if delay.queue.keys().length is 0
  return

# Interface used by the rest of the code: call this function with the
# d3 selection of the element being drawn (typically an <svg>) and an
# action. The action will be called with an animate parameter, which
# is a function that takes a d3 selection and returns it optionally
# with an animated transition.
delay = (element, action) ->
  delay.queue.set element.attr("id"), [
    element
    action
  ]
  idle_tracker.start()
  return
# which elements need redrawing?
# set of elements we've seen before

# NOTE: on iOS, scroll event doesn't occur until after the scrolling
# * stops, which is too late for this redraw. I am not sure how to do
# * this properly. Instead of drawing only on scroll, I also draw in
# * the background when the user is idle. 

# (x, y) should be the center
# scale should be the distance from corner to corner
# orientation should be 0 (flat bottom hex) or 1 (flat side hex)
hexToPolygon = (scale, x, y, orientation) ->
  
  # NOTE: the article says to use angles 0..300 or 30..330 (e.g. I
  # add 30 degrees for pointy top) but I instead use -30..270
  # (e.g. I subtract 30 degrees for pointy top) because it better
  # matches the animations I needed for my diagrams. They're
  # equivalent.
  points = []
  i = 0

  while i < 6
    angle = 2 * Math.PI * (2 * i - orientation) / 12
    points.push new ScreenCoordinate(x + 0.5 * scale * Math.cos(angle), y + 0.5 * scale * Math.sin(angle))
    i++
  points

# Arrow drawing utility takes a <path>, source, dest, and sets the d= and transform
makeArrow = (path, w, skip, A, B) ->
  d = A.subtract(B)
  h = d.length() - 2 * w - skip
  path.attr "transform", "translate(" + B + ") rotate(" + (180 / Math.PI * Math.atan2(d.y, d.x)) + ")"
  if h <= 0.0
    path.attr "d", [
      "M"
      0
      0
    ].join(" ")
  else
    path.attr "d", [
      "M"
      0
      0
      "l"
      2 * w
      2 * w
      "l"
      0
      -w
      "l"
      h
      0
      "l"
      -0.3 * w
      -w
      "l"
      0.3 * w
      -w
      "l"
      -h
      0
      "l"
      0
      -w
      "Z"
    ].join(" ")
  return
axial_hexToCenter = (scale, orientation) ->
  if orientation
    (hex) ->
      q = hex.q
      r = hex.r
      
      # HACK: for cube we use a different setup
      r = hex.s  if typeof (hex.s) is "number"
      new ScreenCoordinate(scale * (Grid.SQRT_3_2 * (q + 0.5 * r)), scale * (0.75 * r))
  else
    (hex) ->
      q = hex.q
      r = hex.r
      
      # HACK: for cube we use a different setup
      r = hex.s  if typeof (hex.s) is "number"
      new ScreenCoordinate(scale * (0.75 * q), scale * (Grid.SQRT_3_2 * (r + 0.5 * q)))
offset_hexToCenter = (offset_style) ->
  (scale, orientation) ->
    w = 0.75 * scale
    h = Grid.SQRT_3_2 * scale
    if orientation
      w = h
      h = 0.75 * scale
    (hex) ->
      q = hex.q
      r = hex.r
      
      # NOTE: we use &1 instead of %2 because it works for negative coordinates
      r += 0.5 * (q & 1)  if offset_style is "odd_q"
      r += 0.5 * (1 - q & 1)  if offset_style is "even_q"
      q += 0.5 * (r & 1)  if offset_style is "odd_r"
      q += 0.5 * (1 - r & 1)  if offset_style is "even_r"
      new ScreenCoordinate(w * q, h * r)

# The shape of a hexagon is fixed by the scale and orientation
makeHexagonShape = (scale, orientation) ->
  points = hexToPolygon(scale, 0, 0, orientation)
  svg_coord = ""
  points.forEach (p) ->
    svg_coord += p + " "
    return

  svg_coord

# A grid diagram will be an object with
#   1. nodes = { cube: Cube object, key: string, node: d3 selection of <g> containing polygon }
#   2. grid = Grid object
#   3. root = d3 selection of root <g> of diagram
#   4. polygons = d3 selection of the hexagons inside the <g> per tile
#   5. update = function(scale, orientation) to call any time orientation changes, including initialization
#   6. onLayout = callback function that will be called before an update (to assign new cube coordinates)
#      - this will be called immediately on update
#   7. onUpdate = callback function that will be called after an update
#      - this will be called after a delay, and only if there hasn't been another update
#      - since it may not be called, this function should only affect the visuals and not data
#
makeGridDiagram = (svg, cubes) ->
  diagram = {}
  diagram.nodes = cubes.map((n) ->
    cube: n
    key: n.toString()
  )
  diagram.root = svg.append("g")
  diagram.tiles = diagram.root.selectAll("g.tile").data(diagram.nodes, (node) ->
    node.key
  )
  diagram.tiles.enter().append("g").attr("class", "tile").each (d) ->
    d.node = d3.select(this)
    return

  diagram.polygons = diagram.tiles.append("polygon")
  diagram.makeTilesSelectable = (callback) ->
    diagram.selected = d3.set()
    diagram.toggle = (cube) ->
      if diagram.selected.has(cube)
        diagram.selected.remove cube
      else
        diagram.selected.add cube
      return

    diagram.tiles.on "click", (d) ->
      d3.event.preventDefault()
      diagram.toggle d.cube
      callback()
      return

    return

  
  # TODO: it'd be nice to be able to click and drag, or touch and drag
  diagram.addLabels = (labelFunction) ->
    diagram.tiles.append("text").attr("y", "0.4em").text (d, i) ->
      (if labelFunction then labelFunction(d, i) else "")

    diagram

  diagram.addHexCoordinates = (converter, withMouseover) ->
    setSelection = (hex) ->
      diagram.tiles.classed("q-axis-same", (other) ->
        hex.q is other.hex.q
      ).classed "r-axis-same", (other) ->
        hex.r is other.hex.r

      return
    diagram.nodes.forEach (n) ->
      n.hex = converter(n.cube)
      return

    diagram.tiles.append("text").attr("y", "0.4em").each (d) ->
      selection = d3.select(this)
      selection.append("tspan").attr("class", "q").text d.hex.q
      selection.append("tspan").text ", "
      selection.append("tspan").attr("class", "r").text d.hex.r
      return

    if withMouseover
      diagram.tiles.on("mouseover", (d) ->
        setSelection d.hex
        return
      ).on "touchstart", (d) ->
        setSelection d.hex
        return

    diagram

  diagram.addCubeCoordinates = (withMouseover) ->
    
    # Special case: label the origin with x/y/z so that you can tell where things to
    relocate = ->
      BL = 4 # adjust to vertically center
      offsets = (if diagram.orientation then [
        14
        -9 + BL
        -14
        -9 + BL
        0
        13 + BL
      ] else [
        13
        0 + BL
        -9
        -14 + BL
        -9
        14 + BL
      ])
      offsets = offsets.map((f) ->
        f * diagram.scale / 50
      )
      diagram.tiles.select(".q").attr("x", offsets[0]).attr "y", offsets[1]
      diagram.tiles.select(".s").attr("x", offsets[2]).attr "y", offsets[3]
      diagram.tiles.select(".r").attr("x", offsets[4]).attr "y", offsets[5]
      return
    setSelection = (cube) ->
      [
        "q"
        "s"
        "r"
      ].forEach (axis, i) ->
        diagram.tiles.classed axis + "-axis-same", (other) ->
          cube.v[i] is other.cube.v[i]

        return

      return
    diagram.tiles.append("text").each (d) ->
      selection = d3.select(this)
      labels = d.cube.v
      if labels[0] is 0 and labels[1] is 0 and labels[2] is 0
        labels = [
          "x"
          "y"
          "z"
        ]
      selection.append("tspan").attr("class", "q").text labels[0]
      selection.append("tspan").attr("class", "s").text labels[1]
      selection.append("tspan").attr("class", "r").text labels[2]
      return

    if withMouseover
      diagram.tiles.on("mouseover", (d) ->
        setSelection d.cube
      ).on "touchstart", (d) ->
        setSelection d.cube

    diagram.onUpdate relocate
    diagram

  pre_callbacks = []
  post_callbacks = []
  diagram.onLayout = (callback) ->
    pre_callbacks.push callback
    return

  diagram.onUpdate = (callback) ->
    post_callbacks.push callback
    return

  diagram.update = (scale, orientation) ->
    diagram.scale = scale
    diagram.orientation = orientation
    pre_callbacks.forEach (f) ->
      f()
      return

    grid = new Grid(scale, orientation, diagram.nodes.map((node) ->
      node.cube
    ))
    bounds = grid.bounds()
    first_draw = not diagram.grid
    diagram.grid = grid
    hexagon_points = makeHexagonShape(scale, orientation)
    delay svg, (animate) ->
      if first_draw
        animate = (selection) ->
          selection
      
      # NOTE: In Webkit I can use svg.node().clientWidth but in Gecko that returns 0 :(
      diagram.translate = new ScreenCoordinate((parseFloat(svg.attr("width")) - bounds.minX - bounds.maxX) / 2, (parseFloat(svg.attr("height")) - bounds.minY - bounds.maxY) / 2)
      animate(diagram.root).attr "transform", "translate(" + diagram.translate + ")"
      animate(diagram.tiles).attr "transform", (node) ->
        center = grid.hexToCenter(node.cube)
        "translate(" + center.x + "," + center.y + ")"

      animate(diagram.polygons).attr "points", hexagon_points
      post_callbacks.forEach (f) ->
        f()
        return

      return

    diagram

  diagram

# Diagram "parts"
makeParts = ->
  svg = d3.select("#hexagon-parts")
  svg.append("g").attr "class", "tile"
  polygon = svg.selectAll("g.tile").append("polygon")
  center_marker = svg.append("circle").attr("class", "marker").attr("r", 5)
  center_text = svg.append("text").text("center").attr("class", "center")
  corner_marker = svg.append("circle").attr("class", "marker").attr("r", 5)
  corner_text = svg.append("text").text("corner").attr("class", "center")
  edge_marker = svg.append("line").attr("class", "marker")
  edge_text = svg.append("text").text("edge")
  (orientation) ->
    size = 250
    center = new ScreenCoordinate(130, 130)
    corner = hexToPolygon(size, center.x, center.y, orientation)[3]
    edge = hexToPolygon(size, center.x, center.y, orientation).slice(1, 3)
    delay svg, (animate) ->
      animate(polygon).attr("transform", "translate(" + center + ")").attr "points", makeHexagonShape(size, orientation)
      animate(center_marker).attr "transform", "translate(" + center + ")"
      animate(center_text).attr "transform", "translate(" + center + ") translate(0, 15)"
      animate(corner_marker).attr "transform", "translate(" + corner + ")"
      animate(corner_text).attr "transform", "translate(" + corner + ") translate(25, 5)"
      animate(edge_marker).attr("x1", edge[0].x).attr("y1", edge[0].y).attr("x2", edge[1].x).attr "y2", edge[1].y
      animate(edge_text).attr "transform", "translate(" + 0.5 * (edge[0].x + edge[1].x) + "," + 0.5 * (edge[0].y + edge[1].y) + ") translate(" + 10 * orientation + ", 15)"
      return

    return

# Diagram "angles"
makeAngles = ->
  svg = d3.select("#hexagon-angles")
  svg.append("g").attr "class", "tile"
  polygon = svg.selectAll("g.tile").append("polygon")
  triangle = svg.append("path").attr("fill", "none").attr("stroke-dasharray", "4,3").attr("stroke-width", 1).attr("stroke", "hsl(0, 0%, 50%)")
  radius_texts = [
    svg.append("text").text("size")
    svg.append("text").text("size")
    svg.append("text").text("size")
  ]
  triangle_text_1 = svg.append("text").text("60°")
  triangle_text_2 = svg.append("text").text("60°")
  triangle_text_3 = svg.append("text").text("60°")
  interior_angle_text = svg.append("text").text("120°")
  exterior_angle_texts = svg.selectAll("text.exterior-angle").data([
    0
    60
    120
    180
    240
    300
  ]).enter().append("text").attr("class", "exterior-angle")
  (orientation) ->
    size = 215
    center = new ScreenCoordinate(130, 130)
    corners = hexToPolygon(size, center.x, center.y, orientation)
    delay svg, (animate) ->
      animate(polygon).attr("transform", "translate(" + center + ")").attr "points", makeHexagonShape(size, orientation)
      animate(triangle).attr "d", [
        "M"
        corners[0]
        "L"
        center
        "L"
        corners[1]
      ].join(" ")
      animate(triangle_text_1).attr "transform", "translate(" + (corners[0].scale(0.8).add(corners[1].scale(0.1)).add(center.scale(0.1))) + ") translate(0, 4)"
      animate(triangle_text_2).attr "transform", "translate(" + (corners[1].scale(0.8).add(corners[0].scale(0.1)).add(center.scale(0.1))) + ") translate(0, 4)"
      animate(triangle_text_3).attr "transform", "translate(" + (center.scale(0.8).add(corners[0].scale(0.1)).add(corners[1].scale(0.1))) + ") translate(0, 4)"
      animate(radius_texts[0]).attr "transform", "translate(" + (center.scale(0.55).add(corners[0].scale(0.55)).add(corners[1].scale(-0.1))) + ") translate(0, 4)"
      animate(radius_texts[1]).attr "transform", "translate(" + (center.scale(0.55).add(corners[1].scale(0.55)).add(corners[0].scale(-0.1))) + ") translate(0, 4)"
      animate(radius_texts[2]).attr "transform", "translate(" + (center.scale(-0.1).add(corners[0].scale(0.55)).add(corners[1].scale(0.55))) + ") translate(0, 4)"
      animate(interior_angle_text).attr "transform", "translate(" + (corners[2].scale(0.85).add(center.scale(0.15))) + ") translate(0, 4)"
      animate(exterior_angle_texts).attr("transform", (degrees, i) ->
        "translate(" + corners[i].subtract(center).scale(1.1).add(center) + ") translate(0, 4)"
      ).text (degrees) ->
        
        # See note about angles in hexToPolygon()
        ((degrees - orientation * 30 + 360) % 360) + "°"

      return

    return

# Diagram "spacing"
format_quarters = (a) ->
  
  # Format a/4 as a mixed numeral
  suffix = [
    ""
    "¼"
    "½"
    "¾"
  ][a % 4]
  prefix = Math.floor(a / 4)
  prefix = ""  if prefix is 0 and suffix isnt ""
  prefix + suffix
makeSpacing = ->
  svg = d3.select("#hexagon-spacing")
  tiles = svg.selectAll("g.tile").data([
    0
    1
    2
    3
  ]).enter().append("g").attr("class", "tile")
  polygons = tiles.append("polygon")
  centers = tiles.append("circle").attr("class", "marker").attr("r", 4)
  (orientation) ->
    size = 120
    r = size / 2
    s = Grid.SQRT_3_2 * r
    center = new ScreenCoordinate(70, 40)
    offsets = (if orientation then [
      new ScreenCoordinate(s, 2.5 * r)
      new ScreenCoordinate(2 * s, r)
      new ScreenCoordinate(3 * s, 2.5 * r)
      new ScreenCoordinate(4 * s, r)
    ] else [
      new ScreenCoordinate(r, 2 * s)
      new ScreenCoordinate(2.5 * r, s)
      new ScreenCoordinate(2.5 * r, 3 * s)
      new ScreenCoordinate(4 * r, 2 * s)
    ])
    delay svg, (animate) ->
      animate(tiles).attr "transform", (_, i) ->
        "translate(" + center.add(offsets[i]) + ")"

      animate(polygons).attr "points", makeHexagonShape(size, orientation)
      
      # NOTE: I should be using d3's exit().remove() here but I
      # haven't learned how to properly handle the nested elements
      # so I'm just taking the easy way out and removing all the
      # old ones every time.
      svg.selectAll("g.grid-horizontal").remove()
      horizontal_lines = svg.selectAll("g.grid-horizontal").data((if orientation then [
        0
        1
        2
        3
        4
        5
        6
        7
      ] else [
        0
        1
        2
        3
        4
      ]), String)
      g = horizontal_lines.enter().append("g").attr("class", "grid-horizontal")
      horizontal_lines.attr "transform", (y) ->
        "translate(" + center.add(new ScreenCoordinate(0, y * ((if orientation then (r / 2) else s)))) + ")"

      g.append("path").attr "d", [
        "M"
        -20
        0
        "L"
        (if orientation then 5 * s else 5 * r)
        0
      ].join(" ")
      g.append("text").attr("transform", "translate(-30, 4)").text (y) ->
        format_quarters((if orientation then y else (2 * y))) + "h"

      svg.selectAll("g.grid-vertical").remove()
      vertical_lines = svg.selectAll("g.grid-vertical").data((if orientation then [
        0
        1
        2
        3
        4
        5
      ] else [
        0
        1
        2
        3
        4
        5
        6
        7
        8
        9
        10
      ]), String)
      g = vertical_lines.enter().append("g").attr("class", "grid-vertical")
      vertical_lines.attr "transform", (x) ->
        "translate(" + center.add(new ScreenCoordinate(x * ((if orientation then s else (r / 2))), 0)) + ")"

      g.append("path").attr "d", [
        "M"
        0
        -20
        "L"
        0
        (if orientation then 3.5 * r else 4 * s)
      ].join(" ")
      g.append("text").attr("transform", "translate(0, -30)").text (x) ->
        format_quarters((if orientation then (2 * x) else x)) + "w"

      return

    return
makeNeighbors = (id_diagram, id_code, converter, parity_var) ->
  
  # Note that this code is a little messy because I'm trying to handle cube, axial, offset
  # should be 6 (axial) or 12 (offset)
  
  # There will be either 7 (axial) or 14 nodes (offset)
  # dummy coordinates for now
  neighbor = (odd, i) ->
    base = (if odd then new Cube(1, -2, 1) else new Cube(0, 0, 0))
    h1 = diagram.converter(base)
    h2 = diagram.converter(base.add(Cube.direction(i)))
    dq = h2.q - h1.q
    dr = h2.r - h1.r
    new Hex(dq, dr)
  setSelection = (d) ->
    code.classed "highlight", (_, i) ->
      i < numSpans and i is d.key

    diagram.tiles.classed "highlight", (_, i) ->
      i < numSpans and i is d.key

    return
  code = d3.select(id_code).selectAll("span.table span")
  code_parity = d3.select(id_code).selectAll("span.parity")
  numSpans = code[0].length
  cubes = []
  i = 0

  while i < (numSpans * 7 / 6)
    unless converter?
      cubes.push (if i < 6 then Cube.direction(i) else new Cube(0, 0, 0))
    else
      cubes.push new Cube(i, -i, 0)
    i++
  diagram = makeGridDiagram(d3.select(id_diagram), cubes)
  diagram.parity_var = parity_var
  diagram.converter = converter
  diagram.nodes.forEach (d, i) ->
    d.direction = (if (i < numSpans) then (i % 6) else null)
    d.key = i
    return

  if converter
    diagram.addLabels()
  else
    diagram.addCubeCoordinates false
  if diagram.converter
    diagram.onUpdate ->
      diagram.tiles.selectAll("text").text (d) ->
        if d.key < numSpans
          h = neighbor(d.key >= 6, d.direction)
          [
            "q"
            (if h.q > 0 then "+" else "")
            (if h.q is 0 then "" else h.q)
            ", "
            "r"
            (if h.r > 0 then "+" else "")
            (if h.r is 0 then "" else h.r)
          ].join ""
        else if numSpans is 12
          (if (d.key is 12) then "EVEN" else "ODD")
        else
          "axial"

      code_parity.text diagram.parity_var
      code.text (_, i) ->
        fmt = (x) ->
          if x > 0
            x = "+" + x
          else
            x = "" + x
          x = " " + x  if x.length < 2
          x
        h = neighbor(i >= 6, i % 6)
        [
          "["
          fmt(h.q)
          ", "
          fmt(h.r)
          "]"
        ].join ""

      return

  diagram.onLayout ->
    offcenter = (if diagram.orientation then new Cube(4, -4, 0) else new Cube(4, -2, -2))
    diagram.nodes.forEach (d, i) ->
      if i < 6
        d.cube = Cube.direction(i)
      else if i < 12 and numSpans is 12
        d.cube = Cube.direction(i % 6).add(offcenter)
      else if i is 13
        d.cube = offcenter
      else
        d.cube = new Cube(0, 0, 0)
      return

    return

  diagram.tiles.on("mouseover", setSelection).on "touchstart", setSelection
  diagram
makeDistances = ->
  diagram = makeGridDiagram(d3.select("#diagram-distances"), Grid.hexagonalShape(5)).addCubeCoordinates(false)
  diagram.tiles.each (d) ->
    len = d.cube.length()
    text = d3.select(this)
    text.select(".q").classed "highlight", Math.abs(d.cube.v[0]) is len
    text.select(".s").classed "highlight", Math.abs(d.cube.v[1]) is len
    text.select(".r").classed "highlight", Math.abs(d.cube.v[2]) is len
    return

  diagram
adjustTextForOrientation = (orientation) ->
  d3.selectAll(".orientation-index-adjust-degrees").text (if orientation then " + 30°" else "")
  d3.selectAll(".orientation-index-adjust").text (if orientation then "(i + 0.5)" else "i")
  d3.selectAll(".orientation-vertical-horizontal").text (if orientation then "horizontal" else "vertical")
  d3.selectAll(".orientation-horizontal-vertical").text (if orientation then "vertical" else "horizontal")
  d3.selectAll(".orientation-height-width").text (if orientation then "width" else "height")
  d3.selectAll(".orientation-width-height").text (if orientation then "height" else "width")
  d3.selectAll(".orientation-vert-horiz").text (if orientation then "horiz" else "vert")
  d3.selectAll(".orientation-horiz-vert").text (if orientation then "vert" else "horiz")
  d3.selectAll(".orientation-northwest-north").text (if orientation then "northwest" else "north")
  return

# Rotation of a hex vector
makeRotation = ->
  redraw = ->
    left1 = target.rotateLeft()
    right1 = target.rotateRight()
    left2 = left1.rotateLeft()
    right2 = right1.rotateRight()
    opposite = right2.rotateRight()
    makeArrow arrow_target, 5, 0, diagram.grid.hexToCenter(center), diagram.grid.hexToCenter(target)
    makeArrow arrow_left, 3, 25, diagram.grid.hexToCenter(target), diagram.grid.hexToCenter(left1)
    makeArrow arrow_right, 3, 25, diagram.grid.hexToCenter(target), diagram.grid.hexToCenter(right1)
    diagram.tiles.classed("center", (d) ->
      d.cube.equals center
    ).classed("target", (d) ->
      d.cube.equals target
    ).classed("opposite", (d) ->
      d.cube.equals opposite
    ).classed("left1", (d) ->
      d.cube.equals left1
    ).classed("right1", (d) ->
      d.cube.equals right1
    ).classed("left2", (d) ->
      d.cube.equals left2
    ).classed "right2", (d) ->
      d.cube.equals right2

    return
  diagram = makeGridDiagram(d3.select("#diagram-rotation"), Grid.hexagonalShape(5)).addCubeCoordinates(false)
  target = new Cube(0, 0, 0)
  diagram.tiles.on("mouseover", (d) ->
    target = d.cube
    redraw()
    return
  ).on("touchstart", (d) ->
    target = d.cube
    redraw()
    return
  ).on "touchmove", (d) ->
    target = d.cube
    redraw()
    return

  arrow_target = diagram.root.append("path").attr("class", "arrow target")
  arrow_left = diagram.root.append("path").attr("class", "arrow left")
  arrow_right = diagram.root.append("path").attr("class", "arrow right")
  center = new Cube(0, 0, 0)
  diagram.onUpdate redraw
  diagram

# Spiral ring is a union of rings, but I use the same code for a single ring
makeSpiral = (id, spiral) ->
  redraw = ->
    
    # Here's the spiral ring algorithm as described in the article
    results = [new Cube(0, 0, 0)]
    k = (if spiral then 1 else N)

    while k <= N
      H = Cube.direction(4).scale(k)
      i = 0

      while i < 6
        j = 0

        while j < k
          results.push H
          H = H.add(Cube.direction(i))
          j++
        i++
      k++
    results_set = d3.set(results)
    diagram.tiles.classed "ring", (d) ->
      (d.key isnt "0,0,0" or spiral or N is 0) and results_set.has(d.cube)

    
    # Also draw arrows showing the order in which we traversed hexes
    arrows = diagram.root.selectAll("path.arrow").data(d3.range(results.length - 1))
    arrows.exit().remove()
    arrows.enter().append("path").attr "class", "arrow"
    arrows.each (d) ->
      makeArrow d3.select(this), 4, 15, diagram.grid.hexToCenter(results[d]), diagram.grid.hexToCenter(results[d + 1])
      return

    return
  diagram = makeGridDiagram(d3.select("#" + id), Grid.hexagonalShape(5))
  N = 0
  diagram.tiles.on("mouseover", (d) ->
    N = d.cube.length()
    redraw()
    return
  ).on("touchstart", (d) ->
    N = d.cube.length()
    redraw()
    return
  ).on "touchmove", (d) ->
    N = d.cube.length()
    redraw()
    return

  diagram.onUpdate redraw
  diagram

# Helper function used for hex regions. A hex shaped region is the
# subset of hexes where a <= x <= b, c <= y <= d, e <= z <= f
colorRegion = (diagram, xmin, xmax, ymin, ymax, zmin, zmax, label) ->
  
  # Here's the range algorithm as described in the article
  results = d3.set()
  x = xmin

  while x <= xmax
    y = Math.max(ymin, -x - zmax)

    while y <= Math.min(ymax, -x - zmin)
      z = -x - y
      results.add new Cube(x, y, z)
      y++
    x++
  diagram.tiles.classed label, (d) ->
    results.has d.cube

  return
makeHexRegion = ->
  moveLine = (line, a, b) ->
    a = diagram.grid.hexToCenter(a)
    b = diagram.grid.hexToCenter(b)
    d = b.subtract(a)
    d = d.normalize().scale(300)  if d.length() > 0
    line.attr("x1", a.x - d.x).attr("y1", a.y - d.y).attr("x2", b.x + d.x).attr "y2", b.y + d.y
    return
  redraw = ->
    colorRegion diagram, -N, N, -N, N, -N, N, "region"
    moveLine xline1, new Cube(N, -N, 0), new Cube(N, 0, -N)
    moveLine xline2, new Cube(-N, N, 0), new Cube(-N, 0, N)
    moveLine yline1, new Cube(-N, N, 0), new Cube(0, N, -N)
    moveLine yline2, new Cube(N, -N, 0), new Cube(0, -N, N)
    moveLine zline1, new Cube(-N, 0, N), new Cube(0, -N, N)
    moveLine zline2, new Cube(N, 0, -N), new Cube(0, N, -N)
    return
  diagram = makeGridDiagram(d3.select("#diagram-hex-range"), Grid.hexagonalShape(5))
  xline1 = diagram.root.append("line").attr("class", "x-axis")
  xline2 = diagram.root.append("line").attr("class", "x-axis")
  yline1 = diagram.root.append("line").attr("class", "y-axis")
  yline2 = diagram.root.append("line").attr("class", "y-axis")
  zline1 = diagram.root.append("line").attr("class", "z-axis")
  zline2 = diagram.root.append("line").attr("class", "z-axis")
  N = 0
  diagram.tiles.on("mouseover", (d) ->
    N = d.cube.length()
    redraw()
    return
  ).on("touchstart", (d) ->
    N = d.cube.length()
    redraw()
    return
  ).on "touchmove", (d) ->
    N = d.cube.length()
    redraw()
    return

  diagram.onUpdate redraw
  diagram
makeIntersection = ->
  redraw = ->
    N = 3
    x = center.v[0]
    y = center.v[1]
    z = center.v[2]
    
    # This region is fixed
    colorRegion diagram, -4 - N, -4 + N, -N, N, 4 - N, 4 + N, "regionB"
    
    # This region is moved by the user
    colorRegion diagram, x - N, x + N, y - N, y + N, z - N, z + N, "regionA"
    
    # This region is the intersection of the first two
    colorRegion diagram, Math.max(-4 - N, x - N), Math.min(-4 + N, x + N), Math.max(-N, y - N), Math.min(N, y + N), Math.max(4 - N, z - N), Math.min(4 + N, z + N), "regionC"
    
    # Always draw the hex the user has selected
    colorRegion diagram, x, x, y, y, z, z, "center"
    return
  diagram = makeGridDiagram(d3.select("#diagram-intersection"), Grid.hexagonalShape(7))
  center = new Cube(0, 0, 0)
  diagram.tiles.on("mouseover", (d) ->
    center = d.cube
    redraw()
    return
  ).on("touchstart", (d) ->
    center = d.cube
    redraw()
    return
  ).on "touchmove", (d) ->
    center = d.cube
    redraw()
    return

  diagram.onUpdate redraw
  diagram
makeMovementRange = ->
  redraw = ->
    maxMovement = 4
    start = new Cube(0, 0, 0)
    visited = d3.map()
    visited.set start, 0
    fringes = [[start]]
    k = 0

    while k < maxMovement
      fringes[k + 1] = []
      fringes[k].forEach (cube) ->
        dir = 0

        while dir < 6
          neighbor = cube.add(Cube.direction(dir))
          if not visited.has(neighbor) and not diagram.selected.has(neighbor)
            visited.set neighbor, k + 1
            fringes[k + 1].push neighbor
          dir++
        return

      k++
    diagram.tiles.classed("blocked", (d) ->
      diagram.selected.has d.cube
    ).classed "center", (d) ->
      d.cube.v[0] is 0 and d.cube.v[1] is 0 and d.cube.v[2] is 0

    diagram.tiles.selectAll("text").text (d) ->
      (if visited.has(d.cube) then visited.get(d.cube) else "")

    return
  diagram = makeGridDiagram(d3.select("#diagram-movement-range"), Grid.hexagonalShape(5)).addLabels()
  diagram.makeTilesSelectable redraw
  diagram.toggle new Cube(2, -1, -1)
  diagram.toggle new Cube(2, -2, 0)
  diagram.toggle new Cube(1, -2, 1)
  diagram.toggle new Cube(0, -2, 2)
  diagram.onUpdate redraw
  diagram

# Line drawing demo has one endpoint fixed and other following the mouse
makeLineDrawer = ->
  
  # HACK: we get better behavior if we're slightly off-center. This
  # is because it breaks ties (which happen often), forcing
  # rounding to go in a consistent direction. I'm not that happy
  # about this but it's an easy way to make the algorithm work for
  # the common case, which has way too many ties.
  redraw = ->
    d = goal.subtract(start)
    N = 1
    i = 0

    while i < 3
      distance = Math.abs(d.v[i])
      N = distance  if distance > N
      i++
    selection = d3.set()
    data = []
    prev = new Cube(0, 0, -999)
    i = 0

    while i <= N
      hex = start.add(d.scale(i / N))
      p = diagram.grid.hexToCenter(hex)
      
      # NOTE: this is more complicate than it needs to be,
      # because there's only one element in the offsets
      # array. However, I'm planning to also use it for "super
      # cover", which will have multiple offsets in the
      # array. That's for a future version of the article. For
      # the simple version, see the loop presented in the
      # article text.
      offsets.forEach (offset) ->
        hex2 = hex.add(offset).round()
        p2 = diagram.grid.hexToCenter(hex2)
        data.push
          hex: hex
          p: p
          hex2: hex2
          p2: p2

        unless hex2.equals(prev)
          selection.add hex2
          prev = hex2
        return

      i++
    diagram.tiles.classed "selected", (d) ->
      selection.has d.cube

    root_path.select("path").remove()
    path = root_path.append("path").attr("stroke", "hsla(0, 0%, 0%, 0.15)").attr("stroke-width", "4.5px").attr("d", [
      "M"
      data[0].p
      "L"
      data[data.length - 1].p
    ].join(" "))
    exacts = root_exacts.selectAll("circle.exact").data(data, (d, i) ->
      i
    )
    exacts.exit().remove()
    exacts.enter().append("circle").attr("class", "exact").attr("fill", "blue").attr("stroke", "hsla(0, 0%, 100%, 0.5)").attr("stroke-width", "2px").attr "r", 2.5
    exacts.attr "transform", (d) ->
      "translate(" + d.p + ")"

    return
  diagram = makeGridDiagram(d3.select("#diagram-line"), Grid.hexagonalShape(7))
  diagram.tiles.on("mouseover", (d) ->
    goal = d.cube
    redraw()
    return
  ).on("touchstart", (d) ->
    goal = d.cube
    redraw()
    return
  ).on "touchmove", (d) ->
    goal = d.cube
    redraw()
    return

  svg = diagram.root
  root = svg.append("g")
  root_centers = root.append("g")
  root_path = root.append("g")
  root_lines = root.append("g")
  root_exacts = root.append("g")
  offsets = [Cube.direction(1).scale(0.00001)]
  start = new Cube(-5, 5, 0)
  goal = new Cube(0, 0, 0)
  diagram.onUpdate redraw
  diagram

# Simple but slow field of view calculation (may not be best accuracy)
makeFieldOfView = ->
  redraw = ->
    visible = d3.set()
    center = new Cube(0, 0, 0)
    x = 0

    while x < N
      [
        new Cube(N - x, x, -N)
        new Cube(x, -N, N - x)
        new Cube(-N, N - x, x)
        new Cube(-N + x, -x, N)
        new Cube(-x, N, -N + x)
        new Cube(N, -N + x, -x)
      ].forEach (corner) ->
        path = Cube.makeLine(center.add(corner.scale(1e-6)), corner)
        i = 0

        while i < path.length
          break  if diagram.selected.has(path[i])
          visible.add path[i]
          i++
        return

      x++
    diagram.tiles.classed("shadow", (d) ->
      not visible.has(d.cube)
    ).classed("blocked", (d) ->
      diagram.selected.has d.cube
    ).classed "center", (d) ->
      d.cube.v[0] is 0 and d.cube.v[1] is 0 and d.cube.v[2] is 0

    return
  N = 8
  diagram = makeGridDiagram(d3.select("#diagram-field-of-view"), Grid.hexagonalShape(N))
  diagram.makeTilesSelectable redraw
  diagram.toggle new Cube(3, 0, -3)
  diagram.toggle new Cube(2, 1, -3)
  diagram.toggle new Cube(1, 2, -3)
  diagram.onUpdate redraw
  diagram
makeHexToPixel = ->
  addArrow = (p1, p2) ->
    p1 = diagram.grid.hexToCenter(p1)
    p2 = diagram.grid.hexToCenter(p2)
    makeArrow diagram.root.append("path"), 3, 20, p1, p2.scale(0.8).add(p1.scale(0.2))
    return
  diagram = makeGridDiagram(d3.select("#diagram-hex-to-pixel"), Grid.trapezoidalShape(0, 1, 0, 1, Grid.oddRToCube))
  diagram.update 80, true
  A = Grid.oddRToCube(new Hex(0, 0))
  Q = Grid.oddRToCube(new Hex(1, 0))
  R = Grid.oddRToCube(new Hex(0, 1))
  B = Grid.oddRToCube(new Hex(1, 1))
  diagram.addLabels (d) ->
    return "A"  if d.key is A.toString()
    return "Q"  if d.key is Q.toString()
    return "R"  if d.key is R.toString()
    "B"  if d.key is B.toString()

  addArrow A, Q
  addArrow A, R
  addArrow A, B
  diagram

# TODO: make this work in either orientation
makePixelToHex = ->
  diagram = makeGridDiagram(d3.select("#diagram-pixel-to-hex"), Grid.hexagonalShape(2))
  diagram.addCubeCoordinates false
  diagram.update 60, true
  marker = diagram.root.append("circle")
  marker.attr("fill", "blue").attr "r", 5
  diagram.root.on "mousemove", ->
    size = diagram.scale / 2
    xy = d3.mouse(diagram.root.node())
    xy =
      x: xy[0]
      y: xy[1]

    q = (1 / 3 * Math.sqrt(3) * xy.x + -1 / 3 * xy.y) / size
    r = 2 / 3 * xy.y / size
    cube = new Cube(q, -q - r, r).round()
    marker.attr "transform", "translate(" + diagram.grid.hexToCenter(new Cube(q, -q - r, r)) + ")"
    diagram.tiles.classed "highlight", (d) ->
      d.cube.equals cube

    return

  diagram

# TODO: make this work in either orientation

# Hex to pixel code is updated to match selected grid type
updateHexToPixelAxial = (orientation) ->
  code = d3.selectAll("#hex-to-pixel-code-axial span")
  code.style "display", (_, i) ->
    (if (i is orientation) then "none" else "inline")

  return
updateHexToPixelOffset = (style) ->
  code = d3.selectAll("#hex-to-pixel-code-offset span").data(updateHexToPixelOffset.styles)
  code.style "display", (d) ->
    (if (d is style) then "inline" else "none")

  return
makeMapStorage = (config, scale) ->
  # just rebuild the whole thing on each shape change…
  
  # Write the code used for accessing the grid
  
  # Build the hex grid
  
  # Build a square grid that can cover the range of axial grid coordinates
  
  # Each grid should highlight things in the other grid
  highlight = (cube) ->
    diagram.tiles.classed "highlight", (node) ->
      node.cube.equals cube

    squares.classed "highlight", (node) ->
      node.cube.equals cube

    diagram.tiles.classed "samerow", (node) ->
      node.cube.v[2] is cube.v[2]

    squares.classed "samerow", (node) ->
      node.cube.v[2] is cube.v[2]

    return
  shape = config[0]
  access_text = config[1]
  svg = d3.select("#diagram-map-storage-shape")
  svg.selectAll("*").remove()
  d3.select("#map-storage-formula").text access_text
  diagram = makeGridDiagram(svg, shape)
  diagram.addHexCoordinates Grid.cubeToTwoAxis, false
  diagram.update scale, true
  hexSet = d3.set()
  first_column = []
  minQ = 0
  maxQ = 0
  minR = 0
  maxR = 0
  diagram.nodes.forEach (node) ->
    q = node.cube.v[0]
    r = node.cube.v[2]
    hexSet.add node.cube
    minQ = q  if q < minQ
    maxQ = q  if q > maxQ
    minR = r  if r < minR
    maxR = r  if r > maxR
    first_column[r] = q  unless q > first_column[r]
    return

  s_size = 260 / (maxR - minR + 1)
  storage = {}
  storage.svg = d3.select("#diagram-map-storage-array")
  storage.svg.selectAll("*").remove()
  storage.nodes = []
  r = minR

  while r <= maxR
    storage.svg.append("text").attr("transform", "translate(10," + (22.5 + 4 + (r - minR + 0.5) * s_size) + ")").text first_column[r]
    q = minQ

    while q <= maxQ
      storage.nodes.push
        cube: new Cube(q, -q - r, r)
        q: q
        r: r

      q++
    r++
  squares = storage.svg.selectAll("g").data(storage.nodes)
  squares.enter().append("g").each (d) ->
    g = d3.select(this)
    d.square = g
    g.attr "transform", "translate(" + ((d.q - minQ) * s_size) + "," + ((d.r - minR) * s_size) + ") translate(25, 22.5)"
    g.append("rect").attr("width", s_size).attr "height", s_size
    g.append("text").text(d.q + ", " + d.r).attr("y", "0.4em").attr "transform", "translate(" + (s_size / 2) + "," + (s_size / 2) + ")"
    g.classed "unused", not hexSet.has(d.cube)
    return

  diagram.tiles.on "mouseover", (d) ->
    highlight d.cube
    return

  squares.on "mouseover", (d) ->
    highlight d.cube
    return

  return

# Map storage shape is controlled separately, and orientation can't be set
makeWraparound = ->
  # Called "L" in the article text
  # Called "M" in the article text
  setSelection = (cube) ->
    diagram.tiles.classed "highlight", (d, i) ->
      shape_mirror[i].equals cube

    return
  N = 2
  shape = []
  shape_center = []
  shape_mirror = []
  baseShape = Grid.hexagonalShape(N)
  centers = [new Cube(0, 0, 0)]
  center = new Cube(N * 2 + 1, -N, -N - 1)
  dir = 0

  while dir < 6
    centers.push center
    center = center.rotateRight()
    dir++
  centers.forEach (c) ->
    baseShape.forEach (b) ->
      shape.push b.add(c)
      shape_center.push c
      shape_mirror.push b
      return

    return

  diagram = makeGridDiagram(d3.select("#diagram-wraparound"), shape)
  diagram.update 30, true
  diagram.tiles.classed("center", (d, i) ->
    shape_mirror[i].length() is 0
  ).classed("wrapped", (d) ->
    d.cube.length() > 2
  ).classed "parity", (d, i) ->
    c = shape_center[i]
    a = c.length()
    c.v[0] is a or c.v[1] is a or c.v[2] is a

  diagram.tiles.on "mouseover", (d, i) ->
    setSelection shape_mirror[i]
    return

  diagram

# Create all the diagrams that can be reoriented
orient = (orientation) ->
  diagram_parts orientation
  diagram_angles orientation
  diagram_spacing orientation
  grid_cube.update 50, orientation
  grid_axial.update 50, orientation
  neighbors_cube.update 100, orientation
  neighbors_axial.update 100, orientation
  neighbors_diagonal.update 75, orientation
  diagram_distances.update 45, orientation
  diagram_lines.update 33, orientation
  diagram_fov.update 27, orientation
  diagram_rotation.update 45, orientation
  diagram_rings.update 45, orientation
  diagram_spiral.update 45, orientation
  diagram_movement_range.update 45, orientation
  diagram_hex_region.update 45, orientation
  diagram_intersection.update 33, orientation
  
  # HACK: invading cubegrid.js space; should support this directly in cubegrid.js diagram object
  delay d3.select("#cube-to-hex"), (animate) ->
    animate(d3.select("#cube-to-hex > g")).attr "transform", "translate(139.5, 139.5) rotate(" + ((not orientation) * 30) + ")"
    return

  adjustTextForOrientation orientation
  d3.selectAll("button.flat").classed "highlight", not orientation
  d3.selectAll("button.pointy").classed "highlight", orientation
  return
console.info "I'm happy to answer questions about the code — email me at redblobgames@gmail.com"
idle_tracker =
  interval: 1000
  idle_threshold: 1000
  running: false
  needs_to_run: false
  last_activity: Date.now()
  callback: null

idle_tracker.user_activity = (e) ->
  @last_activity = Date.now()
  return

idle_tracker.loop = ->
  idle_tracker.running = setTimeout(idle_tracker.loop, idle_tracker.interval)
  idle_tracker.callback()  if idle_tracker.needs_to_run or Date.now() - idle_tracker.last_activity > idle_tracker.idle_threshold
  idle_tracker.needs_to_run = false
  return

idle_tracker.start = ->
  @needs_to_run = true
  unless @running
    @running = setTimeout(@loop, 0)
    window.addEventListener "scroll", @user_activity
    window.addEventListener "touchmove", @user_activity
  else
    clearTimeout @running
    @running = setTimeout(@loop, 1)
  return

idle_tracker.stop = ->
  if @running
    window.removeEventListener "scroll", @user_activity
    window.removeEventListener "touchmove", @user_activity
    clearTimeout @running
    @running = false
  return

delay.queue = d3.map()
delay.refresh = d3.set()
idle_tracker.callback = _delayDrawOnTimeout
window.addEventListener "scroll", _delayedDraw
window.addEventListener "resize", _delayedDraw
makeGridDiagram(d3.select("#grid-offset-odd-q"), Grid.trapezoidalShape(0, 7, 0, 5, Grid.oddQToCube)).addHexCoordinates(Grid.cubeToOddQ, true).update 30, false
makeGridDiagram(d3.select("#grid-offset-even-q"), Grid.trapezoidalShape(0, 7, 0, 5, Grid.evenQToCube)).addHexCoordinates(Grid.cubeToEvenQ, true).update 30, false
makeGridDiagram(d3.select("#grid-offset-odd-r"), Grid.trapezoidalShape(0, 6, 0, 6, Grid.oddRToCube)).addHexCoordinates(Grid.cubeToOddR, true).update 30, true
makeGridDiagram(d3.select("#grid-offset-even-r"), Grid.trapezoidalShape(0, 6, 0, 6, Grid.evenRToCube)).addHexCoordinates(Grid.cubeToEvenR, true).update 30, true
makeHexToPixel()
makePixelToHex()
updateHexToPixelAxial true
d3.select("#hex-to-pixel-axial-pointy").on("change", ->
  updateHexToPixelAxial true
  return
).node().checked = true
d3.select("#hex-to-pixel-axial-flat").on "change", ->
  updateHexToPixelAxial false
  return

updateHexToPixelOffset.styles = [
  "oddR"
  "evenR"
  "oddQ"
  "evenQ"
]
updateHexToPixelOffset.styles.forEach (style) ->
  d3.select("#hex-to-pixel-offset-" + style).on "change", ->
    updateHexToPixelOffset style
    return

  return

updateHexToPixelOffset "oddR"
d3.select("#hex-to-pixel-offset-oddR").node().checked = true
_mapStorage = [
  [
    Grid.trapezoidalShape(0, 5, 0, 5, Grid.oddRToCube)
    "array[r][q + r/2]"
  ]
  [
    Grid.triangularShape(5)
    "array[r][q]"
  ]
  [
    Grid.hexagonalShape(3)
    "array[r + N][q + N + min(0, r)]"
  ]
  [
    Grid.trapezoidalShape(0, 5, 0, 5, Grid.twoAxisToCube)
    "array[r][q]"
  ]
]
makeMapStorage _mapStorage[0], 60
d3.select("#map-storage-rectangle").node().checked = true
d3.select("#map-storage-rectangle").on "change", ->
  makeMapStorage _mapStorage[0], 60
  return

d3.select("#map-storage-triangle").on "change", ->
  makeMapStorage _mapStorage[1], 60
  return

d3.select("#map-storage-hexagon").on "change", ->
  makeMapStorage _mapStorage[2], 50
  return

d3.select("#map-storage-rhombus").on "change", ->
  makeMapStorage _mapStorage[3], 60
  return

makeWraparound()
diagram_parts = makeParts()
diagram_angles = makeAngles()
diagram_spacing = makeSpacing()
grid_cube = makeGridDiagram(d3.select("#grid-cube"), Grid.hexagonalShape(3)).addCubeCoordinates(true)
grid_axial = makeGridDiagram(d3.select("#grid-axial"), Grid.hexagonalShape(3)).addHexCoordinates(Grid.cubeToTwoAxis, true)
neighbors_cube = makeNeighbors("#neighbors-cube", "#neighbors-cube-code")
neighbors_axial = makeNeighbors("#neighbors-axial", "#neighbors-axial-code", Grid.cubeToTwoAxis, "")
neighbors_diagonal = makeGridDiagram(d3.select("#neighbors-diagonal"), Grid.hexagonalShape(1).concat([
  new Cube(2, -1, -1)
  new Cube(-2, 1, 1)
  new Cube(-1, 2, -1)
  new Cube(1, -2, 1)
  new Cube(-1, -1, 2)
  new Cube(1, 1, -2)
])).addCubeCoordinates(false)
neighbors_diagonal.tiles.classed "highlight", (d) ->
  d.cube.length() is 2

diagram_distances = makeDistances()
diagram_lines = makeLineDrawer()
diagram_fov = makeFieldOfView()
diagram_rotation = makeRotation()
diagram_rings = makeSpiral("diagram-rings", false)
diagram_spiral = makeSpiral("diagram-spiral", true)
diagram_movement_range = makeMovementRange()
diagram_hex_region = makeHexRegion()
diagram_intersection = makeIntersection()
orient true

# Offset neighbors are controlled separately
neighbors_offset = makeNeighbors("#neighbors-offset", "#neighbors-offset-code", Grid.cubeToOddR, "r").update(65, true)
d3.select("#neighbors-offset-odd-r").node().checked = true
d3.select("#neighbors-offset-odd-r").on "change", ->
  neighbors_offset.converter = Grid.cubeToOddR
  neighbors_offset.parity_var = "r"
  neighbors_offset.update 65, true
  return

d3.select("#neighbors-offset-even-r").on "change", ->
  neighbors_offset.converter = Grid.cubeToEvenR
  neighbors_offset.parity_var = "r"
  neighbors_offset.update 65, true
  return

d3.select("#neighbors-offset-odd-q").on "change", ->
  neighbors_offset.converter = Grid.cubeToOddQ
  neighbors_offset.parity_var = "q"
  neighbors_offset.update 65, false
  return

d3.select("#neighbors-offset-even-q").on "change", ->
  neighbors_offset.converter = Grid.cubeToEvenQ
  neighbors_offset.parity_var = "q"
  neighbors_offset.update 65, false
  return

delay.pageLoaded = true