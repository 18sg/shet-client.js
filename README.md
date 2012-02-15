# What is this?

A client library for [SHET](https://github.com/18sg/SHET). It can be used in [Node.js](http://nodejs.org/), or in web browsers using [Socket.IO](http://socket.io/).

# How do I get it?

	npm install shet-client

# How do I use it?
## In Node.js

	var shet = new (require("shet-client").Client)();

## In the browser

This uses Socket.IO, so it's probably easiest to get that working first (see
[http://socket.io/#how-to-use](http://socket.io/#how-to-use)).

Install as above, then use
[Browserify](https://github.com/substack/node-browserify) to generate a single
library file:

	browserify -r shet-client -o public/shet.js

Include this in your page, then add the something like this to the server:

	# after "io = require('socket.io').listen(app)"
	require("shet-client").listen_socket(io);

...and something like this to the client:

	# after "var socket = io.connect(...);"
	var shet = new (require("shet-client").Client)(socket);

This creates a SHET client, that can be used exactly as in node.
