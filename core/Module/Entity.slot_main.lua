local p = {} --p stands for package
local mwjson = require('Module:MwJson')

function p.process(frame, mode, title)
	local msg = "Debug Output: <br>" --debug msg

	local res = ""
	if title == nil then title = mw.title.getCurrentTitle().fullText end
	local namespace = mwjson.splitString(title, ':')[1]
	
	local jsondata_res = mwjson.loadJson({title=title, slot=mwjson.slots.jsondata})
	local jsondata = jsondata_res.json
	local debug = mwjson.defaultArg(jsondata[mwjson.keys.debug], false)
	msg = msg .. jsondata_res.debug_msg
	
	local process_res = nil
	if (namespace == "Category") then
		if (mode == "header") then process_res = mwjson.processJsondata({frame=frame, jsondata=jsondata, mode=mwjson.mode.header, categories={"Category:Category"}, recursive=true, debug=debug}) end
		if (mode == "footer") then process_res = mwjson.processJsondata({frame=frame, jsondata=jsondata, mode=mwjson.mode.footer, categories={"Category:Category"}, recursive=true, debug=debug}) end
		--mw.smw.set( {["IsA"]="Category:Category"}) --Todo: use type / HasType ?
	else
		if (mode == "header") then process_res = mwjson.processJsondata({frame=frame, jsondata=jsondata, mode=mwjson.mode.header, debug=debug}) end
		if (mode == "footer") then process_res = mwjson.processJsondata({frame=frame, jsondata=jsondata, mode=mwjson.mode.footer, debug=debug}) end
	end
	
	res = res .. process_res.wikitext
	msg = msg .. process_res.debug_msg

	if (debug) then res = msg .. res  end
	--if (debug) then mw.log(msg) end
	--mw.logObject(res)
	return res
end

function p.header(frame, title)
	return p.process(frame, "header", title)
end

function p.footer(frame, title)
	return p.process(frame, "footer", title)
end

--test: mw.logObject(p.query(mw.getCurrentFrame(), '{"category":"Category:Hardware","manufacturer":"TestM"}'))
function p.query(frame, jsondata_str)
	if (jsondata_str == nil) then jsondata_str = frame.args['jsondata'] end
	--local res = mwjson.processJsondata({frame=frame, jsondata=mw.text.jsonDecode(jsondata_str), mode=mwjson.mode.query}).wikitext
	return jsondata_str --.. "<br>" .. res
end

return p

--DEBUG (direct invoke)
--[[
frame = mw.getCurrentFrame() -- Get a frame object
title="Item:OSL7d7193567ea14e4e89b74de88983b718"
newFrame = frame:newChild{ title=title, args = {}}
mw.log(p.header( newFrame, title ) ) 
--]]