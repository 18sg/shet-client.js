A client library for [SHET](https://github.com/18sg/SHET). It can be used in
[Node.js](http://nodejs.org/), or in web browsers using
[Socket.IO](http://socket.io/).

## Get

	npm install shet-client

## Use
### In Node.js

	var shet = require("shet-client").connect();

### In the browser

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
	var shet = require("shet-client").connect(socket);

This creates a SHET client, that can be used exactly as in Node.

### The API

Rather than using callbacks for everything, this library uses
[Q](https://github.com/kriskowal/q) to provide 'deferred values' or 'promises',
as in the Twisted version.

#### var c = connect()

Create a new client. The host and port to connect to are taken from $SHET_HOST
and $SHET_PORT, and default to localhost:11235, as is standard.

#### var c = connect(socket)

Create a new client connected to the given Socket.IO channel.

#### listen_socket(socket)

Accept connections on the given Socket.IO channel, and pass traffic to the SHET
server (which is resolved as above).

#### c.add_action(path, callback)

Add an action. When the action is called, `callback` will be called with the
appropriate arguments, and it's return value will be returned to the caller. If
`callback` returns a Q promise, it will wait for this to resolve before
returning, as expected.

#### c.add_event(path)

Add an event. This returns an object with a `raise` attribute. Calling this
with any number of arguments raises the event with the given arguments.

#### c.add_prop(path, get_cb, set_cb)

Add a property. `get_cb` should take no arguments and return the desired value
of the property. `set_cb` should take a single argument, and set the property.

#### c.watch(path, callback)

Watch an event. The callback will be called with the arguments of the event.

#### c.call(path, args...)

Call an action with some arguments. This returns a promise, which will resolve
to the return value of the action.

#### c.get(path)

Get a property. This returns a promise, which will resolve to the return value
of the action.

#### c.set(path, value)

Set a property to `value`. This returns a promise, which will resolve when the
set completes.

## Todo

- Examples
- Setting the root directory
- Removing properties/events/actions.
- Event added/removed events?
- Testing

## About

MIT licensed; see [LICENSE](https://github.com/18sg/shet-client.js/blob/master/LICENSE).

Built with [CoffeeScript](http://coffeescript.org/),
[Node.js](http://nodejs.org/), [Socket.IO](http://socket.io/),
[Q](https://github.com/kriskowal/q),
[Browserify](https://github.com/substack/node-browserify),
[recon](https://github.com/substack/node-recon), and
[Lazy](https://github.com/pkrumins/node-lazy).
