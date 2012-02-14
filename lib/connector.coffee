{EventEmitter} = require "events"

class Connector extends EventEmitter
	constructor: ->
		super
	
	on_connect: =>
		@emit "connect"
		
	on_reconnect: =>
		@emit "reconnect"
	
	on_disconnect: =>
		@emit "disconnect"
	
	on_msg: (msg) =>
		@emit "msg", msg
	
	send_msg: (msg) =>
	
	disconnect: =>

exports.Connector = Connector
