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

  actionDurationRange: [500, 2000]
  deadBounceRange: [0, 0.4]
  deadDrag: 0.5
  deadMinVelocity: 0.01
  flyingDuration: 500
  flyingPunchWalkChance: 0.1
  flyingStunnedChance: 0.4
  gibAngularVelocityRange: [-100, 100]
  gibBounceRange: [0, 0.5]
  gibCountRange: [4, 10]
  gibChance: 0.2
  gibShakeFrames: 4
  gibSlowMotionFrames: 5
  gibSlowMotionScale: 2.0
  gibVelocityXRange: [100, 300]
  gibVelocityYRange: [100, 300]
  gravity: 1000
  jumpSpeed: 500
  idleDurationRange: [500, 1000]
  idlePunchWalkChance: 0.15
  idlePunchChance: 0.2
  idleStandTurnChance: 0.1
  idleWalkChance: 0.1
  maxPunchDistance: 15
  maxPunchWalkDistance: 30
  maxWalkDistance: 300
  punchKnockbackXRange: [50, 150]
  punchKnockbackYRange: [200, 300]
  punchWalkSpeed: 20
  punchWalkSpeedRange: 5
  questionChance: 0.3
  questionDuration: 2000
  questionSpriteOffset: 5
  walkSpeed: 100
  walkSpeedRange: 20

  constructor: (@game, x, y, groups) ->
    @health = 3
    @groups = groups

    @punchWalkSpeed = @punchWalkSpeed - @game.rnd.between(0, @punchWalkSpeedRange)
    @walkSpeed = @walkSpeed - @game.rnd.between(0, @walkSpeedRange)
    @action = 'stand'
    @actionTarget = null
    @actionTime = 0

    @sprite = @game.add.sprite(x, y, 'mutant', 0, @groups.mutants)
    @sprite.anchor.setTo(0.5, 0.5)
    @sprite.smoothed = false

    @sprite.animations.add('stand', [0], 10, false)
    @sprite.animations.add('flying', [1, 2, 3, 4], 5, false)
    @sprite.animations.add('stunned', [13, 14], 2, true)
    @sprite.animations.add('dead', [15], 10, false)
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
    newActionDuration = @game.rnd.between(@actionDurationRange[0],
                                          @actionDurationRange[1])
    newAction = if @action == 'flying' and not @sprite.body.onFloor()
      'flying'
    else if @action == 'flying'
      chance = @game.rnd.frac()
      if chance < @flyingPunchWalkChance
        'punchWalk'
      else if chance < @flyingStunnedChance
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
      newActionDuration = @game.rnd.between(@idleDurationRange[0],
                                            @idleDurationRange[1])
      chance = @game.rnd.frac()
      if chance < @idleWalkChance
        'idleWalk'
      else if chance < @idlePunchWalkChance
        'idlePunchWalk'
      else if chance < @idlePunchChance
        'idlePunch'
      else
        @sprite.scale.x = sign(@game.rnd.normal()) if @game.rnd.frac() < @idleStandTurnChance
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
    @logging = true
    playerDirection = sign(player.sprite.x - @sprite.x)
    @sprite.body.velocity.x = (-playerDirection *
                               @game.rnd.between(@punchKnockbackXRange[0],
                                                 @punchKnockbackXRange[1]))
    @sprite.body.velocity.y = -@game.rnd.between(@punchKnockbackYRange[0],
                                                 @punchKnockbackYRange[1])
    @sprite.body.y -= 1
    @health--
    if @health > 0
      @action = 'flying'
      @actionTime = @game.time.now + @flyingDuration
      @sprite.animations.play('flying')
    else
      @onKilled(player)

  onKilled: (player) ->
    if @game.rnd.frac() < @gibChance
      @gib(player)
      @sprite.kill()
    else
      @action = 'dead'
      @actionTime = Infinity
      @sprite.animations.play('dead')
      @sprite.body.bounce.y = @game.rnd.realInRange(@deadBounceRange[0],
                                                    @deadBounceRange[1])

  gib: (player) ->
    @game.plugins.effects.shake @gibShakeFrames
    @game.plugins.effects.slowMotion @gibSlowMotionFrames, @gibSlowMotionScale
    x = @sprite.x
    y = @sprite.y + 10
    if @action == 'dead'
      y += 15
    gibs = [
      @game.add.sprite(x, y, 'gibsBones', 0, @groups.gibs)
      @game.add.sprite(x, y, 'gibsBones', 1, @groups.gibs)
      @game.add.sprite(x, y, 'gibsBones', 1, @groups.gibs)
      @game.add.sprite(x, y, 'gibsParticles', 0, @groups.gibs)
      @game.add.sprite(x, y, 'gibsParticles', 1, @groups.gibs)
    ]
    for i in [0..@game.rnd.between(@gibCountRange[0], @gibCountRange[1])]
      frame = @game.rnd.between(2, 3)
      gibs.push(@game.add.sprite(x, y, 'gibsParticles', frame, @groups.gibs))
    for gib, i in gibs
      gib.anchor.setTo(0.5, 0.5)
      gib.smoothed = false
      @game.physics.enable(gib, Phaser.Physics.ARCADE)
      gib.body.bounce.y = @game.rnd.realInRange(@gibBounceRange[0],
                                                @gibBounceRange[1])
      gib.body.collideWorldBounds = true
      gib.body.gravity.y = @gravity
      gib.body.setSize(gib.width, gib.height, 0, 0)
      gib.body.velocity.x = (@game.rnd.realInRange(@gibVelocityXRange[0],
                                                   @gibVelocityXRange[1]) *
                             (if @game.rnd.frac() < 0.5 then -1 else 1))
      gib.body.drag.x = abs(gib.body.velocity.x)
      gib.body.velocity.y = -@game.rnd.realInRange(@gibVelocityYRange[0],
                                                   @gibVelocityYRange[1])
      gib.body.allowRotation = (i == 1 or i == 2)
      if gib.body.allowRotation
        gib.body.angularVelocity = @game.rnd.realInRange(@gibAngularVelocityRange[0],
                                                         @gibAngularVelocityRange[1])
        gib.body.angularDrag = abs(gib.body.angularVelocity)

  update: (player) ->
    if @action == 'dead'
      if abs(@sprite.body.velocity.x) > 0 and @sprite.body.onFloor()
        @sprite.body.velocity.x *= @deadDrag
        if abs(@sprite.body.velocity.x) < @deadMinVelocity
          @sprite.body.velocity.x = 0
    else
      @startAction(player) if @game.time.now > @actionTime
      @continueAction(player)
      if (@questionSprite.visible = @questionTime > @game.time.now)
        @questionSprite.x = @sprite.x
        @questionSprite.y = @sprite.y - @questionSpriteOffset


