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
		local fileSize = f:seek("end")
		f:seek("set", 0)

		res.writeHead(200, {
			["Content-Type"] = mimeType,
			["Content-Length"] = tostring(fileSize),
			["Transfer-Encoding"] = "identity",
			["Connection"] = "close"
		})

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
