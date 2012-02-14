{Connector} = require "./connector"

class SocketIoConnector extends Connector
	constructor: (@socket) ->
		super
		
		@socket.on "msg", @on_msg
		@socket.on "connect", @on_connect
	
	send_msg: (msg) =>
		@socket.emit "msg", msg
	
	disconnect: =>
		@socket.disconnect()

exports.SocketIoConnector = SocketIoConnector
