{Connector} = require "./connector"
{Client} = require "./shet_generic"
Lazy=require("lazy")
net = require "net"

# A connector that uses regular sockets to connect to SHET.
class NodeConnector extends Connector
	constructor: (opts) ->
		super
		# Make a connection, and bind to the appropriate events.
		@connection = new net.Socket
		# @connection.on "connect", @on_connect
		# @connection.on "close", @on_disconnect
		new Lazy(@connection).lines.map(JSON.parse).forEach(@on_msg)
		
	
		# Various options.
		@connect_delay = opts.connect_delay ? 1500
		@shet_port = opts.port ? (parseInt(process.env["SHET_PORT"]) || 11235)
		@shet_host = opts.host ? (process.env["SHET_HOST"] || "localhost")
		
		# State machine.
		@states =
			start:
				next: ["connecting"]
			connecting:
				enter: =>
					@connection.connect @shet_port, @shet_host
				next: ["connected", "wait"]
				events:
					connect: => @enter_state "connected"
					close: => @enter_state "wait"
					error: => @enter_state "wait"
			connected:
				enter: =>
					@on_connect()
				exit: =>
					@on_disconnect()
				events:
					close: => @enter_state "wait"
					error: => @enter_state "wait"
				next: ["wait"]
			wait:
				enter: =>
					@connection.end()
					setTimeout (=> @enter_state "connecting"), @connect_delay
				next: ["connecting"]
		
		@init_state "connecting"
	
	# Move to the next state.
	# This checks that this is a valid transition unless force is given.
	enter_state: (next, force=false) =>
		if force or next in @states[@state].next
			@states[@state].exit?()
			
			if @states[@state].events?
				@connection.removeListener k, v for k, v of @states[@state].events
			
			@state = next
			
			@states[@state].enter?()
			
			if @states[@state].events?
				@connection.once k, v for k, v of @states[@state].events
		else
			console.error "Invalid transition from %s to %s.", @state, next
	
	# Initialise the state.
	init_state: (next) =>
			@state = next
			@states[@state].enter?()
			
			if @states[@state].events?
				@connection.once k, v for k, v of @states[@state].events
	
	# Force a transition.
	reset_state: (next) =>
		@enter_state next, true
	
	# Tell the connection to reconnect if it's not already.
	reconnect: =>
		if @state in ["connecting", "connected"]
			@enter_state "wait"
	
	# Write a JSON message to the socket.
	send_msg: (msg) =>
		@connection.write (JSON.stringify msg) + "\r\n"
	
	# Stop the connection.
	disconnect: =>
		@connection.end()
		@reset_state "start"

# Connect to SHET using a NodeConnector. Returns a connected Client instance.
connect = (opts = {}) ->
	new Client(opts, new NodeConnector(opts))

	
# Accept connections on the given Socket.IO channel, and pass traffic to the
# SHET server (which is resolved as above).
listen_socket = (socket, opts={}) ->
	socket.sockets.on "connection", (socket_client) ->
		shet_client = new NodeConnector(opts)
		
		shet_client.on "msg", (msg) ->
			socket_client.emit "msg", msg
		
		shet_client.on "disconnect", () ->
			socket_client.disconnect()
		
		socket_client.on "msg", (msg) ->
			shet_client.send_msg msg
		
		socket_client.on "disconnect", (msg) ->
			shet_client.disconnect()


module.exports = {connect, listen_socket}
