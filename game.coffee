'use strict'


# Return the absolute version of value.
abs = (value) -> if value >= 0 then value else -value

# Return the squared distance between a and b, where a and b are any objects
# that have x and y properties.
distanceSquared = (a, b) ->
  deltaX = a.x - b.x
  deltaY = a.y - b.y
  deltaX * deltaX + deltaY * deltaY

# Returns -1 if the value is less than 0, or 1 otherwise.
sign = (value) -> if value >= 0 then 1 else -1


# Allows you to call pop() forever to continuously loop over shuffled versions
# of the passed array.
#
class RandomBag

  constructor: (@values) ->
    @currentValues = []

  pop: ->
    if @currentValues.length == 0
      @currentValues = @values.slice()
      Phaser.ArrayUtils.shuffle(@currentValues)
    @currentValues.pop()


# Phaser plugin to provide some special effects to things.
#
class EffectsPlugin extends Phaser.Plugin

  constructor: (game, parent) ->
    super(game, parent)
    @flashGraphics = @game.add.graphics(0, 0)
    @game.groups.effects.add(@flashGraphics)
    @game.groups.explosions.createMultiple(10)
    @flashGraphics.fixedToCamera = true
    @flashGraphics.visible = false
    @lastShakeTime = 0
    @numShakeFrames = 0
    @numSlowMotionFrames = 0
    @shakeAmount = 0

  # Create an explosion sprite at the given position.
  explode: (x, y) ->
    explosion = @game.groups.explosions.getFirstExists(false)
    if explosion
      explosion.reset(x, y)

  # Create a tinted flash on the screen.
  flash: (numFrames, color=0xff0000) ->
    @numFlashFrames = numFrames
    @flashGraphics.clear()
    @flashGraphics.beginFill(color, 0.1)
    @flashGraphics.drawRect(-50, -50, @game.width + 100, @game.height + 100)
    @flashGraphics.endFill()
    @flashGraphics.visible = true

  # Shake the camera around for a couple frames.
  shake: (numFrames, amount) ->
    return if @game.time.now - @lastShakeTime < 200
    @lastShakeTime = @game.time.now
    @numShakeFrames = numFrames
    @shakeAmount = amount or 1
    # window.navigator?.vibrate?(count * 10)

  # Make things run in slow motion for a couple frames.
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


# This is an exploding barrel entity. When punched, it blows up and gibs any
# mutants nearby.
#
class Barrel extends Phaser.Sprite

  maxExplodeDistance: 128

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

  # Called by PlayerBrain when the player punches a barrel.
  explode: ->
    maxExplodeDistanceSquared = @maxExplodeDistance * @maxExplodeDistance

    # Gib any mutants that are close enough.
    @game.groups.mutants.forEachAlive((mutant) ->
      if distanceSquared(this, mutant) < maxExplodeDistanceSquared
        # FIXME: MutantBrain should take care of these.
        mutant.brain.action = 'dead'
        mutant.brain.actionTime = Infinity
        mutant.brain.gib()
        mutant.kill()
    , this, true)

    # Knock back any players who are close enough.
    @game.groups.players.forEachAlive((player) ->
      # FIXME: Horizontal knockback doesn't work because PlayerBrain
      # resets velocity.x to 0 every frame.
      if distanceSquared(this, player) < maxExplodeDistanceSquared
        player.body.velocity.y = -300
    , this, true)

    # Explode the barrel and create some gibs.
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
    # Make the barrel play a drip animation every once in a while.
    if @nextDripTime < @game.time.now
      @nextDripTime = @game.time.now + @game.rnd.between(0, 10000)
      @animations.stop(null, true)
      @animations.play('drip')


# Base class for gibs. Other classes override this to custom their appearance.
#
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


# A metallic piece of a barrel.
#
class BarrelGib extends Gib

  constructor: (game, x, y) ->
    super(game, x, y, 'gibsParticles', game.rnd.between(4, 6))
    @smoothed = false
    @scale.x = @scale.y = @game.rnd.between(1, 3)
    @body.setSize(@scale.x, @scale.y)


# A green piece of barrel goo.
#
class BarrelWasteGib extends Gib

  constructor: (game, x, y) ->
    super(game, x, y, 'gibsParticles', game.rnd.between(0, 1))
    @smoothed = false
    @scale.x = @scale.y = @game.rnd.between(1, 2)
    @body.setSize(@scale.x, @scale.y)
    @body.allowRotation = true


