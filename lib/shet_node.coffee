{Client} = require "./shet_generic"
{NodeConnector} = require "./node_connector"

class NodeClient extends Client
	constructor: ->
		super new NodeConnector()

exports.Client = NodeClient
