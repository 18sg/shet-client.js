{NodeConnector} = require "./node_connector"

exports.listen = (socket) ->
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
