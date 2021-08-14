local resourceName = GetCurrentResourceName()
local resourcePath = GetResourcePath(resourceName)

local blockSize = 8192

SetHttpHandler(function(req, res)
	local url = Url.normalize(req.path)

	if url.path:sub(-1) == "/" then
		url.path = url.path .. "index.html"
	end

	local relativePath = "files" .. url.path
	local absolutePath = resourcePath .. "/" .. relativePath

	local mimeType = PureMagic.via_path(absolutePath)

	local f = io.open(absolutePath, "rb")

	if f then
		local startBytes, endBytes

		if req.headers.Range then
			local s, e = req.headers.Range:match("^bytes=(%d+)-(%d+)$")
			startBytes = tonumber(s)
			endBytes = tonumber(e)
		end

		if not startBytes then
			startBytes = 0
		end

		local fileSize = f:seek("end")
		f:seek("set", startBytes)

		if not endBytes then
			endBytes = fileSize - 1
		end

		local headers = {
			["Content-Type"] = mimeType,
			["Transfer-Encoding"] = "identity",
			["Accept-Ranges"] = "bytes"
		}

		if req.headers.Range then
			headers["Content-Range"] = ("bytes %d-%d/%d"):format(startBytes, endBytes, fileSize)
			headers["Content-Length"] = tostring(endBytes - startBytes + 1)

			res.writeHead(206, headers)
		else
			headers["Content-Length"] = tostring(fileSize)

			res.writeHead(200, headers)
		end

		if req.method ~= "HEAD" then
			while true do
				local block = f:read(blockSize)
				if not block then break end
				res.write(block)
			end
		end

		res.send()

		f:close()
	else
		res.writeHead(404)
		res.send("Not found: " .. req.path)
	end
end)
