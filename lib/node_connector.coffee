{Connector} = require "./connector"
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

exports.NodeConnector = NodeConnector
