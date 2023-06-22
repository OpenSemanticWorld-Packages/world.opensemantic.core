local p = {} --p stands for package

p.file_type_mapping = {
	["py"] = "python",
	["json"] = "json",
	["md"] = "markdown",
	["yml"] = "yaml",
	["yaml"] = "yaml",
}

function p.code(frame)
	local url = frame.args['url']
	local lang = frame.args['lang']
	if (lang == "") then lang = nil end
	local show_line_numbers = frame.args['show_line_numbers']
	if (show_line_numbers == nil or show_line_numbers == "" or show_line_numbers == "0" or show_line_numbers == "false") then show_line_numbers = false
	else show_line_numbers = true end
	local highlight = frame.args['highlight']
	local render_markdown = frame.args['render_markdown']
	if (render_markdown == nil or render_markdown == "") then render_markdown = true end
	if (render_markdown == "0" or render_markdown == "false") then render_markdown = false end

	local url_parts = p.splitString(url, "#")
	mw.logObject(url_parts)
	local base_url = url_parts[1]
	local anchor = url_parts[2]
	local start_line = frame.args['start_line']
	local end_line = frame.args['end_line']
	if ((start_line == nil or start_line == "") and anchor ~= nil) then start_line =  p.splitString(p.splitString(p.splitString(anchor, "-")[1], "L")[1], "C")[1] end -- '#L65C1-L80C10' => 65
	if ((end_line == nil or end_line == "") and anchor ~= nil) then 
		end_line =  p.splitString(anchor, "-")[2]
		if (end_line ~= nil) then end_line =  p.splitString(p.splitString(end_line, "L")[1], "C")[1] end -- '#L65C1-L80C10' => 10
	end
	mw.logObject(start_line)
	mw.logObject(end_line)
	local path_parts = p.splitString(base_url, "/")
	local protocol = path_parts[1]
	local domain = path_parts[2]
	local org = path_parts[3]
	local repo = path_parts[4]
	local blob = path_parts[5] 
	local ref = path_parts[6] -- branch or commit
	local file_path =  "" --p.splitString(base_url, "ref")[2]
	for i = 7, #path_parts do file_path = file_path .. "/" .. (path_parts[i]) end
	local file_path_parts = p.splitString(file_path, ".")
	local file_type = file_path_parts[#file_path_parts]
	mw.logObject(path_parts)
	mw.logObject(file_path)
	mw.logObject(file_path_parts)
	local raw_url = "https://raw.githubusercontent.com/" .. org .. "/" .. repo .. "/" .. ref .. file_path
	mw.logObject(raw_url)
	--https://raw.githubusercontent.com/OpenSemanticLab/osw-python/b83d590553231dcc74d849af7f40239ef43546e0/src/osw/core.py
	local params = {}
	params["url"] = raw_url
	params["format"] = "text"
	if (start_line ~= nil) then params["start line"] = start_line end
	if (end_line ~= nil) then params["end line"] = end_line end
	res = mw.ext.externalData.getWebData(params)
	mw.logObject(res["__text"])
	
	if (lang == nil) then lang = p.file_type_mapping[file_type] end
	if (lang == nil) then lang = "text" end
	
	local wikitext = ""
	
	if (lang == "markdown" and render_markdown) then
		-- https://www.mediawiki.org/wiki/Extension:WikiMarkdown
		wikitext = frame:extensionTag{ name = "markdown" , content = res["__text"] }
	else
		local hl_params = {}
		hl_params["lang"] = lang
		-- extract line numbers from url
		if (start_line ~= nil and start_line ~= "") then hl_params["start"] = start_line end
		if (show_line_numbers) then hl_params["line"] = "1" end
		if (highlight ~= nil and highlight ~= "") then 
			if (start_line ~= nil and start_line ~= "") then
				local highlight_with_offset =""
				local offset = tonumber(start_line) - 1
				d='(%D-)'
				for k,i,j in highlight:gmatch(d..'(%d+)'..d) do highlight_with_offset = highlight_with_offset .. k .. i-offset .. j end
				hl_params["highlight"] = highlight_with_offset 
			else
				hl_params["highlight"] = highlight
			end
		end
		mw.logObject(hl_params)
		-- https://www.mediawiki.org/wiki/Extension:SyntaxHighlight
		wikitext = frame:extensionTag{ name = "syntaxhighlight" , content = res["__text"], args = hl_params }
	end
	
	mw.logObject(wikitext)
	return wikitext
end

function p.test()
	d='(%D-)'
	s = "1,2,3-5"
	res = ""
	for k,i,j in s:gmatch(d..'(%d+)'..d) do res = res .. k .. i+1 .. j
	end
	mw.logObject(res)
	--mw.logObject(names)
end

function p.splitString(inputstr, sep)
	
        if sep == nil then
                sep = ";"
        end
        local t={}
        for str in string.gmatch(inputstr, "([^"..sep.."]+)") do
                table.insert(t, str)
        end
        return t
end

return p

--DEBUG (direct invoke)
--[[
frame = mw.getCurrentFrame() -- Get a frame object
url = "https://github.com/OpenSemanticLab/osw-python/blob/b83d590553231dcc74d849af7f40239ef43546e0/src/osw/core.py#L49-L61"
newFrame = frame:newChild{ args = {url=url}}
mw.log(p.code( newFrame ) ) 
--]]