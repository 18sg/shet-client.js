{Connector} = require "./connector"
{Client} = require "./shet_generic"
recon = require "recon"
lines = require "lines-adapter"

class NodeConnector extends Connector
	constructor: ->
		super
		# Get the shet host and port from the environment,
		# defaulting to localhost:11235.
		shet_port = parseInt(process.env["SHET_PORT"]) || 11235
		shet_host = process.env["SHET_HOST"] || "localhost"
		
		# Make a connection, and bind to the appropriate events.
		@connection = recon shet_host, shet_port
		@connection.on "connect", @on_connect
		@connection.on "reconnect", @on_reconnect
		@connection.on "drop", @on_disconnect
		lines(@connection).on "data", (line) =>
			@on_msg JSON.parse(line)
	
	send_msg: (msg) =>
		@connection.write (JSON.stringify msg) + "\r\n"
	
	disconnect: =>
		@connection.end()


class NodeClient extends Client
	constructor: ->
		super new NodeConnector()


listen_socket = (socket) ->
	socket.sockets.on "connection", (socket_client) ->
		shet_client = new NodeConnector()
		
		shet_client.on "msg", (msg) ->
			socket_client.emit "msg", msg
		
		shet_client.on "disconnect", () ->
			socket_client.disconnect()
		
		socket_client.on "msg", (msg) ->
			shet_client.send_msg msg
		
		socket_client.on "disconnect", (msg) ->
			shet_client.disconnect()


exports.Client = NodeClient
exports.listen_socket = listen_socket
