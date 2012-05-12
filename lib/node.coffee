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
		@connection.on "connect", @on_connect
		@connection.on "close", @on_disconnect
		new Lazy(@connection).lines.map(JSON.parse).forEach(@on_msg)
		
		# State machine.
		@state = "start"
		@listeners = (f) =>
	
		# Various options.
		@connect_delay = opts.connect_delay ? 1500
		@shet_port = opts.port ? (parseInt(process.env["SHET_PORT"]) || 11235)
		@shet_host = opts.host ? (process.env["SHET_HOST"] || "localhost")
		
		# Connect.
		@state_connecting()
	
	# Take a function that will be passed @connection.once then this is called,
	# then passed connection.removelistener when this is called. This is usefull
	# to setup listeners until the next state transition.
	setup_listeners: (f) =>
		@listeners(@connection.removeListener.bind(@connection))
		f(@connection.once.bind(@connection))
		@listeners = f
	
	# Connection has been initialted, but is not connected yet.
	state_connecting: =>
		if @state in ["start", "wait"]
			@state = "connecting"
			
			@connection.connect @shet_port, @shet_host
			
			@setup_listeners (once) =>
				once "connect", @state_connected
				once "close", @state_wait
				once "error", @state_wait
		else
			console.error "Invalid transition from %s to connecting.", @state
	
	# Connection is connected.
	state_connected: =>
		if @state in ["connecting"]
			@state = "connected"
			
			@setup_listeners (once) =>
				once "close", @state_wait
				once "error", @state_wait
		else
			console.error "Invalid transition from %s to connected.", @state
	
	# Connection is waiting before being reconnected.
	state_wait: =>
		if @state in ["connecting", "connected"]
			@state = "wait"
			
			@connection.end()
			setTimeout @state_connecting, @connect_delay
			
			@setup_listeners (once) =>
		else
			console.error "Invalid transition from %s to wait.", @state
	
	# Tell the connection to reconnect if it's not already.
	reconnect: =>
		if @state in ["connecting", "connected"]
			@state_wait()
	
	send_msg: (msg) =>
		@connection.write (JSON.stringify msg) + "\r\n"
	
	# Stop the connection.
	disconnect: =>
		@state = "start"
		@setup_listeners (once) =>
		@connection.end()

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
