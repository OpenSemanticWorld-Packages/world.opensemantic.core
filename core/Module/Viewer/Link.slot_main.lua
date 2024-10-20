
local p = {} --p stands for package

function p.render(frame)
	if (frame.args['page'] == nil and frame.args['url'] == nil) then frame = frame:getParent() end
	local page = frame.args['page']
	local url = frame.args['url']
	local label = frame.args['label']
	local wikitext = ""
	if page ~= nil and page ~= "" then
		page = string.gsub(page, "Category:", ":Category:")
		if label == nil or label == "" then
			label = nil
			local pref_lang = frame.args['pref_lang']
			if pref_lang == nil then pref_lang = frame:preprocess( "{{USERLANGUAGECODE}}" ) end
			local query = "[[" .. page .. "]]|?HasLabel=label_pref_lang|+lang=" .. pref_lang .. "|?HasLabel=label_lang_en|+lang=en|?HasLabel#-=label_lang_any|?HasName=name|?Display_title_of=displaytitle|mainlabel=-"
			local result = mw.smw.ask( query )
			mw.logObject(result)
			if result ~= nil and result[1] ~= nil then
				label = result[1]['label_pref_lang']
				if label == nil then label = result[1]['label_lang_en'] end
				if label == nil then label = result[1]['label_lang_any'] end
				if label == nil then label = result[1]['displaytitle'] end
				if label == nil then label = result[1]['name'] end
				if type(label) == 'table' then label = label[1] end
				--mw.logObject(result)
				--result = result[1]['predecessor']
				--mw.logObject(result)
			end
		end
		page = string.gsub(page, "File:", "Media:")
		wikitext = "[[" .. page
		if label ~= nil then wikitext = wikitext .. "|" .. label end 
		wikitext = wikitext .. "]]"
	end
	if url ~= nil and url ~= "" then
		if label == nil then label = url end
		wikitext = "[" .. url .. " " .. label .. "]"
	end
	wikitext = frame:preprocess( wikitext )
	
	return wikitext
end

function p.debug()
	frame = mw.getCurrentFrame() -- Get a frame object
	newFrame = frame:newChild{ title=title, args = {page="Category:Entity", xpref_lang="de"}}
	mw.logObject(p.render( newFrame ) ) 
end

return p