# An explosion sprite. This is just visual, it doesn't actually do anything
# to things in the world.
#
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


# Muties! Kill em all!
#
class Mutant extends Phaser.Sprite

  constructor: (game, x, y) ->
    super(game, x, y, 'mutant', 0)

    @anchor.setTo(0.5, 0.5)
    @smoothed = false

    @animations.add('stand', [0], 10, false)
    @animations.add('flying', [1, 2, 3, 4], 5, false)
    @animations.add('stunned', [13, 14], 2, true)
    @animations.add('dead', [15], 10, false)
    @animations.add('walk', [1, 2, 3, 4], 5, true)
    @animations.add('punchWalk', [6, 7, 8, 5], 5, true)
    @animations.add('punch', [10, 11, 12, 9], 5, true)
    @animations.add('idleWalk', [1, 2, 3, 4], 3, true)
    @animations.add('idlePunchWalk', [5, 6, 7, 8], 3, true)
    @animations.add('idlePunch', [9, 10, 11, 12], 3, true)
    @animations.play('stand')

    @game.physics.enable(this, Phaser.Physics.ARCADE)
    @body.collideWorldBounds = true
    @body.setSize(16, 32, 0, 16)

    @brain = new MutantBrain(@game, this)

  update: ->
    super
    @brain.update()


# The logic behind a mutant sprite.
#
class MutantBrain

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
  punchWalkSpeedRange: [15, 20]
  questionChance: 0.3
  questionDuration: 2000
  questionSpriteOffset: 5
  walkSpeedRange: [80, 100]

  constructor: (@game, @sprite) ->
    @sprite.body.gravity.y = @gravity
    @sprite.body.maxVelocity.y = @jumpSpeed

    @action = 'stand'
    @actionTarget = null
    @actionTime = 0
    @health = 3
    @punchWalkSpeed = @game.rnd.between(@punchWalkSpeedRange[0],
                                        @punchWalkSpeedRange[1])
    @walkSpeed = @game.rnd.between(@walkSpeedRange[0], @walkSpeedRange[1])

    @questionSprite = @game.add.sprite(@sprite.x, @sprite.y, 'questionMark')
    @questionSprite.anchor.setTo(0.5, 1)
    @questionSprite.visible = false
    @questionTimer = 0

    @punchSprite = @game.add.sprite(10, 0, null)
    @punchSprite.anchor.setTo(0.5, 0.5)
    @game.physics.enable(@punchSprite, Phaser.Physics.ARCADE)
    @punchSprite.body.allowGravity = false
    @punchSprite.body.allowRotation = false
    @punchSprite.body.setSize(10, 32, 0, 16)
    @sprite.addChild(@punchSprite)

  # Called when the mutant wants to start a new action.
  startAction: (player) ->
    playerDelta = player.x - @sprite.x
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

  # Called each frame to continue the action the mutant is currently taking.
  continueAction: (player) ->
    deltaX = player.x - @sprite.x
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
    player.brain.onPunched(this) if @isPunching(player)

  # Returns true if the mutant should cause punch damage to the player.
  isPunching: (player) ->
    anim = @sprite.animations.name
    frame = @sprite.animations.frame
    if ((anim == 'punch' and (frame == 9 or frame == 1)) or
        (anim == 'punchWalk' and (frame == 5 or frame == 7)))
      # This is a punching frame, see if the punch sprite is hitting the player
      @game.physics.arcade.overlap @punchSprite, player
    else
      false

  # Called when a player punches this mutant.
  onPunched: (player) ->
    playerDirection = sign(player.x - @sprite.x)
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

  # Called when this mutant has been killed.
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

  # Called when we want to gib the mutant (or its dead body).
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

  update: ->
    # FIXME: This should handle multiple players.
    player = @game.groups.players.getFirstAlive()
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


# Our hero. What fists.
#
class Player extends Phaser.Sprite

  constructor: (game, x, y, brain) ->
    super(game, x, y, 'player', 0)
    @anchor.setTo(0.5, 0.5)
    @smoothed = false

    @animations.add('stand', [0], 60, false)
    @animations.add('walk', [1, 2, 3, 0], 5, true)
    @animations.add('punch', [4, 5, 6, 7], 7, true)
    @animations.play('stand')

    @game.physics.enable(this, Phaser.Physics.ARCADE)
    @body.collideWorldBounds = true
    @body.setSize(16, 32, 0, 16)

    @brain = brain or new PlayerBrain(@game, this)

  update: ->
    super
    @brain.update()


