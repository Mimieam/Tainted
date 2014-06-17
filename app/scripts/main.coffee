"use strict"

# $(document).ready( () -> 
console.log "'Allo from CoffeeScript!"

# convert cube to axial
# q = x
# r = z

# # convert axial to cube
# x = q
# z = r
# y = -x-z

# cube hex ... using x, y, z
    # hexObj =  {
    #   x: ...  
    #   y: ... 
    #   z: ...
    #   id :"nonExistant", 
    #   scale:...., 
    #   orientation: ...
    # }
class Hex
  constructor: (@x, @y, @z, @id ,@scale, @orientation) ->
    if typeof @x is "object"
      hexObj = @x;
      @points = hexToPolygon hexObj.scale, hexObj.x , hexObj.y, hexObj.orientation
    else   
      @points = hexToPolygon @scale, @x , @y, @orientation
    @status = @id or "empty"

    @neighbors = [
       [+1, -1,  0], [+1,  0, -1], [ 0, +1, -1],
       [-1, +1,  0], [-1,  0, +1], [ 0, -1, +1]
    ]


  getNeighbor: (index) ->  # returns information about a neighbors
    tempHex = {
      x: @x + @neighbors[index][0] or 0,   # 0  index x  
      y: @y + @neighbors[index][1] or 0, 
      z: @z + @neighbors[index][2] or 0,
      id :"nonExistant", 
      scale: @scale, 
      orientation: @orientation
    }
    # toArray: () ->
    translationVector = Map.ScreenCoordinate(Game.scale * (Game.CONST.SQRT_3_2  * (tempHex.x + 0.5 * tempHex.z)),Game.scale * (0.75 * tempHex.z))
    neighborPoints =  hexToPolygon tempHex.scale, tempHex.x , tempHex.y, tempHex.orientation
    console.log translationVector
    AllPts = []
    for i in [0...7]
      AllPts.push neighborPoints[i].x + translationVector.x
      AllPts.push neighborPoints[i].y + translationVector.y
      console.log(AllPts[i-1], AllPts[i])
      # [tempHex.x, tempHex.y,tempHex.z, tempHex.id, tempHex.scale, tempHex.orientation]
    AllPts
  # # getArrayOfPoints: () ->


  #   AllPts
  toString: () ->
    Hex_str = ""+@x+","+@y+","+@z

  update: (@x, @y, @z ,@scale, @orientation) ->
    @points = hexToPolygon @scale, @x , @y, @orientation 


  hexToPolygon = (scale, x, y, orientation) ->
    # create the points of an hex
    points = []
    # console.log "in hexToPolygon --- ",scale, x, y , orientation
    for i in [0..6]
      angle = 2 * Math.PI * (2 * i - orientation) / 12
      points.push {
                   x: x + 0.5 * scale * Math.cos(angle),
                   y: y + 0.5 * scale * Math.sin(angle),
                   z: 0
                  }
      # console.log angle, points[i]
    points

Map = {};
Map.InMemoryMap = {}  #store device representation of the current map

Map.hexagonalShape = (size) -> 
    hexes = []
    _g1 = -size 
    _g = size + 1
    while(_g1 < _g)
        x = _g1
        _g3 = -size
        _g2 = size + 1
        while(_g3 < _g2) 
            y = _g3
            z = -x - y
            if(Math.abs(x) <= size and  Math.abs(y) <= size and  Math.abs(z) <= size) then  hexes.push new Hex x ,y ,z, @id , Game.scale, Game.HexConfig.pointyBottom
            _g3++
        _g1++
    return hexes

Map.ScreenCoordinate = (x,y) ->
  {x:x , y:y}

# Map.toScreen = (H) ->
#   console.log( H.x, H.y, H.z)

Map.toScreen = (H,Y,Z) ->
  console.log( H, Y, Z)
  if typeof H is "object" 
    new  Map.ScreenCoordinate(Game.scale * (Game.CONST.SQRT_3_2  * (H.x + 0.5 * H.z)),Game.scale * (0.75 * H.z))
  else 
    X = H
    new  Map.ScreenCoordinate(Game.scale * (Game.CONST.SQRT_3_2  * (X + 0.5 * Z)),Game.scale * (0.75 * Z))

Map.getTile = (X,Y,Z) ->
  # call to server for updated version of tile
  # if tile exist 
    # return tile 
    # if(Map.myMap){}   -> access/update in memory map  
  # else 
    # create new tile
    new Hex X ,Y ,Z, "unamed" , Game.scale, Game.HexConfig.pointyBottom


