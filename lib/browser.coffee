{Client, Connector} = require "./shet_generic"

# Connect to shet using the given Socket.IO connection.
class SocketIoConnector extends Connector
	constructor: (@socket) ->
		super
		
		@socket.on "msg", @on_msg
		@socket.on "connect", @on_connect
	
	send_msg: (msg) =>
		@socket.emit "msg", msg
	
	disconnect: =>
		@socket.disconnect()


# Connect to shet using the given Socket.IO connection. Returns a Client
# instance.
connect = (socket, opts={}) ->
	# socket.op already sends heartbeats for us.
	opts.ping_interval = 0
	new Client(opts, new SocketIoConnector(socket))


module.exports = {connect}
