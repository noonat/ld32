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


class EffectsPlugin extends Phaser.Plugin

  constructor: (game, parent) ->
    super(game, parent)
    @flashGraphics = @game.add.graphics(0, 0)
    @flashGraphics.beginFill(0xff0000, 0.1)
    @flashGraphics.drawRect(-50, -50, _width + 100, _height + 100)
    @flashGraphics.endFill()
    @flashGraphics.fixedToCamera = true
    @flashGraphics.visible = false
    @lastShakeTime = 0
    @numShakeFrames = 0
    @numSlowMotionFrames = 0

  flash: (numFrames, color) ->
    @numFlashFrames = numFrames
    @flashGraphics.visible = true

  shake: (numFrames) ->
    return if @game.time.now - @lastShakeTime < 200
    @lastShakeTime = @game.time.now
    @numShakeFrames = numFrames
    # window.navigator?.vibrate?(count * 10)

  slowMotion: (numFrames, scale) ->
    @numSlowMotionFrames = numFrames
    @slowMotionScale = scale

  postUpdate: ->
    if @numFlashFrames > 0
      @numFlashFrames--
    else
      @flashGraphics.visible = false

    if @numShakeFrames > 0
      @numShakeFrames--
      @game.camera.displayObject.position.x += @game.rnd.normal()
      @game.camera.displayObject.position.y += @game.rnd.normal()

    if @numSlowMotionFrames > 0
      @numSlowMotionFrames--
      @game.time.slowMotion = @slowMotionScale
    else
      @game.time.slowMotion = 1.0


