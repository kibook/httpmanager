SetHttpHandler(exports.httpmanager:createHttpHandler{
	routes = {
		["/multiply%-by%-two"] = function(req, res, helpers)
			req.readJson(function(data)
				res.sendJson{output = data.input * 2}
			end)
		end
	}
})