Game = {}
Game.CONST= {} # constant variables 
# get canvas and make it fit its parent div 
canvas = document.getElementsByTagName('canvas')[0]
canvasParent = document.querySelector('#game_world')

# canvas.width  = 600
# canvas.height = 600

# game dim = canvas dim
Game.width = $("#game_world").width()
Game.height = $("#game_world").height()

Game.HexConfig = {pointyBottom:true}
Game.viewport = {centerX:Game.width/2, centerY:Game.height/2}

console.log Game

Game.scale = 100
Game.CONST.SQRT_3_2 =  Math.sqrt(3)/2;

# homeHexTile = new Hex Game.viewport.centerX , Game.viewport.centerY ,0 ,'Home', Game.scale , Game.HexConfig.pointyBottom


# hex = new Path { segments: homeHexTile.points}
# hex.strokeColor = '#bada55'
# hex.Hex_info = homeHexTile

Map.myMap = Map.hexagonalShape(2)   # create a map
# console.log Map.myMap
Hexes =  []
for H in Map.myMap
  console.log(H);
  translationVector = Map.toScreen(H);  #find the scaling factor for coordinate of the grid 

  #scale hex coordinate to pixel position
  for i in [0...7]
    H.points[i].x = H.points[i].x + translationVector.x;   
    H.points[i].y = H.points[i].y + translationVector.y;
    console.log(H.points[i].x , H.points[i].y)

  # console.log H
  # # hex = new Path { segments: H.points}
  # hex.strokeColor = '#000555'
  # hex.translate(300,300);
  # hex.Hex_info = H
  # Hexes.push hex

# Snap-svg time:)
s = Snap "#snap-svg"
for H in Map.myMap 
  AllPts = []
  for coord in H.points
    # console.log i , H.points[i]
    AllPts.push coord.x 
    AllPts.push coord.y

  console.log AllPts    
  x = s.polygon(AllPts)
      .transform("t200,200")
  x.Hex = H

  # s.drag();


  x.attr({
    fill: "#bada55",
    stroke: "#000",
    strokeWidth: 2
    })
    .data "info", H.toString()
  console.log H
  x.click () -> 
    console.log @.data "info"
    currentHex =  JSON.parse(@.data "info")
    N = x.Hex.getNeighbor(0)
    console.log x.Hex 
    console.log N
    # N = new Hex x.Hex.neighbors[0][0], x.Hex.neighbors[0][1] ,x.Hex.neighbors[0][2],"taintedBy" ,Game.scale , Game.HexConfig.pointyBottom
    # e.preventDefault()
    v = s.polygon(N)
        .transform("t200,200")
        .attr({
        fill: "#bada55",
        stroke: "#000",
        strokeWidth: 2
        })
        .data "info", H.toString()

    this.attr({fill: "#000555"})

        # console.log "stuff clicked"

#  ============= dragdealerjs
new Dragdealer('game_world')

#==================

# PseudoRamdomizer class 

class PseudoRandomizer 
  constructor: (ulGen1, ulSeed, ulMax) ->
    @ulGen1 = ulGen1
    @ulGen2 = ulGen1 * 2
    @ulSeed = ulSeed
    @ulMax = ulMax

  pseudoRandom: () ->
    ulNewSeed = @ulGen1 * @ulSeed + ulGen2
    ulNewSeed = ulNewSeed % ulMax  # Use modulo operator to ensure < ulMax 
    @ulSeed = ulNewSeed

  pseudoRandom: (ulMaxValue) ->
    @ulMax = ulMaxValue
    @ulNewSeed = ulGen1 * ulSeed + ulGen2
    @ulNewSeed = ulNewSeed % ulMax # Use modulo operator to ensure < ulMax 
    @ulSeed = ulNewSeed


# Universe generator class

class Universe
  constructor:(ulXDimension, ulYDimension) ->
    # set parameters for the new universe
    @ulXDimension = ulXDimension
    @ulYDimension = ulYDimension
    # init randomizer
    @prRandomizer = new PseudoRamdomizer( ulXDimension, ulYDimension, ulXDimension*ulYDimension)

  starAt: (ulXPosition, ulYPosition, ulSerialNumber) ->
    ulRandomValue
    # Set up the serial number for this grid reference
    @ulSerialNumber = ((ulYPosition + 1) * @ulXDimension) + ulXPosition

    for ulco in [0...ulSerialNumber]
      ulRandomValue = @prRandomizer.PseudoRandom()

    # If ulRandomValue falls in the lower 1%, there is a star here
    if (ulRandomValue <= ((@ulXDimension * @ulYDimension) / 100))
      return 1
    0