class Mutant

  gravity: 1000
  jumpSpeed: 500
  idleActions: ['stand', 'idleWalk']
  idleActionDuration: 100
  maxPunchDistance: 15
  maxPunchWalkDistance: 30
  maxWalkDistance: 300
  minActionDuration: 500
  maxActionDuration: 2000
  minIdleDuration: 500
  maxIdleDuration: 2000
  punchKnockbackXRange: [50, 150]
  punchKnockbackYRange: [200, 300]
  punchWalkSpeed: 20
  punchWalkSpeedRange: 5
  questionChance: 0.3
  questionDuration: 2000
  walkSpeed: 100
  walkSpeedRange: 20

  constructor: (@game, x, y) ->
    @punchWalkSpeed = @punchWalkSpeed - @game.rnd.between(0, @punchWalkSpeedRange)
    @walkSpeed = @walkSpeed - @game.rnd.between(0, @walkSpeedRange)
    @action = 'stand'
    @actionTarget = null
    @actionTime = 0

    @sprite = @game.add.sprite(x, y, 'mutant', 0)
    @sprite.anchor.setTo(0.5, 0.5)
    @sprite.smoothed = false
    tint = Phaser.Color.HSLtoRGB(0, 0, @game.rnd.realInRange(0.9, 1.0))
    @sprite.tint = Phaser.Color.getColor(tint.r, tint.g, tint.b)

    @sprite.animations.add('stand', [0], 10, false)
    @sprite.animations.add('flying', [1, 2, 3, 4], 5, false)
    @sprite.animations.add('stunned', [13, 14], 2, true)
    @sprite.animations.add('walk', [1, 2, 3, 4], 5, true)
    @sprite.animations.add('punchWalk', [6, 7, 8, 5], 5, true)
    @sprite.animations.add('punch', [10, 11, 12, 9], 5, true)
    @sprite.animations.add('idleWalk', [1, 2, 3, 4], 3, true)
    @sprite.animations.add('idlePunchWalk', [5, 6, 7, 8], 3, true)
    @sprite.animations.add('idlePunch', [9, 10, 11, 12], 3, true)
    @sprite.animations.play('stand')

    @game.physics.enable(@sprite, Phaser.Physics.ARCADE)
    @sprite.body.collideWorldBounds = true
    @sprite.body.gravity.y = @gravity
    @sprite.body.maxVelocity.y = @jumpSpeed
    @sprite.body.setSize(16, 32, 0, 16)

    @questionSprite = @game.add.sprite(x, y, 'questionMark')
    @questionSprite.anchor.setTo(0.5, 1)
    @questionSprite.visible = false
    @questionTimer = 0

    @punchSprite = @game.add.sprite(10, 0, null)
    @punchSprite.anchor.setTo(0.5, 0.5)
    @sprite.addChild(@punchSprite)
    @game.physics.enable(@punchSprite, Phaser.Physics.ARCADE)
    @punchSprite.body.allowGravity = false
    @punchSprite.body.allowRotation = false
    @punchSprite.body.setSize(10, 32, 0, 16)

  startAction: (player) ->
    playerDelta = player.sprite.x - @sprite.x
    playerDistance = abs(playerDelta)
    newActionDuration = @game.rnd.between(@minActionDuration,
                                          @maxActionDuration)
    newAction = if not @sprite.body.onFloor()
      'flying'
    else if @action == 'flying'
      chance = @game.rnd.frac()
      if chance < 0.1
        'punchWalk'
      else if chance < 0.4
        'stunned'
      else
        'walk'
    else if playerDistance < @maxPunchDistance
      @target = player
      'punch'
    else if playerDistance < @maxPunchWalkDistance
      @target = player
      newActionDuration = 0
      'punchWalk'
    else if playerDistance < @maxWalkDistance
      @target = player
      newActionDuration = 0
      'walk'
    else if @target and @game.rnd.frac() < @questionChance
      @target = null
      @questionTime = @game.time.now + @questionDuration
      'stand'
    else
      @target = null
      newActionDuration = @game.rnd.between(500, 1000)
      random = @game.rnd.frac()
      if random < 0.1
        'idleWalk'
      else if random < 0.15
        'idlePunchWalk'
      else if random < 0.20
        'idlePunch'
      else
        @sprite.scale.x = sign(@game.rnd.normal()) if @game.rnd.frac() < 0.1
        'stand'
    @action = newAction
    @actionTime = @game.time.now + newActionDuration
    @sprite.animations.play(@action)

  continueAction: (player) ->
    deltaX = player.sprite.x - @sprite.x
    switch @action
      when 'flying'
        @startAction(player) if @sprite.body.onFloor()
      when 'stunned'
        @sprite.body.velocity.x = 0
      when 'punch'
        @sprite.body.velocity.x = 0
      when 'punchWalk'
        @sprite.body.velocity.x = @punchWalkSpeed * sign(deltaX)
        @sprite.scale.x = sign(deltaX)
      when 'walk'
        @sprite.body.velocity.x = @walkSpeed * sign(deltaX)
        @sprite.scale.x = sign(deltaX)
      when 'idlePunch'
        @sprite.body.velocity.x = 0
      when 'idlePunchWalk'
        @sprite.body.velocity.x = 0
      when 'idleWalk'
        @sprite.body.velocity.x = @walkSpeed * 0.5 * sign(@sprite.scale.x)
      when 'stand'
        @sprite.body.velocity.x = 0
    player.onPunched(this) if @isPunching(player)

  isPunching: (player) ->
    anim = @sprite.animations.currentAnim.name
    frame = @sprite.animations.currentFrame.index
    if ((anim == 'punch' and (frame == 9 or frame == 1)) or
        (anim == 'punchWalk' and (frame == 5 or frame == 7)))
      # This is a punching frame, see if the punch sprite is hitting the player
      @game.physics.arcade.overlap @punchSprite, player.sprite
    else
      false

  onPunched: (player) ->
    playerDirection = sign(player.sprite.x - @sprite.x)
    @action = 'flying'
    @actionTime = @game.time.now + 500
    @sprite.animations.play('flying')
    @sprite.body.velocity.x = (-playerDirection *
                               @game.rnd.between(@punchKnockbackXRange[0],
                                                 @punchKnockbackXRange[1]))
    @sprite.body.velocity.y = -@game.rnd.between(@punchKnockbackYRange[0],
                                                 @punchKnockbackYRange[1])
    @sprite.body.y -= 1

  update: (player) ->
    @startAction(player) if @game.time.now > @actionTime
    @continueAction(player)
    if (@questionSprite.visible = @questionTime > @game.time.now)
      @questionSprite.x = @sprite.x
      @questionSprite.y = @sprite.y - 5
    if @tintTimer != null and @tintTimer < @game.time.now
      @sprite.tint = 0xffffff


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
    @sprite.animations.add('punch', [4, 5, 6, 7], 7, true)
    @sprite.animations.play('stand')

    @game.physics.enable(@sprite, Phaser.Physics.ARCADE)
    @sprite.body.collideWorldBounds = true
    @sprite.body.gravity.y = @gravity
    @sprite.body.maxVelocity.y = @jumpSpeed
    @sprite.body.setSize(16, 32, 0, 16)

    @punchSprite = @game.add.sprite(10, 0, null)
    @punchSprite.anchor.setTo(0.5, 0.5)
    @sprite.addChild(@punchSprite)
    @game.physics.enable(@punchSprite, Phaser.Physics.ARCADE)
    @punchSprite.body.allowGravity = false
    @punchSprite.body.allowRotation = false
    @punchSprite.body.setSize(24, 32, 0, 16)

    @hurtTimer = null

  isPunching: (mutant) ->
    anim = @sprite.animations.currentAnim.name
    frame = @sprite.animations.currentFrame.index
    if anim == 'punch' and (frame == 5 or frame == 7)
      # This is a punching frame, see if the punch sprite is hitting the player
      @game.physics.arcade.overlap @punchSprite, mutant.sprite
    else
      false

  onPunched: (mutant) ->
    @hurtTimer = @game.time.now + 250
    @game.plugins.effects.flash 10
    @game.plugins.effects.shake 4
    @game.plugins.effects.slowMotion 10, 2.0

  update: (keys, mutants) ->
    dirX = 0
    dirY = 0
    dirX -= 1 if keys.left.isDown
    dirX += 1 if keys.right.isDown

    speed = @walkSpeed
    animation = if keys.fire.isDown
      speed = 0
      'punch'
    else if dirX < 0
      'walk'
    else if dirX > 0
      'walk'
    else
      'stand'
    @sprite.animations.play(animation)
    @sprite.scale.x = sign(dirX) if dirX
    @sprite.body.velocity.x = speed * dirX

    if ((keys.jump1.isDown or keys.jump2.isDown or keys.up.isDown) and
        @game.time.now > @jumpTimer and @sprite.body.onFloor())
      @sprite.body.velocity.y = -@jumpSpeed
      @jumpTimer = @game.time.now + @jumpDuration

    if @hurtTimer != null and @hurtTimer < @game.time.now
      @hurtTimer = null
      @sprite.tint = 0xffffff

    for mutant in mutants
      mutant.onPunched(this) if @isPunching(mutant)


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

  farBackgroundScroll: 0.1
  nearBackgroundScroll: 0.3

  preload: ->
    @game.time.advancedTiming = true
    @load.image('mountains', _scaled['/assets/mountains.png'])
    @load.image('questionMark', _scaled['/assets/question_mark.png'])
    @load.image('rocks', _scaled['/assets/rocks.png'])
    @load.image('tiles', _scaled['/assets/tiles.png'])
    @load.spritesheet('mutant', _scaled['/assets/mutant.png'], 64, 64)
    @load.spritesheet('player', _scaled['/assets/player.png'], 64, 64)

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

    @farBackground = @game.add.tileSprite(0, @game.height - 96 - 32,
                                          @game.width, 96, 'mountains')
    @farBackground.fixedToCamera = true

    @keys = @game.input.keyboard.createCursorKeys()
    @keys.jump1 = @game.input.keyboard.addKey(Phaser.Keyboard.SPACEBAR)
    @keys.jump2 = @game.input.keyboard.addKey(Phaser.Keyboard.Z)
    @keys.fire = @game.input.keyboard.addKey(Phaser.Keyboard.C)
    @player = new Player(@game, @world.width / 2, @game.height - 64)
    @camera.follow(@player.sprite, Phaser.Camera.FOLLOW_PLATFORMER)

    @mutants = (new Mutant(@game, @game.rnd.between(0, @world.width),
                           @game.height - 64) for i in [0..5])

    @game.plugins.effects = @game.plugins.add(EffectsPlugin)

  render: ->
    @game.debug.text(@game.time.fps or '--', 2, 14, "#00ff00")

  update: ->
    @farBackground.tilePosition.set(@game.camera.x * -@farBackgroundScroll, 0)
    @game.physics.arcade.collide(@player.sprite, @layer)
    @player.update(@keys, @mutants)
    for mutant in @mutants
      @game.physics.arcade.collide(mutant.sprite, @layer)
      mutant.update(@player)


window.addEventListener('load', ->
  loadScaledImages([
    '/assets/mountains.png'
    '/assets/mutant.png'
    '/assets/player.png'
    '/assets/question_mark.png'
    '/assets/rocks.png'
    '/assets/tiles.png'
  ], -> _game.state.start('play'))
, false)
