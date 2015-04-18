'use strict'

_canvas = document.createElement 'canvas'
_scale = 4
_scaledImageUrls = {}
_width = 900
_height = 600
_game = new Phaser.Game(_width, _height, Phaser.AUTO, 'phaser')

PLAYER_JUMP_DURATION = 750
PLAYER_JUMP_SPEED = 500
PLAYER_WALK_SPEED = 150


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
    callback.call(callbackContext, _canvas.toDataURL())

  image = document.createElement('img')
  image.onload = onImageLoaded
  image.src = url


loadScaledImages = (images, callback, context) ->
  numImages = images.length
  numLoadedImages = 0
  onImageScaled = (url) ->
    image = this
    image.scaledUrl = url
    numLoadedImages++
    if (numLoadedImages >= numImages)
      callback.call(context, images)
  for image in images
    loadScaledImage(image.url, onImageScaled, image)


window.addEventListener('load', ->
  onScaled = (images) ->
    _scaledImageUrls = {}
    _scaledImageUrls = {}
    for image in images
      _scaledImageUrls[image.key] = image.scaledUrl
    _game.state.start 'play'
  loadScaledImages([
    {
      key: 'kid'
      url: '/assets/kid.png'
    }
  ], onScaled)
, false)


_game.state.add 'menu',
  create: ->
    @stage.backgroundColor = '#42244d'

    playButtonGraphics = @game.make.graphics(0, 0)
    playButtonGraphics.beginFill Phaser.Color.getColor(255, 255, 255), 1.0
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
    @load.spritesheet('kid', _scaledImageUrls.kid, 64, 64)

  create: ->
    @keys = @game.input.keyboard.createCursorKeys()
    @keys.jump = @game.input.keyboard.addKey(Phaser.Keyboard.SPACEBAR)

    @game.physics.startSystem(Phaser.Physics.ARCADE)
    @game.physics.arcade.gravity.y = 300

    @player = @game.add.sprite(0, 0, 'kid', 0)
    @player.anchor.setTo(0.5, 0.5)
    @player.jumpTimer = 0

    @game.physics.enable(@player, Phaser.Physics.ARCADE)
    @player.body.collideWorldBounds = true
    @player.body.gravity.y = 1000
    @player.body.maxVelocity.y = 500
    @player.body.setSize(20, 32, 5, 16)

    @player.animations.add('stand', [0], 60, false)
    @player.animations.add('walk', [1, 2, 3, 0], 5, true)
    @player.animations.play('walk')

  update: ->
    dirX = 0
    dirY = 0
    if @keys.left.isDown
      dirX -= 1
    if @keys.right.isDown
      dirX += 1
    if dirX < 0
      @player.animations.play('walk')
      @player.scale.x = -1
    else if dirX > 0
      @player.animations.play('walk')
      @player.scale.x = 1
    else
      @player.animations.play('stand')
    if (@keys.jump.isDown and @player.body.onFloor() and
        @game.time.now > @jumpTimer)
      @player.body.velocity.y = -PLAYER_JUMP_SPEED
      @player.jumpTimer = @game.time.now + PLAYER_JUMP_DURATION
    @player.body.velocity.x = PLAYER_WALK_SPEED * dirX