# The logic behind a player sprite.
#
class PlayerBrain

  gravity: 750
  hurtDuration: 250
  hurtFlashFrames: 10
  hurtShakeFrames: 4
  hurtSlowMotionFrames: 10
  hurtSlowMotionScale: 2.0
  jumpDuration: 750
  jumpSpeed: 500
  walkSpeed: 150

  constructor: (@game, @sprite) ->
    @hurtTimer = null
    @jumpTimer = 0
    @punchTimer = 0

    @sprite.body.gravity.y = @gravity
    @sprite.body.maxVelocity.y = @jumpSpeed

    @punchSprite = @game.add.sprite(10, 0, null)
    @punchSprite.anchor.setTo(0.5, 0.5)
    @game.physics.enable(@punchSprite, Phaser.Physics.ARCADE)
    @punchSprite.body.allowGravity = false
    @punchSprite.body.allowRotation = false
    @punchSprite.body.setSize(24, 32, 0, 16)
    @sprite.addChild(@punchSprite)

  # Returns true if the player just started displaying a punch frame. Returns
  # false for additional ticks after that while the same frame is display, so
  # that we only trigger punch logic once for a given punch frame.
  isPunching: ->
    anim = @sprite.animations.name
    frame = @sprite.animations.frame
    if anim == 'punch' and (frame == 5 or frame == 7)
      unless @wasPunching
        @wasPunching = true
      else
        false
    else
      @wasPunching = false

  # Called when this player is punched by a mutant.
  onPunched: (mutant) ->
    @hurtTimer = @game.time.now + @hurtDuration
    @game.plugins.effects.flash @hurtFlashFrames
    @game.plugins.effects.shake @hurtShakeFrames
    @game.plugins.effects.slowMotion @hurtSlowMotionFrames, @hurtSlowMotionScale

  update: ->
    keys = @game.keys

    dirX = 0
    dirY = 0
    dirX -= 1 if keys.left.isDown
    dirX += 1 if keys.right.isDown

    if @punchTimer < @game.time.now and (keys.fire1.isDown or keys.fire2.isDown)
      @punchTimer = @game.time.now + 285

    speed = @walkSpeed
    animation = if @punchTimer > @game.time.now
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
      @game.groups.mutants.forEachAlive((mutant) ->
        if (mutant.brain.action != 'flying' and
            @game.physics.arcade.overlap(@punchSprite, mutant))
          mutant.brain.onPunched(this)
      , this, true)


# This preloader state loads all the image assets and does a nearest neighbor
# scale up by 4x to get the pixellated look we want.
#
class PreloadState extends Phaser.State

  assets: [
    ['image', 'mountains', './assets/mountains.png']
    ['image', 'questionMark', './assets/question_mark.png']
    ['image', 'rocks', './assets/rocks.png']
    ['image', 'tiles', './assets/tiles.png']
    ['image', 'title', './assets/title.png']
    ['spritesheet', 'barrel', './assets/barrel.png', 11, 8]
    ['spritesheet', 'explosion', './assets/explosion.png', 32, 32]
    ['spritesheet', 'explosionSmall', './assets/explosion_small.png', 16, 16]
    ['spritesheet', 'gibsBones', './assets/gibs_bones.png', 5, 4, -1, 1, 1]
    ['spritesheet', 'gibsParticles', './assets/gibs_particles.png', 1, 1, -1, 1, 1]
    ['spritesheet', 'mutant', './assets/mutant.png', 16, 16]
    ['spritesheet', 'player', './assets/player.png', 16, 16]
  ]
  assetScale: 4

  preload: ->
    super
    @canvas = document.createElement('canvas')
    for [type, key, url, args...] in @assets
      @load[type](key, url, args...)

  create: ->
    for [type, key, url, args...] in @assets
      image = @cache.getImage(key)
      continue unless image
      @scaleImage(image, @assetScale)
      @cache.removeImage(key)
      if type == 'spritesheet'
        # For spritesheets, we also need to scale up some of the arguments.
        [frameWidth, frameHeight, frameMax, margin, spacing] = args
        frameWidth *= @assetScale
        frameHeight *= @assetScale
        frameMax ?= -1
        margin = (margin or 0) * @assetScale
        spacing = (spacing or 0) * @assetScale
        @cache.addSpriteSheet(key, url, image, frameWidth, frameHeight,
                              frameMax, margin, spacing)
      else
        @cache.addImage(key, url, image)
    @game.state.start('menu')

  # Scale the image in place by the given amount. This does the scaling work
  # in a canvas object, then sets the src on the image element to a data URI
  # from the canvas.
  scaleImage: (image, scale) ->
    width = image.width
    height = image.height
    scaledWidth = width * scale
    scaledHeight = height * scale

    @canvas.width = scaledWidth
    @canvas.height = scaledHeight
    context = @canvas.getContext('2d')
    context.clearRect(0, 0, scaledWidth, scaledHeight)

    context.drawImage(image, 0, 0)
    imageData = context.getImageData(0, 0, width, height)
    data = imageData.data

    scaledImageData = context.createImageData(scaledWidth, scaledHeight)
    scaledData = scaledImageData.data

    for y in [0...height]
      rowIndex = y * width * 4
      for x in [0...width]
        index = rowIndex + (x * 4)
        r = data[index + 0]
        g = data[index + 1]
        b = data[index + 2]
        a = data[index + 3]
        scaledX = x * scale
        scaledY = y * scale
        scaledIndex = (scaledY * scaledWidth * 4) + (scaledX * 4)
        for sy in [0...scale]
          scaledRowIndex = scaledIndex + (sy * scaledWidth * 4)
          for sx in [0...scale]
            si = scaledRowIndex + (sx * 4)
            scaledData[si + 0] = r
            scaledData[si + 1] = g
            scaledData[si + 2] = b
            scaledData[si + 3] = a

    context.clearRect(0, 0, scaledWidth, scaledHeight)
    context.putImageData(scaledImageData, 0, 0)
    image.src = @canvas.toDataURL()