class Player

  gravity: 1000
  hurtDuration: 250
  hurtFlashFrames: 10
  hurtShakeFrames: 4
  hurtSlowMotionFrames: 10
  hurtSlowMotionScale: 2.0
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

  isPunching: ->
    anim = @sprite.animations.currentAnim.name
    frame = @sprite.animations.currentFrame.index
    if anim == 'punch' and (frame == 5 or frame == 7)
      unless @wasPunching
        @wasPunching = true
      else
        false
    else
      @wasPunching = false

  onPunched: (mutant) ->
    @hurtTimer = @game.time.now + @hurtDuration
    @game.plugins.effects.flash @hurtFlashFrames
    @game.plugins.effects.shake @hurtShakeFrames
    @game.plugins.effects.slowMotion @hurtSlowMotionFrames, @hurtSlowMotionScale

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

    if @isPunching()
      for mutant in mutants
        if (mutant.action != 'flying' and
            @game.physics.arcade.overlap(@punchSprite, mutant.sprite))
          mutant.onPunched(this)


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
    @load.spritesheet('gibsBones', _scaled['/assets/gibs_bones.png'],
                      20, 16, -1, 4, 4)
    @load.spritesheet('gibsParticles', _scaled['/assets/gibs_particles.png'],
                      4, 4, -1, 4, 4)
    @load.spritesheet('mutant', _scaled['/assets/mutant.png'], 64, 64)
    @load.spritesheet('player', _scaled['/assets/player.png'], 64, 64)

  create: ->
    @farBackground = @game.add.tileSprite(0, @game.height - 96 - 32,
                                          @game.width, 96, 'mountains')
    @farBackground.fixedToCamera = true

    @groups =
      gibs: @game.add.group()
      mutants: @game.add.group()

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
    @keys.jump1 = @game.input.keyboard.addKey(Phaser.Keyboard.SPACEBAR)
    @keys.jump2 = @game.input.keyboard.addKey(Phaser.Keyboard.Z)
    @keys.fire = @game.input.keyboard.addKey(Phaser.Keyboard.C)
    @player = new Player(@game, @world.width / 2, @game.height - 64)
    @camera.follow(@player.sprite, Phaser.Camera.FOLLOW_PLATFORMER)

    @mutants = (new Mutant(@game, @game.rnd.between(0, @world.width),
                           @game.height - 64, @groups) for i in [0..5])

    @game.plugins.effects = @game.plugins.add(EffectsPlugin)

  render: ->
    @game.debug.text(@game.time.fps or '--', 2, 14, "#00ff00")

  update: ->
    @farBackground.tilePosition.set(@game.camera.x * -@farBackgroundScroll, 0)
    @game.physics.arcade.collide(@groups.gibs, @layer)
    @game.physics.arcade.collide(@player.sprite, @layer)
    @player.update(@keys, @mutants)
    @game.physics.arcade.collide(@groups.mutants, @layer)
    for mutant in @mutants
      mutant.update(@player)


window.addEventListener('load', ->
  loadScaledImages([
    '/assets/gibs_bones.png'
    '/assets/gibs_particles.png'
    '/assets/mountains.png'
    '/assets/mutant.png'
    '/assets/player.png'
    '/assets/question_mark.png'
    '/assets/rocks.png'
    '/assets/tiles.png'
  ], -> _game.state.start('play'))
, false)
