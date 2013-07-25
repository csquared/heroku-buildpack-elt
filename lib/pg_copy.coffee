#!/usr/bin/env coffee

spawn  = require("child_process").spawn
coffee = require "coffee-script"
logfmt = require('logfmt')

module.exports.PgCopy = class PgCopy
  constructor: (@spec, @options = {}) ->

  where: ->
    if @spec.where?
      where_clause = @spec.where.join(' AND ')
      "WHERE #{where_clause}"
    else
      ""
  schema: -> @options.build_schema || process.env['build_schema'] || 'public'

  in_sql: ->
    in_sql = ""
    in_sql += "set search_path TO \"#{@schema()}\"; "
    in_sql += "DROP TABLE IF EXISTS #{@spec.destination_table}; "
    create_fields = ("\"#{field}\" #{type}" for field, type of @spec.fields).join(', ')
    in_sql += "CREATE TABLE #{@spec.destination_table} (#{create_fields}); "
    in_sql += "COPY #{@spec.destination_table} FROM STDIN BINARY; "

  out_sql: ->
    select_fields = ("\"#{key}\"" for key, value of @spec.fields).join(', ')
    out_sql = "set work_mem = '1GB'; "
    out_sql += "COPY (SELECT #{select_fields} FROM #{@spec.source_table} #{@where()}) TO STDOUT BINARY"

  log_params: (params) ->
    _params =
      from: @spec.source_db      + '::' + @spec.source_table
      to:   @spec.destination_db + '::' + @spec.destination_table
      app: 'elt'
    coffee.helpers.merge _params, params

  copy_out_args: ->
    [process.env[@spec.source_db], '-c', @out_sql()]

  copy_in_args: ->
    [process.env[@spec.destination_db], '-c', @in_sql()]

  run: (callback = null) ->
    logfmt.log @log_params(fn: 'pg_copy_run', out_sql: @out_sql(), in_sql: @in_sql())
    if !process.env['DEBUG']
      startTime = new Date()
      copy_out = spawn 'psql', @copy_out_args()
      copy_in  = spawn 'psql', @copy_in_args()
      copy_out.stdout.pipe copy_in.stdin
      copy_in.stderr.on  'data', (data) -> process.stdout.write("STDERR #{data}")
      copy_out.stderr.on 'data', (data) -> process.stdout.write("STDERR #{data}")
      copy_out.on 'exit', (code) -> logfmt.log {at: "copy_out_exit", status: code, last: code}
      copy_in.on  'exit', (code) =>
        elapsed = (new Date() - startTime) / 1000 + 's'
        logfmt.log @log_params(fn: 'pg_copy_spawn', status: code, last: code, elpased: elapsed)
        callback() if callback