# The menu state... this was an ugly hack and should be ignored.
#
class MenuState extends Phaser.State

  cameraSpeed: 100
  worldGravity: 300

  create: ->
    @game.physics.startSystem(Phaser.Physics.ARCADE)
    @game.physics.arcade.gravity.y = @worldGravity

    @stage.backgroundColor = '#dbecff'  # This is the sky blue background.
    @farBackground = @game.add.tileSprite(0, 224, @game.width, 192,
                                          'mountains', 0)
    @farBackground.autoScroll(-10, 0)
    @farBackground.fixedToCamera = true
    @farBackground.tint = 0xcccccc

    numDirtTiles = 16
    dirtBag = new RandomBag([0...numDirtTiles])
    @map = new Phaser.Tilemap(@game, null, 32, 32, 100, 100)
    @map.addTilesetImage('tiles', 'tiles', 32, 32, 4, 4)
    @map.createBlankLayer('dirt', @map.width, @map.height, 32, 32).resizeWorld()
    for y in [11...13]
      for x in [0...@map.width]
        @map.putTile(dirtBag.pop(), x, y)

    @title = @game.add.image(0, 0, 'title')
    @title.fixedToCamera = true

    players = []
    for i in [0...4]
      player = new Player(@game, 630, 238 + i * 48, update: ->)
      player.body.allowGravity = false
      player.body.immovable = true
      player.fixedToCamera = true
      player.scale.x = -1
      @game.world.add(player)
      players.push(player)
    [@jumpPlayer, @punchPlayer, @leftWalkPlayer, @rightWalkPlayer] = players

    @leftWalkPlayer.animations.play('walk')
    @leftWalkPlayer.animations.next()

    @rightWalkPlayer.animations.play('walk')
    @rightWalkPlayer.scale.x = 1

    @jumpPlayer.animations.play('stand')
    @jumpPlayer.body.allowGravity = true
    @jumpPlayer.body.gravity.y = 750
    @jumpPlayer.fixedToCamera = false
    @jumpPlayerX = @jumpPlayer.x
    @jumpPlayerY = @jumpPlayer.y
    @jumpTime = @game.time.now + 1000

    @punchPlayer.animations.play('punch')
    @punchTime = @game.time.now + 1000

    @key = @game.input.keyboard.addKey(Phaser.Keyboard.SPACEBAR)

  update: ->
    @game.camera.x += @cameraSpeed * (@game.time.elapsed / 1000)
    @game.camera.x %= 2000

    if @jumpPlayer.body.y > @jumpPlayerY
      @jumpPlayer.body.reset(@jumpPlayerX, @jumpPlayerY)
      @jumpPlayer.animations.play('stand')
    if @jumpTime < @game.time.now
      @jumpTime = @game.time.now + 1000
      @jumpPlayer.body.velocity.y = -300
      @jumpPlayer.animations.play('walk')
    @jumpPlayer.x = Math.floor(@game.camera.x + @jumpPlayerX)

    if @punchTime < @game.time.now
      @punchTime = @game.time.now + 1000
      @punchPlayer.animations.play(
        if @punchPlayer.animations.name == 'punch' then 'stand' else 'punch')

    @game.state.start('play') if @key.isDown


