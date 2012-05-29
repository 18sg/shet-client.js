Q = require "q"
{EventEmitter} = require "events"

# Dispatcher for shet commands, matching a command (a list) to a handler
# based on it's first elements.
# For example, if one calls:
#   on [foo, bar], f
#   on [foo, baz], g
# , call [foo, bar, quux...] => f(quux...)
# , call [foo, baz) => g()
# This also supports commands that result in multiple calls, so:
#   on_multi [wombat, squirrel], f
#   on_multi [wombat, squirrel], g
#   call[wombat, squirrel, badger...] => none (but calls f & g)
class CommandDispatcher
	constructor: () ->
		@commands = {}
	
	on: (command, callback) =>
		add = (commands, cmd) ->
			[first, rest...] = cmd
			if rest.length == 0
				commands[first] = callback
			else
				if commands[first] is undefined then commands[first] = {}
				add commands[first], rest
		add @commands, command
	
	on_multi: (command, callback) =>
		add = (commands, cmd) ->
			[first, rest...] = cmd
			if rest.length == 0
				if commands[first]?
					if not commands[first].length?
						throw new Error "Inconsistent command handlers."
					commands[first].push(callback)
				else
					commands[first] = [callback]
			else
				if commands[first] is undefined then commands[first] = {}
				add commands[first], rest
		add @commands, command
	
	call: (command) =>
		sub_call = (commands, cmd) ->
			if cmd.length == 0
				throw new Error "Not enough arguments in command."
			else
				[first, rest...] = cmd
				switch typeof commands[first]
					when "undefined"
						throw new Error "Unrecognised command."
					when "function"
						commands[first](rest...)
					when "object"
						if commands[first] instanceof Array
							handler(rest...) for handler in commands[first]
							null
						else
							sub_call commands[first], rest
		sub_call @commands, command


# Persistent commands are commands that change the state of the server,
# and need to be re-installed upon reconnection.
# The constructor is always passed the client as the first command, and
# the 'add' method is called when a connection comes up. When called from the
# client, the Command object is returned, so add any extra methods in here.
class PersistentCommand
	add: =>

# Add an action.
class Action extends PersistentCommand
	constructor: (@client, @path, @callback) ->
		@client.dispatch.on ["docall", @path], (args...) =>
			@callback args...
	
	add: =>
		@client.command "mkaction", @path

# Add an event.
class Event extends PersistentCommand
	constructor: (@client, @path) ->
	
	add: =>
		@client.command "mkevent", @path
	
	raise: (args...) =>
		@client.command "raise", @path, args...

# Add a property.
class Property extends PersistentCommand
	constructor: (@client, @path, @getter, @setter) ->
		@client.dispatch.on ["getprop", @path], () =>
			@getter()
		@client.dispatch.on ["setprop", @path], (value) =>
			@setter value
	
	add: =>
		@client.command "mkprop", @path

# Watch an event.
class Watch extends PersistentCommand
	constructor: (@client, @path, @callback) ->
		@client.dispatch.on_multi ["event", @path], (args...) =>
			@callback args...
	
	add: =>
		@client.command "watch", @path


# Commands that are run once, and don't change the state of the server.
# The client is always passed as the first argument to the constructor, and the
# return value when called through the client is the 'value' property.
# 'run' is called straight away, or when the connection comes up.
class Command
	constructor: (@client) ->
		@value = Q.defer()
	
	run: =>
	
	get_value: =>
		@value.promise

# Call an action.
class Call extends Command
	constructor: (client, @path, @args...) ->
		super client
	run: => 
		@value.resolve @client.command("call", @path, @args...)

# Set a property.
class Set extends Command
	constructor: (client, @path, @new_value) ->
		super client
	run: => 
		@value.resolve @client.command("set", @path, @new_value)

# Get a property.
class Get extends Command
	constructor: (client, @path) ->
		super client
	run: => 
		@value.resolve @client.command("get", @path)


# Connectors encapsulate a connection to the shet server.
class Connector extends EventEmitter
	constructor: ->
		super()
	
	# Convenience methods to emit specific events; call from subclasses.
	on_connect: =>
		@emit "connect"
	on_disconnect: =>
		@emit "disconnect"
	on_msg: (msg) =>
		@emit "msg", msg
	
	# Public API.
	
	# Send a message to the server. msg should be an array (and therefore may
	# need converting to JSON by the subclasses).
	send_msg: (msg) =>
	
	# Disconnect from the server.
	disconnect: =>
	
	# Tell the connection to reconnect (when a ping fails, usually).
	reconnect: =>


