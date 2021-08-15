SetHttpHandler(exports.httpmanager:createHttpHandler {
	routes = {
		["/players/(.+)"] = function(req, res, helpers, player)
			if GetPlayerEndpoint(player) then
				res.send(GetPlayerName(player))
			else
				res.sendError(404)
			end
		end
	}
})
