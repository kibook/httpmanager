SetHttpHandler(function(req, res)
	local url = Url.normalize(req.path)

	if url.path == "/" then
		url.path = "/index.html"
	end

	local fileData = LoadResourceFile(GetCurrentResourceName(), "files" .. url.path)

	if fileData then
		res.send(fileData)
	else
		res.writeHead(404)
		res.send("Not found: " .. req.path)
	end
end)