# Turn something that's possibly an error into something more informative to be
# serialised to json.
jsonify_error = (x) ->
	if x instanceof Error
		x.toString()
	else
		x


# A generic shet client, that knows nothing about the connection to the server.
# The constructor argument should be a Connector instance.
class Client extends EventEmitter
	constructor: (opts, @connection) ->
		super()
		
		@return_callbacks = {}
		@persistent_commands = []
		@waiting_commands = []
		@connected = false
		@dispatch = new CommandDispatcher
		@next_id = 0
		@ping_id = null
		
		# Options.
		@ping_interval = opts.ping_interval ? 30000
		
		# Inject the commands into this instance.
		for name, cmd of arguments.callee.commands
			this[name] = cmd.bind(this)
		
		# When the client connects/reconnects.
		on_connect = =>
			@connected = true
			@emit "connect"
			if @ping_interval then @start_ping @ping_interval
			
			# Re-add the persistent commands.
			for node in @persistent_commands
				node.add()
			# Run any commands in the waiting queue.
			for cmd in @waiting_commands
				cmd.run()
			@waiting_commands = []
		
		# When the client disconnects.
		on_disconnect = =>
			@connected = false
			@emit "disconnect"
			if @ping_interval then @stop_ping()
		
		@connection.on "connect", on_connect
		@connection.on "disconnect", on_disconnect
		@connection.on "msg", @process_msg
	
	# Command functions to be injected at instantiation time.
	@commands = []
	
	# Add a presistent command to the class.
	# This creates the method to be ran, and adds it to the commands object.
	@add_presistent_command: (name, cls) ->
		@commands[name] = (args...) ->
			# Construct an object of the class, add it to the persistent_commands
			# array, add it to the server if we're connected, and finally return the
			# command object to the caller.
			cmd = new cls this, args...
			@persistent_commands.push cmd
			if @connected then cmd.add()
			return cmd
	
	# Add a non-persistent command.
	# This creates the method to be ran, and adds it to the commands object.
	@add_command: (name, cls) ->
		@commands[name] = (args...) ->
			# Construct an object of the class, either run it, or put it in the
			# waiting queue, and return the value.
			cmd = new cls(this, args...)
			if @connected then cmd.run() else (@waiting_commands.push cmd)
			return cmd.get_value()
	
	# Add all the commands.
	@add_presistent_command "add_action", Action
	@add_presistent_command "add_event", Event
	@add_presistent_command "watch", Watch
	@add_presistent_command "add_prop", Property
	@add_command "call", Call
	@add_command "get", Get
	@add_command "set", Set
	
	# Process one line from the server.
	process_msg: (msg) =>
		[id, command, args...] = msg
		if command is "return"
			[status, value] = args
			if status is 0
				@return_callbacks[id].resolve(value)
			else
				@return_callbacks[id].reject(value)
			delete @return_callbacks[id]
		else
			# Call the correct command, and add callbacks to send a return.
			Q.call(@dispatch.call, null, [command, args...])
			.then(
				(value) => @do_return id, 0, value,
				(value) => @do_return id, 1, jsonify_error value)
	
	# Send a raw command (should be a list of items).
	send_command: (cmd) =>
		@connection.send_msg cmd
	
	# Send a return command with a given id, status, and value.
	do_return: (id, status, value) =>
		@send_command [id, "return", status, value]
	
	# Send a command with a given name and arguments, returning a deferred value
	# that resolves when the command returns.
	command: (name, args...) =>
		id = @next_id++
		@send_command [id, name, args...]
		d = Q.defer()
		@return_callbacks[id] = d
		return d.promise
	
	# Start pinging the server every timeout milliseconds.
	start_ping: (timeout) =>
		if @ping_id == null
			# The first time round, act as if a ping was received.
			ping_returned = true
			
			do_ping = =>
				if ping_returned
					# If the last ping was successful, reset and send another.
					ping_returned = false
					@command("ping").fin () ->
						ping_returned = true
				else
					# Otherwise, tell the connection to restart.
					@connection.reconnect()
			
			@ping_id = setInterval do_ping, timeout
	
	# Stop pinging the server.
	stop_ping: =>
		if @ping_id != null
			clearInterval @ping_id
			@ping_id = null


exports.Client = Client
exports.Connector = Connector
