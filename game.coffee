'use strict'

_canvas = document.createElement 'canvas'
_scale = 4
_scaled = {}
_width = 900
_height = 500
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


class RandomBag

  constructor: (@values) ->
    @currentValues = []

  pop: ->
    if @currentValues.length == 0
      @currentValues = @values.slice()
      Phaser.ArrayUtils.shuffle(@currentValues)
    @currentValues.pop()


class EffectsPlugin extends Phaser.Plugin

  constructor: (game, parent) ->
    super(game, parent)
    @flashGraphics = @game.add.graphics(0, 0)
    @game.groups.effects.add(@flashGraphics)
    @game.groups.explosions.createMultiple(10)
    @flashGraphics.beginFill(0xff0000, 0.1)
    @flashGraphics.drawRect(-50, -50, _width + 100, _height + 100)
    @flashGraphics.endFill()
    @flashGraphics.fixedToCamera = true
    @flashGraphics.visible = false
    @lastShakeTime = 0
    @numShakeFrames = 0
    @numSlowMotionFrames = 0
    @shakeAmount = 0

  explode: (x, y) ->
    explosion = @game.groups.explosions.getFirstExists(false)
    if explosion
      explosion.reset(x, y)

  flash: (numFrames, color) ->
    @numFlashFrames = numFrames
    @flashGraphics.visible = true

  shake: (numFrames, amount) ->
    return if @game.time.now - @lastShakeTime < 200
    @lastShakeTime = @game.time.now
    @numShakeFrames = numFrames
    @shakeAmount = amount or 1
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
      @game.camera.displayObject.position.x += @game.rnd.normal() * @shakeAmount
      @game.camera.displayObject.position.y += @game.rnd.normal() * @shakeAmount

    if @numSlowMotionFrames > 0
      @numSlowMotionFrames--
      @game.time.slowMotion = @slowMotionScale
    else
      @game.time.slowMotion = 1.0


class Barrel extends Phaser.Sprite

  constructor: (game, x, y) ->
    super(game, x, y, 'barrel', 3)
    @anchor.setTo(0.5, 1.0)
    @animations.add('drip', [0, 0, 0, 0, 0, 1, 2, 3], 10, false)
    @smoothed = false
    @nextDripTime = @game.time.now + @game.rnd.between(0, 10000)

    @game.physics.enable(this, Phaser.Physics.ARCADE)
    @body.allowGravity = false
    @body.collideWorldBounds = true
    @body.immovable = true
    @body.setSize(12, 24, 0, 0)

  explode: ->
    @game.groups.mutants.forEachAlive((mutant) ->
      deltaX = @x - mutant.x
      deltaY = @y - mutant.y
      distance = Math.sqrt(deltaX * deltaX + deltaY * deltaY)
      if distance < 32 * 4
        mutant.brain.action = 'dead'
        mutant.brain.actionTime = Infinity
        mutant.brain.gib()
        mutant.kill()
    , this, true)
    @game.groups.players.forEachAlive((player) ->
      deltaX = @x - player.x
      deltaY = @y - player.y
      distance = Math.sqrt(deltaX * deltaX + deltaY * deltaY)
      player.body.velocity.y = -300 if distance < 32 * 4
    , this, true)
    @game.plugins.effects.explode(@x, @y - 16)
    for i in [0..8]
      gib = @game.groups.gibs.barrel.getFirstExists(false)
      gib.reset(@x, @y - 16) if gib
    for i in [0..16]
      gib = @game.groups.gibs.barrelWaste.getFirstExists(false)
      gib.reset(@x, @y - 16) if gib
    @kill()

  update: ->
    super
    if @nextDripTime < @game.time.now
      @nextDripTime = @game.time.now + @game.rnd.between(0, 10000)
      @animations.stop(null, true)
      @animations.play('drip')


