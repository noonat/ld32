'use strict'

_canvas = document.createElement 'canvas'
_scale = 4
_scaled = {}
_width = 900
_height = 600
_game = new Phaser.Game(_width, _height, Phaser.AUTO, 'phaser')


abs = (value) ->
  if value >= 0
    value
  else
    -value


sign = (value) ->
  if value >= 0
    1
  else
    -1


# Trigger a breakpoint inside the game file, so the web inspector can be
# used to debug game variables.
#
window.debugGame = -> debugger


# Load a single image and scale it up
#
loadScaledImage = (url, callback, callbackContext) ->
  image = null

  onImageLoaded = ->
    width = image.width
    height = image.height
    scaledWidth = width * _scale
    scaledHeight = height * _scale

    _canvas.width = scaledWidth
    _canvas.height = scaledHeight
    context = _canvas.getContext '2d'
    context.clearRect(0, 0, scaledWidth, scaledHeight)

    context.drawImage(image, 0, 0)
    imageData = context.getImageData(0, 0, width, height)
    data = imageData.data

    scaledImageData = context.createImageData(scaledWidth, scaledHeight)
    scaledData = scaledImageData.data

    for y in [0..height]
      for x in [0..width]
        index = (y * width * 4) + (x * 4)
        r = data[index + 0]
        g = data[index + 1]
        b = data[index + 2]
        a = data[index + 3]
        scaledX = x * _scale
        scaledY = y * _scale
        scaledIndex = (scaledY * scaledWidth * 4) + (scaledX * 4)
        for sy in [0.._scale]
          for sx in [0.._scale]
            si = scaledIndex + (sy * scaledWidth * 4) + (sx * 4)
            scaledData[si + 0] = r
            scaledData[si + 1] = g
            scaledData[si + 2] = b
            scaledData[si + 3] = a

    context.clearRect(0, 0, scaledWidth, scaledHeight)
    context.putImageData(scaledImageData, 0, 0)
    callback.call(callbackContext, url, _canvas.toDataURL())

  image = document.createElement('img')
  image.onload = onImageLoaded
  image.src = url


# Load a list of images and scale them up
#
loadScaledImages = (urls, callback, context) ->
  numImages = urls.length
  numLoadedImages = 0
  onImageScaled = (url, scaledUrl) ->
    _scaled[url] = scaledUrl
    numLoadedImages++
    callback.call(context) if numLoadedImages >= numImages
  for url in urls
    loadScaledImage(url, onImageScaled)


class Player

  gravity: 1000
  jumpDuration: 750
  jumpSpeed: 500
  walkSpeed: 150

  constructor: (@game, x, y) ->
    @jumpTimer = 0

    @sprite = @game.add.sprite(x, y, 'player', 0)
    @sprite.anchor.setTo(0.5, 0.5)
    @sprite.smoothed = false

    @sprite.animations.add('stand', [0], 60, false)
    @sprite.animations.add('walk', [1, 2, 3, 0], 5, true)
    @sprite.animations.play('stand')

    @game.physics.enable(@sprite, Phaser.Physics.ARCADE)
    @sprite.body.collideWorldBounds = true
    @sprite.body.gravity.y = @gravity
    @sprite.body.maxVelocity.y = @jumpSpeed
    @sprite.body.setSize(16, 32, 0, 16)


  update: (keys) ->
    dirX = 0
    dirY = 0
    dirX -= 1 if keys.left.isDown
    dirX += 1 if keys.right.isDown

    if dirX < 0
      @sprite.animations.play('walk')
      @sprite.scale.x = -1
    else if dirX > 0
      @sprite.animations.play('walk')
      @sprite.scale.x = 1
    else
      @sprite.animations.play('stand')
    @sprite.body.velocity.x = @walkSpeed * dirX

    if ((keys.jump.isDown or keys.up.isDown) and @sprite.body.onFloor() and
        @game.time.now > @jumpTimer)
      @sprite.body.velocity.y = -@jumpSpeed
      @jumpTimer = @game.time.now + @jumpDuration


class Mutant

  gravity: 1000
  jumpSpeed: 500
  walkSpeed: 100

  constructor: (@game, x, y) ->
    @sprite = @game.add.sprite(x, y, 'mutant', 0)
    @sprite.anchor.setTo(0.5, 0.5)
    @sprite.smoothed = false

    @sprite.animations.add('stand', [0], 60, false)
    @sprite.animations.add('walk', [1, 2, 3, 4], 5, true)
    @sprite.animations.play('stand')

    @game.physics.enable(@sprite, Phaser.Physics.ARCADE)
    @sprite.body.collideWorldBounds = true
    @sprite.body.gravity.y = @gravity
    @sprite.body.maxVelocity.y = @jumpSpeed
    @sprite.body.setSize(16, 32, 0, 16)

  update: (player) ->
    deltaX = player.sprite.x - @sprite.x
    if abs(deltaX) > 100
      @sprite.animations.play('walk')
      @sprite.body.velocity.x = @walkSpeed * sign(deltaX)
      @sprite.scale.x = sign(deltaX)
    else
      @sprite.animations.play('stand')
      @sprite.body.velocity.x = 0


_game.state.add 'menu',

  create: ->
    playButtonGraphics = @game.make.graphics(0, 0)
    playButtonGraphics.beginFill(Phaser.Color.getColor(255, 255, 255), 1.0)
    playButtonGraphics.drawRect(0, 0, 200, 50)
    playButtonGraphics.endFill()
    playButtonText = @game.make.text(70, 7, 'Play')
    playButton = @game.add.button((_width - 200) / 2, (_height - 50) / 2,
                                  null, @playButtonClicked, this)
    playButton.addChild(playButtonGraphics)
    playButton.addChild(playButtonText)

  playButtonClicked: ->
    @game.state.start 'play'


_game.state.add 'play',

  preload: ->
    @load.image('tiles', _scaled['/assets/tiles.png'])
    @load.spritesheet('player', _scaled['/assets/player.png'], 64, 64)
    @load.spritesheet('mutant', _scaled['/assets/mutant.png'], 64, 64)

  create: ->
    @stage.backgroundColor = '#dbecff'

    @game.physics.startSystem(Phaser.Physics.ARCADE)
    @game.physics.arcade.gravity.y = 300

    @map = new Phaser.Tilemap(@game, null, 32, 32, 60, 20)
    @map.addTilesetImage('tiles')
    @layer = @map.createBlankLayer('dirt', 60, 20, 32, 32)
    @layer.resizeWorld()
    @camera.setBoundsToWorld()
    @map.fill(1, 0, 19, 60, 1)
    @map.setCollision(1)

    @keys = @game.input.keyboard.createCursorKeys()
    @keys.jump = @game.input.keyboard.addKey(Phaser.Keyboard.SPACEBAR)
    @player = new Player(@game, @world.width / 2, @game.height - 64)
    @camera.follow(@player.sprite, Phaser.Camera.FOLLOW_PLATFORMER)

    @mutant = new Mutant(@game, @world.width / 2 - 100, @game.height - 64)

  update: ->
    @game.physics.arcade.collide(@player.sprite, @layer)
    @game.physics.arcade.collide(@mutant.sprite, @layer)
    @player.update(@keys)
    @mutant.update(@player)


window.addEventListener('load', ->
  loadScaledImages([
    '/assets/mutant.png'
    '/assets/player.png'
    '/assets/tiles.png'
  ], -> _game.state.start('play'))
, false)