# The play state.
#
class PlayState extends Phaser.State

  farBackgroundScroll: 0.1
  nearBackgroundScroll: 0.3
  worldGravity: 300

  create: ->
    @game.physics.startSystem(Phaser.Physics.ARCADE)
    @game.physics.arcade.gravity.y = @worldGravity

    # Create a bunch of groups so we can be sure things are ordered properly.
    # We store this as game.groups, too, so sprites and such can get to the
    # sets of groups.
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
    @groups.mutants.classType = Mutant
    @groups.players = @game.add.group()
    @groups.players.classType = Player
    @groups.effects = @game.add.group()

    # Add our effects plugin to the game. It can be accessed via
    # game.plugins.effects from sprites and such.
    @game.plugins.effects = @game.plugins.add(EffectsPlugin)

    @stage.backgroundColor = '#dbecff'  # This is the sky blue background.
    @farBackground = @game.add.tileSprite(0, @game.height - 192 - 32,
                                          @game.width, 192, 'mountains', 0,
                                          @groups.background)
    @farBackground.fixedToCamera = true

    @createRandomMap()

    @game.keys = @game.input.keyboard.createCursorKeys()
    @game.keys.jump1 = @game.input.keyboard.addKey(Phaser.Keyboard.SPACEBAR)
    @game.keys.jump2 = @game.input.keyboard.addKey(Phaser.Keyboard.Z)
    @game.keys.fire1 = @game.input.keyboard.addKey(Phaser.Keyboard.CONTROL)
    @game.keys.fire2 = @game.input.keyboard.addKey(Phaser.Keyboard.C)

    @player = @groups.players.create(32, @game.height - 64)
    @camera.follow(@player, Phaser.Camera.FOLLOW_PLATFORMER)

  # Create some random terrain to fill the world.
  createRandomMap: ->
    @map = new Phaser.Tilemap(@game, null, 32, 32, 200, 20)
    @map.addTilesetImage('tiles', 'tiles', 32, 32, 4, 4)

    @dirtLayer = @map.createBlankLayer('dirt', @map.width, @map.height, 32, 32)
    @dirtLayer.resizeWorld()
    @camera.setBoundsToWorld()

    # Iterate over the width of the world (in tiles), and place random dirt
    # tiles. Each column has a chance of increasing or decreasing in height.
    # The chance starts very low, but increases a bit each column, so we are
    # guaranteed to get height changes, but not *too many* height changes.
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

    # Place some barrels at regular intervals.
    stepWidth = 20
    for stepX in [0...@map.width] by stepWidth
      tileX = @game.rnd.between(stepX, stepX + stepWidth - 1)
      tileY = @map.height - heights[tileX]
      @game.groups.barrels.create(tileX * 32 + 16, tileY * 32)

    # Create a bunch of mutants to punch.
    for i in [0...40]
      @groups.mutants.create(@game.rnd.between(0, @world.width),
                             @game.height - 64)

  update: ->
    @farBackground.tilePosition.set(@game.camera.x * -@farBackgroundScroll, 0)
    @game.physics.arcade.collide(@groups.gibs.barrel, @dirtLayer)
    @game.physics.arcade.collide(@groups.gibs.barrelWaste, @dirtLayer)
    @game.physics.arcade.collide(@groups.gibs.particles, @dirtLayer)
    @game.physics.arcade.collide(@groups.gibs.bones, @dirtLayer)
    @game.physics.arcade.collide(@groups.gibs.heads, @dirtLayer)
    @game.physics.arcade.collide(@groups.players, @dirtLayer)
    @game.physics.arcade.collide(@groups.mutants, @dirtLayer)


do ->
  game = new Phaser.Game(900, 500, Phaser.AUTO, 'phaser')
  game.state.add('preload', new PreloadState())
  game.state.add('menu', new MenuState())
  game.state.add('play', new PlayState())
  game.state.start('preload')
  window.mutantsMustDie = game