class Gib extends Phaser.Sprite

  angularVelocityRange: [-100, 100]
  velocityXRange: [100, 300]
  velocityYRange: [100, 300]

  constructor: (game, x, y, key, frame) ->
    super(game, x, y, key, frame)
    @anchor.setTo(0.5, 0.5)
    @game.physics.enable(this, Phaser.Physics.ARCADE)
    @body.allowRotation = false
    @body.collideWorldBounds = true
    @body.gravity.y = 500
    @body.setSize(1, 1, 0, 0)

  reset: (x, y, health) ->
    super(x, y, health)
    @lifespan = @game.rnd.between(5000, 10000)
    @body.velocity.x = (@game.rnd.realInRange(@velocityXRange[0],
                                              @velocityXRange[1]) *
                        (if @game.rnd.frac() < 0.5 then -1 else 1))
    @body.drag.x = abs(@body.velocity.x)
    @body.velocity.y = -@game.rnd.realInRange(@velocityYRange[0],
                                              @velocityYRange[1])
    @body.angularVelocity = @game.rnd.realInRange(@angularVelocityRange[0],
                                                  @angularVelocityRange[1])
    @body.angularDrag = abs(@body.angularVelocity)


class BarrelGib extends Gib

  constructor: (game, x, y) ->
    super(game, x, y, 'gibsParticles', game.rnd.between(4, 6))
    @smoothed = false
    @scale.x = @scale.y = @game.rnd.between(1, 3)
    @body.setSize(@scale.x, @scale.y)


class BarrelWasteGib extends Gib

  constructor: (game, x, y) ->
    super(game, x, y, 'gibsParticles', game.rnd.between(0, 1))
    @smoothed = false
    @scale.x = @scale.y = @game.rnd.between(1, 2)
    @body.setSize(@scale.x, @scale.y)
    @body.allowRotation = true


class Explosion extends Phaser.Sprite

  constructor: (game, @baseX, @baseY) ->
    super(game, @baseX, @baseY, 'explosion', 0)
    @anchor.setTo(0.5, 0.5)

  reset: (x, y, health) ->
    super(x, y, health)
    @baseX = x
    @baseY = y
    @frame = 0
    @nextFrameTime = @game.time.now + 100
    @game.plugins.effects.shake(10, 5)

  update: ->
    super
    if @nextFrameTime < @game.time.now
      @nextFrameTime = @game.time.now + 100
      if @animations.frame == 0
        @animations.frame = 1
      else
        @kill()
    @x = Math.round(@baseX + @game.rnd.normal() * 5)
    @y = Math.round(@baseY + @game.rnd.normal() * 5)


class Mutant

  actionDurationRange: [500, 2000]
  bloodLifespanRange: [5000, 10000]
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
  idleDurationRange: [500, 1000]
  idlePunchWalkChance: 0.15
  idlePunchChance: 0.2
  idleStandTurnChance: 0.1
  idleWalkChance: 0.1
  jumpSpeed: 250
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

  constructor: (@game, x, y) ->
    @health = 3

    @punchWalkSpeed = @punchWalkSpeed - @game.rnd.between(0, @punchWalkSpeedRange)
    @walkSpeed = @walkSpeed - @game.rnd.between(0, @walkSpeedRange)
    @action = 'stand'
    @actionTarget = null
    @actionTime = 0

    @sprite = @game.add.sprite(x, y, 'mutant', 0, @game.groups.mutants)
    @sprite.brain = this
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
        if @sprite.body.onWall()
          @sprite.body.velocity.y = -@jumpSpeed
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
    @action = 'dead'
    @actionTime = Infinity
    if @game.rnd.frac() < @gibChance
      @gib(player)
      @sprite.kill()
    else
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
      @game.add.sprite(x, y, 'gibsBones', 0, @game.groups.gibs.heads)
      @game.add.sprite(x, y, 'gibsBones', 1, @game.groups.gibs.bones)
      @game.add.sprite(x, y, 'gibsBones', 1, @game.groups.gibs.bones)
      @game.add.sprite(x, y, 'gibsParticles', 0, @game.groups.gibs.particles)
      @game.add.sprite(x, y, 'gibsParticles', 1, @game.groups.gibs.particles)
    ]
    for i in [0..@game.rnd.between(@gibCountRange[0], @gibCountRange[1])]
      frame = @game.rnd.between(2, 3)
      bloodGib = @game.add.sprite(x, y, 'gibsParticles', frame,
                                  @game.groups.gibs.particles)
      bloodGib.lifespan = @game.rnd.between(@bloodLifespanRange[0],
                                            @bloodLifespanRange[1])
      gibs.push(bloodGib)
    for gib, i in gibs
      gib.anchor.setTo(0.5, 0.5)
      gib.smoothed = false
      @game.physics.enable(gib, Phaser.Physics.ARCADE)
      body = gib.body
      body.bounce.y = @game.rnd.realInRange(@gibBounceRange[0],
                                            @gibBounceRange[1])
      body.collideWorldBounds = true
      body.gravity.y = @gravity
      body.setSize(gib.width, gib.height, 0, 0)
      body.velocity.x = (@game.rnd.realInRange(@gibVelocityXRange[0],
                                               @gibVelocityXRange[1]) *
                         (if @game.rnd.frac() < 0.5 then -1 else 1))
      body.drag.x = abs(gib.body.velocity.x)
      body.velocity.y = -@game.rnd.realInRange(@gibVelocityYRange[0],
                                               @gibVelocityYRange[1])
      body.allowRotation = (i == 1 or i == 2)
      if body.allowRotation
        body.angularVelocity = @game.rnd.realInRange(@gibAngularVelocityRange[0],
                                                     @gibAngularVelocityRange[1])
        body.angularDrag = abs(body.angularVelocity)

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

    @sprite = @game.add.sprite(x, y, 'player', 0, @game.groups.players)
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
    animation = if keys.fire1.isDown or keys.fire2.isDown
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
      @game.physics.arcade.overlap(@punchSprite, @game.groups.barrels,
                                   (sprite, barrel) -> barrel.explode())
      for mutant in mutants
        if (mutant.action != 'flying' and
            @game.physics.arcade.overlap(@punchSprite, mutant.sprite))
          mutant.onPunched(this)


