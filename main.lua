SetHttpHandler(exports.httpmanager:createHttpHandler {
	routes = {
		["/password/generate%-hash"] = function(req, res, helpers)
			req.setDataHandler(function(body)
				local data = json.decode(body)

				if data and data.password then
					res.writeHead(200, {["Content-Type"] = "application/json"})
					res.send(json.encode{hash = hashPassword(data.password)})
				else
					res.sendError(400)
				end
			end)
		end
	}
})
