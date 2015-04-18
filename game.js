(function() {
  'use strict';

  var _canvas = document.createElement('canvas');
  var _scale = 4;
  var _scaledImageUrls;
  var _width = 900;
  var _height = 600;
  var _game = new Phaser.Game(_width, _height, Phaser.AUTO, 'phaser');


  var loadScaledImage = function(url, callback, callbackContext) {
    var image;

    var onImageLoaded = function() {
      var width = image.width;
      var height = image.height;
      var scaledWidth = width * _scale;
      var scaledHeight = height * _scale;

      _canvas.width = scaledWidth;
      _canvas.height = scaledHeight;
      var context = _canvas.getContext('2d');
      context.clearRect(0, 0, scaledWidth, scaledHeight);

      context.drawImage(image, 0, 0);
      var imageData = context.getImageData(0, 0, width, height);
      var data = imageData.data;

      var scaledImageData = context.createImageData(scaledWidth, scaledHeight);
      var scaledData = scaledImageData.data;

      for (var y = 0; y < height; y++) {
        for (var x = 0; x < width; x++) {
          var index = (y * width * 4) + (x * 4);
          var r = data[index + 0];
          var g = data[index + 1];
          var b = data[index + 2];
          var a = data[index + 3];

          var scaledX = x * _scale;
          var scaledY = y * _scale;
          var scaledIndex = (scaledY * scaledWidth * 4) + (scaledX * 4);
          for (var sy = 0; sy < _scale; sy++) {
            for (var sx = 0; sx < _scale; sx++) {
              var si = scaledIndex + (sy * scaledWidth * 4) + (sx * 4);
              scaledData[si + 0] = r;
              scaledData[si + 1] = g;
              scaledData[si + 2] = b;
              scaledData[si + 3] = a;
            }
          }
        }
      }

      context.clearRect(0, 0, scaledWidth, scaledHeight);
      context.putImageData(scaledImageData, 0, 0);
      callback.call(callbackContext, _canvas.toDataURL());
    };

    image = document.createElement('img');
    image.onload = onImageLoaded;
    image.src = url;
  };

  var loadScaledImages = function(images, callback, context) {
    var numImages = images.length;
    var numLoadedImages = 0;
    var onImageScaled = function(url) {
      var image = this;
      image.scaledUrl = url;
      numLoadedImages++;
      if (numLoadedImages >= numImages) {
        callback.call(context, images);
      }
    };
    for (var i = 0; i < images.length; i++) {
      var image = images[i];
      loadScaledImage(image.url, onImageScaled, image);
    }
  };

  window.addEventListener('load', function() {
    loadScaledImages([
      {
        key: 'kid',
        url: '/assets/kid.png'
      }
    ], function(images) {
      _scaledImageUrls = {};
      images.forEach(function(image) {
        _scaledImageUrls[image.key] = image.scaledUrl;
      });
      console.log(_scaledImageUrls);
      _game.state.start('menu');
    });
  }, false);

  _game.state.add('menu', {
    preload: function() {

    },

    create: function() {
      this.stage.backgroundColor = '#42244d';

      var playButtonGraphics = this.game.make.graphics(0, 0);
      playButtonGraphics.beginFill(Phaser.Color.getColor(255, 255, 255), 1.0);
      playButtonGraphics.drawRect(0, 0, 200, 50);
      playButtonGraphics.endFill();
      var playButtonText = this.game.make.text(70, 7, 'Play');
      var playButton = this.game.add.button(
        (_width - 200) / 2, (_height - 50) / 2, null, this.playButtonClicked, this);
      playButton.addChild(playButtonGraphics);
      playButton.addChild(playButtonText);
    },

    update: function() {

    },

    render: function() {

    },

    playButtonClicked: function() {
      this.game.state.start('play');
    }
  });

  _game.state.add('play', {
    preload: function() {
      this.load.spritesheet('kid', _scaledImageUrls.kid, 64, 64);
    },

    create: function() {
      this.keys = this.game.input.keyboard.createCursorKeys();
      this.player = this.game.add.sprite(0, 0, 'kid', 0);
      this.player.anchor.setTo(0.5, 0.5);
      this.player.animations.add('stand', [0], 60, false);
      this.player.animations.add('walk', [1, 2, 3, 0], 5, true);
      this.player.animations.play('walk');
      this.player.moveX = this.player.x;
      this.player.moveY = this.player.y;
    },

    update: function() {
      var moveX = 0;
      var moveY = 0;
      if (this.keys.up.isDown) {
        moveY -= 1;
        this.player.animations.play('walk');
      }
      if (this.keys.down.isDown) {
        moveY += 1;
        this.player.animations.play('walk');
      }
      if (this.keys.left.isDown) {
        moveX -= 1;
      }
      if (this.keys.right.isDown) {
        moveX += 1;
      }
      if (moveX || moveY) {
        this.player.animations.play('walk');
        if (moveX === -1) {
          this.player.scale.x = -1;
        } else if (moveX === 1) {
          this.player.scale.x = 1;
        }
      } else {
        this.player.animations.play('stand');
      }
      this.player.x += moveX;
      this.player.y += moveY;
    }
  });
})();
