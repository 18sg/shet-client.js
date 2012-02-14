{SocketIoConnector} = require "./socket_connector"
{Client} = require "./shet_generic"

class SocketClient extends Client
	constructor: (socket) ->
		super new SocketIoConnector(socket)

exports.Client = SocketClient
