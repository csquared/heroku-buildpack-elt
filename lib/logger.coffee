coffee = require("coffee-script")

class Logger
  constructor: (@subject, @options={}) ->

  write: (subject, options={}) ->
    message = ("#{key}=\"#{val.toString().replace('"', '\\"')}\"" for key, val of coffee.helpers.merge(app:subject, options))
    console.log message.join(" ")

  log: (opts={}, cb) ->
    options = coffee.helpers.merge(@options, opts)
    if cb?
      options = coffee.helpers.merge(options, measure:'true')
      logger = new Logger(@subject, options)
      logger.start = new Date().getTime()
      @write @subject, coffee.helpers.merge(options, at:"start")
      cb(logger)
    else
      @write @subject, options

  finish: (opts={}) ->
    options = coffee.helpers.merge(@options, opts)
    finish  = new Date().getTime()
    elapsed = (finish - @start) / 1000
    @write @subject, coffee.helpers.merge(options, at:"finish", elapsed:elapsed)

module.exports = (app_name) ->
  new Logger app_name
