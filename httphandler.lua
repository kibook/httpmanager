local mainResourceName = GetCurrentResourceName()

-- Default options for new HTTP handlers
local defaultOptions = {
	documentRoot = "files",
	directoryIndex = "index.html",
	log = false,
	logFile = "log.json",
	errorPages = {},
	mimeTypes = {},
	routes = {}
}

-- The size of each block used when reading a file on disk
local blockSize = 131072

-- Maximum number of bytes to send in one response
local maxContentLength = 5242880

local function createHttpHandler(options)
	local resourceName = GetInvokingResource() or GetCurrentResourceName()
	local resourcePath = GetResourcePath(resourceName)

	if type(options) ~= "table" then
		options = {}
	end

	for key, defaultValue in pairs(defaultOptions) do
		if not options[key] then
			options[key] = defaultValue
		end
	end

	local handlerLog

	if options.log then
		handlerLog = json.decode(LoadResourceFile(resourceName, options.logFile)) or {}
	end

	local authorizations = {}

	local function getMimeType(path)
		local extension = path:match("^.+%.(.+)$")

		if options.mimeTypes[extension] then
			return options.mimeTypes[extension]
		elseif MimeTypes[extension] then
			return MimeTypes[extension]
		else
			return "application/octet-stream"
		end
	end

	local function sendError(res, code, extraHeaders)
		local headers = {["Content-Type"] = "text/html"}

		if extraHeaders then
			for h, v in pairs(extraHeaders) do
				headers[h] = v
			end
		end

		res.writeHead(code, headers)

		local resource, path

		if options.errorPages[code] then
			resource = resourceName
			path = options.documentRoot .. "/" .. options.errorPages[code]
		else
			resource = mainResourceName
			path = defaultOptions.documentRoot .. "/" .. code .. ".html"
		end

		local data = LoadResourceFile(resource, path)

		if data then
			res.send(data)
		else
			res.send("Error: " .. code)
		end
	end

	local function log(entry)
		if not handlerLog then
			return
		end

		entry.time = os.time()

		table.insert(handlerLog, entry)

		table.sort(handlerLog, function(a, b)
			return a.time < b.time
		end)

		SaveResourceFile(resourceName, options.logFile, json.encode(handlerLog), -1)
	end

	local function sendFile(req, res, path)
		local relativePath = options.documentRoot .. path
		local absolutePath = resourcePath .. "/" .. relativePath

		local mimeType = getMimeType(absolutePath)

		local f = io.open(absolutePath, "rb")

		local statusCode

		if f then
			local startBytes, endBytes

			if req.headers.Range then
				startBytes = tonumber(req.headers.Range:match("^bytes=(%d+)-.*$"))
				endBytes = tonumber(req.headers.Range:match("^bytes=%d+-(%d+)$"))
			end

			if not startBytes or startBytes < 0 then
				startBytes = 0
			end

			local fileSize = f:seek("end")
			f:seek("set", startBytes)

			if not endBytes then
				endBytes = math.min(startBytes + maxContentLength, fileSize) - 1
			end

			local headers = {
				["Content-Type"] = mimeType,
				["Transfer-Encoding"] = "identity",
				["Accept-Ranges"] = "bytes"
			}

			if endBytes < fileSize - 1 then
				statusCode = 206

				headers["Content-Range"] = ("bytes %d-%d/%d"):format(startBytes, endBytes, fileSize)
				headers["Content-Length"] = tostring(endBytes - startBytes + 1)
			else
				statusCode = 200

				headers["Content-Length"] = tostring(fileSize)
			end

			res.writeHead(statusCode, headers)

			Citizen.CreateThread(function()
				if req.method ~= "HEAD" then
					while true do
						if startBytes > endBytes then
							break
						end

						local block = f:read(blockSize)

						if not block then
							break
						end

						res.write(block)

						startBytes = startBytes + blockSize

						Citizen.Wait(0)
					end
				end

				res.send()

				f:close()
			end)
		else
			statusCode = 404

			sendError(res, statusCode)
		end

		log {
			type = "file",
			path = req.path,
			address = req.address,
			method = req.method,
			headers = req.headers,
			status = statusCode,
			file = absolutePath
		}

		return statusCode
	end

	local function isAuthorized(req)
		local auth = req.headers.Authorization

		if not auth then
			return false
		end

		if authorizations[auth] then
			return true
		end

		local encoded = auth:match("^Basic (.+)$")

		if not encoded then
			return false
		end

		local decoded = base64.decode(encoded)

		local username, password = decoded:match("^([^:]+):(.+)$")

		if not (username and password) then
			return false
		end

		if not verifyPassword(password, options.authorization[username]) then
			return false
		end

		authorizations[auth] = true

		return true
	end

	return function(req, res)
		if options.authorization and not isAuthorized(req) then
			sendError(res, 401, {
				["WWW-Authenticate"] = ("Basic realm=\"%s\""):format(resourceName)
			})
			return
		end

		local url = Url.normalize(req.path)

		for pattern, callback in pairs(options.routes) do
			local matches = {url.path:match(pattern)}

			if #matches > 0 then
				req.url = url

				res.sendError = function(code)
					sendError(res, code)
				end

				res.sendFile = function(path)
					sendFile(req, res, path)
				end

				local helpers = {
					log = function(entry)
						entry.type = "message"
						entry.route = pattern
						log(entry)
					end
				}

				callback(req, res, helpers, table.unpack(matches))

				log {
					type = "route",
					route = pattern,
					path = req.path,
					address = req.address,
					method = req.method,
					headers = req.headers,
				}

				return
			end
		end

		if options.documentRoot then
			if url.path:sub(-1) == "/" then
				url.path = url.path .. options.directoryIndex
			end

			sendFile(req, res, url.path)
		else
			sendError(res, 404)
		end
	end
end

exports("createHttpHandler", createHttpHandler)
