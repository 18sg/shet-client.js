{Connector} = require "./connector"
{Client} = require "./shet_generic"


class SocketIoConnector extends Connector
	constructor: (@socket) ->
		super
		
		@socket.on "msg", @on_msg
		@socket.on "connect", @on_connect
	
	send_msg: (msg) =>
		@socket.emit "msg", msg
	
	disconnect: =>
		@socket.disconnect()


class SocketClient extends Client
	constructor: (socket) ->
		super new SocketIoConnector(socket)


exports.Client = SocketClient