_game.state.add 'menu',

  preload: ->
    @load.image('title', _scaled['./assets/title.png'])

  create: ->
    @game.add.image(0, 0, 'title')

    textStyle =
      fill: '#dbecff'
      font: '20px arial'
    texts = [
      @game.add.text(700, 310, 'arrows to move', textStyle)
      @game.add.text(700, 335, 'space or z to jump', textStyle)
      @game.add.text(700, 360, 'ctrl or c to punch', textStyle)
      @game.add.text(700, 410, 'space to start', textStyle)
    ]
    for text in texts
      text.smoothed = false

    @key = @game.input.keyboard.addKey(Phaser.Keyboard.SPACEBAR)

  update: ->
    @game.state.start('play') if @key.isDown


_game.state.add 'play',

  farBackgroundScroll: 0.1
  nearBackgroundScroll: 0.3

  preload: ->
    @load.image('mountains', _scaled['./assets/mountains.png'])
    @load.image('questionMark', _scaled['./assets/question_mark.png'])
    @load.image('rocks', _scaled['./assets/rocks.png'])
    @load.image('tiles', _scaled['./assets/tiles.png'])
    @load.spritesheet('barrel', _scaled['./assets/barrel.png'], 44, 32)
    @load.spritesheet('explosion', _scaled['./assets/explosion.png'], 128, 128)
    @load.spritesheet('explosionSmall', _scaled['./assets/explosion_small.png'],
                      64, 64)
    @load.spritesheet('gibsBones', _scaled['./assets/gibs_bones.png'],
                      20, 16, -1, 4, 4)
    @load.spritesheet('gibsParticles', _scaled['./assets/gibs_particles.png'],
                      4, 4, -1, 4, 4)
    @load.spritesheet('mutant', _scaled['./assets/mutant.png'], 64, 64)
    @load.spritesheet('player', _scaled['./assets/player.png'], 64, 64)

  create: ->
    @game.physics.startSystem(Phaser.Physics.ARCADE)
    @game.physics.arcade.gravity.y = 300

    @groups = @game.groups = {}
    @groups.background = @game.add.group()
    @groups.explosions = @game.add.group()
    @groups.barrels = @game.add.group()
    @groups.barrels.classType = Barrel
    @groups.explosions = @game.add.group()
    @groups.explosions.classType = Explosion
    @groups.gibs = {}
    @groups.gibs.barrel = @game.add.group()
    @groups.gibs.barrel.classType = BarrelGib
    @groups.gibs.barrel.createMultiple(64)
    @groups.gibs.barrelWaste = @game.add.group()
    @groups.gibs.barrelWaste.classType = BarrelWasteGib
    @groups.gibs.barrelWaste.createMultiple(32)
    @groups.gibs.particles = @game.add.group()
    @groups.gibs.bones = @game.add.group()
    @groups.gibs.heads =  @game.add.group()
    @groups.mutants = @game.add.group()
    @groups.players = @game.add.group()
    @groups.effects = @game.add.group()

    @game.plugins.effects = @game.plugins.add(EffectsPlugin)

    @stage.backgroundColor = '#dbecff'
    @farBackground = @game.add.tileSprite(0, @game.height - 192 - 32,
                                          @game.width, 192, 'mountains', 0,
                                          @groups.background)
    @farBackground.fixedToCamera = true

    @createRandomMap()

    @keys = @game.input.keyboard.createCursorKeys()
    @keys.jump1 = @game.input.keyboard.addKey(Phaser.Keyboard.SPACEBAR)
    @keys.jump2 = @game.input.keyboard.addKey(Phaser.Keyboard.Z)
    @keys.fire1 = @game.input.keyboard.addKey(Phaser.Keyboard.CONTROL)
    @keys.fire2 = @game.input.keyboard.addKey(Phaser.Keyboard.C)
    @player = new Player(@game, 32, @game.height - 64)
    @camera.follow(@player.sprite, Phaser.Camera.FOLLOW_PLATFORMER)

    @mutants = (new Mutant(@game, @game.rnd.between(0, @world.width),
                           @game.height - 64) for i in [0..40])

  createRandomMap: ->
    @map = new Phaser.Tilemap(@game, null, 32, 32, 200, 20)
    @map.addTilesetImage('tiles', 'tiles', 32, 32, 4, 4)

    @dirtLayer = @map.createBlankLayer('dirt', @map.width, @map.height, 32, 32)
    @dirtLayer.resizeWorld()
    @camera.setBoundsToWorld()

    numDirtTiles = 16
    dirtBag = new RandomBag([0...numDirtTiles])
    height = 1
    heights = []
    heightChance = 0
    for x in [0...@map.width]
      if @game.rnd.frac() < heightChance
        heightChance = 0
        if height == 1
          height++
        else if height == 4
          height--
        else
          height += sign(@game.rnd.normal())
      heightChance += 0.05
      heights[x] = height
      for y in [@map.height - height...@map.height]
        @map.putTile(dirtBag.pop(), x, y)
    @map.setCollisionBetween(0, numDirtTiles)

    # place some barrels
    stepWidth = 20
    for stepX in [0...@map.width] by stepWidth
      tileX = @game.rnd.between(stepX, stepX + stepWidth - 1)
      tileY = @map.height - heights[tileX]
      @game.groups.barrels.create(tileX * 32 + 16, tileY * 32)

  update: ->
    @farBackground.tilePosition.set(@game.camera.x * -@farBackgroundScroll, 0)
    @game.physics.arcade.collide(@groups.gibs.barrel, @dirtLayer)
    @game.physics.arcade.collide(@groups.gibs.barrelWaste, @dirtLayer)
    @game.physics.arcade.collide(@groups.gibs.particles, @dirtLayer)
    @game.physics.arcade.collide(@groups.gibs.bones, @dirtLayer)
    @game.physics.arcade.collide(@groups.gibs.heads, @dirtLayer)
    @game.physics.arcade.collide(@groups.players, @dirtLayer)
    @player.update(@keys, @mutants)
    @game.physics.arcade.collide(@groups.mutants, @dirtLayer)
    for mutant in @mutants
      mutant.update(@player)


window.addEventListener('load', ->
  loadScaledImages([
    './assets/barrel.png'
    './assets/explosion.png'
    './assets/explosion_small.png'
    './assets/gibs_bones.png'
    './assets/gibs_particles.png'
    './assets/mountains.png'
    './assets/mutant.png'
    './assets/player.png'
    './assets/question_mark.png'
    './assets/rocks.png'
    './assets/tiles.png'
    './assets/title.png'
  ], -> _game.state.start('menu'))
, false)
