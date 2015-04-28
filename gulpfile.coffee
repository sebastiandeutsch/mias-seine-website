es              = require 'event-stream'
gulp            = require 'gulp'
fs              = require 'fs'
source          = require 'vinyl-source-stream'
browserify      = require 'browserify'
watchify        = require 'watchify'
coffeeify       = require 'coffeeify'
runSequence     = require 'run-sequence'
gulpLoadPlugins = require 'gulp-load-plugins'
browserSync     = require 'browser-sync'
reload          = browserSync.reload
$               = gulpLoadPlugins()
isProduction    = false

###############################################################################
# constants
###############################################################################

BASES =
  src: './src'
  build: './build'

SERVER_PORT       = 3456

VENDOR_DIR        = "./#{BASES.src}/scripts/vendor/"
SCRIPTS_BUILD_DIR = "#{BASES.build}/scripts"

###############################################################################
# helper function
###############################################################################
handleErrors = () ->
  args = Array.prototype.slice.call(arguments);

  $.notify.onError({
    title: "Compile Error",
    message: "<%= error.message %>"
  }).apply(this, args);

  this.emit('end');
  return

###############################################################################
# set-production
###############################################################################
gulp.task 'set-production', ->
  isProduction = true

###############################################################################
# clean
###############################################################################

gulp.task 'clean', ->
  gulp.src(BASES.build).pipe($.clean())

###############################################################################
# haml
###############################################################################

gulp.task 'haml', ->
  gulp.src(["#{BASES.src}/**/*.haml", "!#{BASES.src}/pages/**/_*"])
    .pipe($.plumber({errorHandler: $.notify.onError("Error: <%= error.message %>")}))
    .pipe($.rubyHaml())
    .pipe(gulp.dest("#{BASES.build}"))
    .pipe($.if(!isProduction, reload({ stream: true, once: true })))

###############################################################################
# coffeelint
###############################################################################

gulp.task 'coffeelint', ->
  gulp.src('#{BASES.src}/scripts/**/*.coffee')
    .pipe($.plumber({errorHandler: $.notify.onError("Error: <%= error.message %>")}))
    .pipe($.coffeelint())
    .pipe($.coffeelint.reporter())

###############################################################################
# compass
###############################################################################

gulp.task 'compass', ->
  gulp.src(["#{BASES.src}/stylesheets/**/*.{css,scss,sass}", "!#{BASES.src}/pages/**/_*"])
    .pipe($.plumber({errorHandler: $.notify.onError("Error: <%= error.message %>")}))
    .pipe($.compass(
      config_file: './config.rb'
      css: "build/stylesheets",
      sass: "src/stylesheets"
    ))
    .on('error', $.notify.onError({ onError: true }))
    .on('error', $.util.log)
    .on('error', $.util.beep)
    .pipe(gulp.dest("#{BASES.build}/stylesheets"))
    .pipe($.if(!isProduction, reload({ stream: true, once: true })))

###############################################################################
# copy
###############################################################################

gulp.task 'copy', ->
  gulp.src("#{BASES.src}/assets/**")
    .pipe($.plumber({errorHandler: $.notify.onError("Error: <%= error.message %>")}))
    .pipe(gulp.dest("#{BASES.build}/assets"))
    .pipe($.if(!isProduction, reload({ stream: true, once: true })))

###############################################################################
# uglify:all
###############################################################################

gulp.task 'uglify:all', ->
  gulp.src('#{BASES.build}/scripts/*.js')
    .pipe($.plumber({errorHandler: $.notify.onError("Error: <%= error.message %>")}))
    .pipe($.uglify())
    .pipe($.rename({ suffix: '.min' }))
    .pipe(gulp.dest("#{BASES.build}/scripts"))

###############################################################################
# cssmin:minify
###############################################################################

gulp.task 'cssmin:minify', ->
  gulp.src('#{BASES.build}/stylesheets/*.css')
    .pipe($.plumber({errorHandler: $.notify.onError("Error: <%= error.message %>")}))
    .pipe($.cssmin())
    .pipe($.rename({ suffix: '.min' }))
    .pipe(gulp.dest("#{BASES.build}/stylesheets"));

###############################################################################
# Browserify
###############################################################################

gulp.task 'watchify', ->
  bundler = browserify
    cache: {},
    packageCache: {},
    fullPaths: true,
    entries: ["#{BASES.src}/scripts/application.coffee"],
    extensions: ['.coffee', '.js'],
    debug: !isProduction

  bundler.transform(coffeeify)

  rebundle = ->
    bundler
      .bundle()
      .on('error', handleErrors)
      .pipe(source('application.js'))
      .pipe(gulp.dest(SCRIPTS_BUILD_DIR))
      .pipe($.if(!isProduction, reload({ stream: true, once: true })))

  unless isProduction
    bundler = watchify(bundler)
    bundler.on 'update', rebundle

  rebundle()

###############################################################################
# watch
###############################################################################

gulp.task 'watch', ->
  gulp.watch "#{BASES.src}/**/*.haml", ['build:markup']
  gulp.watch "#{BASES.src}/assets/**/*", ['copy']
  gulp.watch "#{BASES.src}/stylesheets/**/*.{css,scss,sass}", ['build:stylesheets']

###############################################################################
# serve
###############################################################################
gulp.task 'serve', ->
  browserSync({
    notify: false,
    server: {
      baseDir: [BASES.build]
    },
    ports: {
      min: SERVER_PORT
    }
  })
  console.log "Point your browser to #{SERVER_PORT}"

###############################################################################
# high level tasks
###############################################################################

gulp.task 'build:markup', ['copy', 'haml']
gulp.task 'build:scripts', ->
  runSequence 'coffeelint', 'watchify', 'uglify:all'
gulp.task 'build:stylesheets', ->
  runSequence 'compass', 'cssmin:minify'

gulp.task 'build', ->
  console.log 'browserify:sequence'
  seq = runSequence(
    'clean',
    [
      'build:markup'
      'build:scripts'
      'build:stylesheets'
    ]
  )
  seq

gulp.task 'heroku', ->
  runSequence('set-production', 'build')
gulp.task 'default', ->
  runSequence('build', 'serve', 'watch')
