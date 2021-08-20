# httpmanager

HTTP handler utility for FiveM and RedM. It can be used as a simple file server, or to provide easy HTTP functionality to any resource.

# Installation

1. Place in your resources directory.

2. Add `start httpmanager` to server.cfg.

# Usage

## As a standalone file server

After installing, you can place files in the `files` folder inside the `httpmanager` resource folder, and those files will be accessible at:

```
http://[server IP]:[server port]/httpmanager/...
```
or
```
https://[owner]-[server ID].users.cfx.re/httpmanager/...
```

For example, if you place a file named `test.html` in the `files` folder, it would be accessible at `http://[server IP]:[server port]/httpmanager/test.html`.

## In other resources

You can quickly add HTTP functionality to any resource using the [`createHttpHandler`](#createhttphandler) export:

```lua
handler = exports.httpmanager:createHttpHandler(options)
```

This creates a new HTTP handler that can be used with `SetHttpHandler` in a server script in the resource:

```lua
SetHttpHandler(exports.httpmanager:createHttpHandler())
```

`options` is a table containing configuration options for the new handler. Any unspecified options will be given their default value.

| Option           | Description                                                                                  | Default        |
|------------------|----------------------------------------------------------------------------------------------|----------------|
| `documentRoot`   | The directory in the resource folder where files are served from.                            | `"files"`      |
| `directoryIndex` | If the path points to a directory, a file with this name inside that directory will be sent. | `"index.html"` |
| `authorization`  | A table of usernames and passwords required to access any files or routes.                   | `nil`          |
| `access`         | A table of paths with which users can access them.                                           | `{}`           |
| `log`            | Whether to log requests to a file in the resource directory.                                 | `false`        |
| `logFile`        | If `log` is `true`, store the log in this file in the resource directory.                    | `"log.json"`   |
| `errorPages`     | A table of custom pages for different error codes (e.g., 404).                               | `{}`           |
| `mimeTypes`      | A table of MIME type associations for extensions, which will override any detected type.     | `{}`           |
| `routes`         | A table of route patterns and callbacks.                                                     | `{}`           |

```lua
SetHttpHandler(exports.httpmanager:createHttpHandler {
	documentRoot = "root",
	directoryIndex = "index.html",
	authorization = {
		["admin"] = "$2a$11$HoxJPx5sTe4RX5qPw1OkSO.ukDdwAvGJwXtmyOE5i.1gz7EvN71.q",
		["user"] = "$2a$11$ILOCJlRiUPhRpmqYiZDDM.EdI16yOtMBTLJKTBLSUHTFzyXjXHJYa"
	},
	access = {
		{path = "/admin/.*", login = {["admin"] = true}},
		{path = "/public/.*", login = false},
		{path = "/public/secret/.*"}
	},
	log = true,
	logFile = "log.json",
	errorPages = {
		[404] = "custom404.html"
	},
	mimeTypes = {
		["ogg"] = "audio/ogg"
	},
	routes = {
		["/players/(%d+)"] = function(req, res, helpers, player)
			if GetPlayerEndpoint(player) then
				res.send(GetPlayerName(player))
			else
				res.sendError(404)
			end
		end
	}
})
```

## Authorization

Access to a handler can be controlled by the `authorization` option. If `authorization` is unset, then no restrictions are applied. If `authorization` is a table of usernames and passwords, then access will only be granted once a client has been authenticated using one of these username/password combinations.

Passwords in the `authorization` table must be hashed. httpmanager includes a built-in utility for generating password hashes, which can be accessed at `http://[server IP]:[server port]/httpmanager/password/`.

```lua
authorization = {
	["admin"] = "$2a$11$HoxJPx5sTe4RX5qPw1OkSO.ukDdwAvGJwXtmyOE5i.1gz7EvN71.q"
}
```

Access can be further refined using the `access` option. `access` is a table of rules that each specify a path pattern and which users (as defined in the `authorization` table) can access it.

```lua
access = {
	{path = "/admin/.*", login = {["admin"] = true}},
	{path = "/public/.*", login = false},
	{path = "/public/secret/.*"}
}
```

In this example, anything under `/admin/` can only be accessed by the user `admin`, and no other users in the `authorization` table. Things under `/public/` require no login, and can be accessed by anyone. However, the last rule adds an exception, where anything under `/public/secret/` goes back to the default of allowing only authorized users access.

The `path` in an access rule is a [Lua pattern](https://www.lua.org/pil/20.2.html). Access rules are tested in reverse order, so later rules will override earlier rules.

## Routes

Routes are handlers for specific URL patterns. When a URL matching one of these patterns is requested, the request is directed to a callback function to determine the response. URLs that match no routes are handled as simple file requests.

Routes use [Lua patterns](https://www.lua.org/pil/20.2.html), and any [captures](https://www.lua.org/pil/20.3.html) are passed as parameters to the route handler function.

An example route is `/players/(%d+)`. This would match a URL like `/players/3`. If you wanted the name of the player on the server with the specified ID number to be the response, you could use a handler like this:

```lua
routes = {
	["/players/(%d+)"] = function(req, res, helpers, player)
		if GetPlayerEndpoint(player) then
			res.send(GetPlayerName(player))
		else
			res.sendError(404)
		end
	end
}
```

The `req`, `res`, and `helpers` arguments provide the interface for getting data from clients and sending data back to clients.

### `req`

The incoming request from the client.

#### `req.path`

The raw path of the request.

#### `req.url`

The parsed URL, containing the normalized path (`url.path`) and query parameters (`url.query`).

#### `req.method`

The HTTP method of the request.

#### `req.headers`

The HTTP headers of the request.

### `res`

The response that will be sent back to the client.

#### `res.writeHead(code, [headers])`

Sets the HTTP status code and other headers of the response.

#### `res.write(data)`

Writes data to the body of the response without closing it.

#### `res.send(data)`

Writes data to the body of the response and closes it. No arguments will close the response without sending any additional data.

#### `res.sendError(code, [headers])`

Sends an error page as the response.

#### `res.sendFile(path)`

Sends a file as the response.

#### `res.sendJson(data, [code, [headers]])`

Sends JSON data as the response. If `data` is a string, it is sent as-is. If `data` is not a string, it is encoded to a string with `json.encode`.

### `helpers`

Other helper functions.

#### `helpers.log(entry)`

Add an entry to the log. `entry` is a table that can contain any fields.
