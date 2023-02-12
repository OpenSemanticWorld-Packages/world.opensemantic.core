local lustache = require("Module:Lustache")

local p = {} --p stands for package

p.keys = { --jsonschema / json-ld keys
	category='type', 
	subcategory='subclass_of',
	property_ns_prefix='Property',
	schema='osl_schema', 
	template='eval_template',
	mode='mode',
	context='@context',
	allOf='allOf',
	label='label',
	name='name',
	description='description',
	text='text',
	debug='_debug'
} 
p.slots = { --slot names
	jsondata='jsondata', 
	jsonschema='jsonschema', 
	header_template='header_template',
	footer_template='footer_template',
	data_template='data_template'
} 
p.mode = {
	header='header',
	footer='footer',
	query='query'
}

--loads json from a wiki page
--test: mw.logObject(p.loadJson({title="JsonSchema:Entity"}))
--test: mw.logObject(p.loadJson({title="Category:Entity", slot="jsonschema"}))
function p.loadJson(args)
	local page_title = p.defaultArg(args.title, "JsonSchema:Entity") --for testing
	local slot = p.defaultArg(args.slot, nil)
	local debug = p.defaultArg(args.debug, nil)
	local msg = ""
	
	local json = {}
	
	if (slot == nil) then
		--json = mw.loadJsonData( "JsonSchema:Entity" ) --requires MediaWiki 1.39
		local page = mw.title.makeTitle(p.splitString(page_title, ':')[1], p.splitString(page_title, ':')[2])
		local text = page:getContent()
		if (text ~= nil) then json = mw.text.jsonDecode(text) end
	else
		if (debug) then msg = msg .. "Fetch slot " .. p.slots.jsondata .. " from page " .. title .. "<br>" end
		local text = mw.slots.slotContent( slot , page_title )
		if (text ~= nil) then json = mw.text.jsonDecode(text) end
	end	
	
	--mw.logObject(json)

	return {json=json, debug_msg=msg}
end

-- test: mw.logObject(p.walkJsonSchema({jsonschema=p.loadJson({title="Category:Hardware", slot="jsonschema"}).json, debug=true}).jsonschema)
function p.walkJsonSchema(args)
	local jsonschema = p.defaultArg(args.jsonschema, {})
	local jsonschemas = p.defaultArg(args.jsonschemas, {})
	local categories = p.defaultArg(args.categories, nil)
	local visited = p.defaultArg(args.visited, {})
	local mode = p.defaultArg(args.mode, p.mode.header)
	--local merged_jsonschema = p.defaultArg(args.merged_jsonschema, {})
	local templates = p.defaultArg(args.templates, {})
	local recursive = p.defaultArg(args.recursive, true)
	local root = p.defaultArg(args.root, true)
	local debug = p.defaultArg(args.debug, false)
	local msg = ""
	local wikitext = ""
	
	local category_template_slot = nil
	if (mode == p.mode.footer) then category_template_slot = p.slots.footer_template end
	if (mode == p.mode.header) then category_template_slot = p.slots.header_template end
	
	if (categories == nil) then categories = p.getCategories({jsonschema=jsonschema, includeNamespace=true}).categories end
	if (type(categories) ~= 'table') then categories = {categories} end
	if (debug) then msg = msg .. "Supercategories: " .. mw.dumpObject(categories) .. "\n<br>" end
	for k, category in pairs(categories) do
		if (not p.tableContains(visited, category)) then
			--mw.logObject("Visit " .. category)
			if (debug) then msg = msg .. "Fetch slot " .. p.slots.jsonschema .. " from page " .. category .. "\n<br>" end
			local super_jsonschema_str = mw.slots.slotContent( p.slots.jsonschema , category )
			if (super_jsonschema_str ~= nil) then
				super_jsonschema = mw.text.jsonDecode( super_jsonschema_str )
				if (recursive) then	
					local res = p.walkJsonSchema({jsonschema=super_jsonschema, jsonschemas=jsonschemas, templates=templates, mode=mode, visited=visited, root=false})
					wikitext = wikitext .. res.wikitext 
				end
				--table.insert(jsonschemas, mw.text.jsonDecode( super_jsonschema_str )) --keep a copy of the schema, super_jsonschema passed by references gets modified
				--table.insert(jsonschemas, super_jsonschema ) 
				--mw.logObject("Store " .. category)
				table.insert(visited, category)
				jsonschemas[category] = mw.text.jsonDecode( super_jsonschema_str ) --keep a copy of the schema, super_jsonschema passed by references gets modified
				--jsonschema = p.tableMerge(jsonschema, super_jsonschema) --merge superschema is done by the caller
			end
			
			if (debug) then msg = msg .. "Fetch slot " .. category_template_slot .. " from page " .. category .. "\n<br>" end
			templates[category] = mw.slots.slotContent( category_template_slot , category )
		end
	end	
	if (root) then
		jsonschema = {}
		for i, category in ipairs(visited) do
			jsonschema = p.tableMerge(jsonschema, jsonschemas[category]) --merge all schemas
		end	
	end
	if (debug) then wikitext = msg .. wikitext  end
	return {jsonschema=jsonschema, jsonschemas=jsonschemas, templates=templates, visited=visited, wikitext=wikitext}
end

--[[ test: 
category = "Category:Hardware"
page = "Item:OSW7d7193567ea14e4e89b74de88983b718"
category2 = "Category:OSW80e240a2e17d4ae5adfe6419051aa0bb"
page2 = "Item:OSWa4da6664aeac466a86b09e6b32a1cb41"
mw.logObject(p.expandEmbeddedTemplates({
	jsonschema=p.walkJsonSchema({jsonschema=p.loadJson({title=category, slot="jsonschema"}).json, debug=true}).jsonschema, 
	jsondata=p.loadJson({title=page, slot="jsondata"}).json,
	debug=true, mode="render"
}).res)
--]]
function p.expandEmbeddedTemplates(args)
	local frame = p.defaultArg(args.frame, mw.getCurrentFrame())
	local jsondata = p.defaultArg(args.jsondata, {})
	local jsonschema = p.defaultArg(args.jsonschema, {})
	local template = p.defaultArg(args.template, nil)
	local mode = p.defaultArg(args.mode, nil)
	local stringify_arrays = p.defaultArg(args.stringify_arrays, false)
	local msg = ""
	local res = p.defaultArg(args.jsondata, "")
	
	for k,v in pairs(jsondata) do
		local eval_template = nil
		local eval_templates = p.defaultArgPath(jsonschema, {"properties", k, p.keys.template}, {})
		if (eval_templates[1] == nil) then eval_templates = {eval_templates} end --ensure list of objects
		for i, t in pairs(eval_templates) do
			if (t[p.keys.mode] ~= nil and t[p.keys.mode] == mode) then eval_template = t --use only render templates in render mode and store templates in store mode
			elseif (t[p.keys.mode] == nil) then  eval_template = t --default
			elseif (debug) then msg = msg .. "Ignore eval_template" .. mw.dumpObject( t ) .. "\n<br>"
			end
		end

		if (eval_template ~= nil and eval_template.value ~= nil and (eval_template.type == "mustache" or eval_template.type == "mustache-wikitext")) then
			-- mustache can handle objects and array to we can parse it directly
			-- todo: handle nested templates
			if (debug) then msg = msg .. "Parse mustache template " .. eval_template.value .. " with params " .. mw.dumpObject( {[k]=v} ) .. "\n<br>" end
			jsondata[k] = lustache:render(eval_template.value, {[k]=v})
			if (eval_template.type == "mustache-wikitext") then 
				jsondata[k] = frame:preprocess( jsondata[k] )
			end
		elseif type(v) == 'table' then 
			if (v[1] == nil) then --key value array = object/dict
				local sub_res = p.expandEmbeddedTemplates({frame=frame, jsondata=v, template=eval_template, mode=mode, stringify_arrays=stringify_arrays})
				msg = msg .. sub_res.debug_msg
				jsondata[k] = sub_res.res
				--if (sub_res.unparsed ~= nil) then jsondata[k] = sub_res.unparsed else jsondata[k] = sub_res.wikitext end
			else --list array
				local string_list = ""
				for i,e in pairs(v) do 
					if type(e) == 'table' then 	
						local eval_template = nil
						local eval_templates = p.defaultArgPath(jsonschema, {"properties", k, "items", p.keys.template}, {})
						if (eval_templates[1] == nil) then eval_templates = {eval_templates} end --ensure list of objects
						for i, t in pairs(eval_templates) do
							if (t[p.keys.mode] ~= nil and t[p.keys.mode] == mode) then eval_template = t --use only render templates in render mode and store templates in store mode
							elseif (t[p.keys.mode] == nil) then  eval_template = t --default
							elseif (debug) then msg = msg .. "Ignore eval_template" .. mw.dumpObject( t ) .. "\n<br>"
							end
						end
						local sub_res = p.expandEmbeddedTemplates({frame=frame, jsondata=e, template=eval_template, mode=mode, stringify_arrays=stringify_arrays})
						msg = msg .. sub_res.debug_msg
						if (type(sub_res.res) == 'table') then 
							if (debug) then msg = msg .. "Values for " .. k .. " contains non-literal items: " .. mw.dumpObject( sub_res.res ) .. " => skip value in wikitemplate array param creation\n<br>" end
						else 
							if (stringify_arrays) then string_list = string_list .. sub_res.res .. ";" 
							else v[i] = sub_res.res end
						end
					else
						if (stringify_arrays) then string_list = string_list .. e .. ";" end
					end
				end
				if (stringify_arrays) then jsondata[k] = string_list end
			end
		end
	end	
	
	
	if (template == nil) then 
		local templates = jsondata[p.keys.template]
		if (templates == nil) then templates = p.defaultArg(jsonschema[p.keys.template], {}) end
		if (templates[1] == nil) then templates = {templates} end --ensure list of objects
		for i, t in pairs(templates) do
			if (t[p.keys.mode] ~= nil and t[p.keys.mode] == mode) then template = t --use only render templates in render mode and store templates in store mode
			elseif (t[p.keys.mode] == nil) then  template = t --default
			elseif (debug) then msg = msg .. "Ignore template" .. mw.dumpObject( t ) .. "\n<br>"
			end
		end
	end
	
	if template ~= nil then
		if (template.type == "wikitext") then
			for k,v in pairs(jsondata) do
				if type(v) == 'table' then 
					if (debug) then msg = msg .. "Values for " .. k .. " contains non-literals: " .. mw.dumpObject( v ) .. " => skip wikitemplate parsing\n<br>" end
					return {res=res, debug_msg=msg} 
				end --not supported
			end			
			if (template.value ~= nil) then
				if (debug) then msg = msg .. "Parse wikitemplate " .. template.value .. " with params " .. mw.dumpObject( jsondata ) .. "\n<br>" end
				local child = frame:newChild{args=jsondata}
				res = child:preprocess( template.value )
			elseif (template.page ~= nil) then
				if (debug) then msg = msg .. "Parse wikitemplate " .. template.page .. " with params " .. mw.dumpObject( jsondata ) .. "\n<br>" end
				res = frame:expandTemplate{ title = template.page, args = jsondata }
			end
			
		end
	end
	
	--if (debug) then mw.logObject(msg) end
	return {res=res, debug_msg=msg}
end

-- mw.logObject(p.processJsondata({jsondata=p.loadJson({title="Item:OSW7d7193567ea14e4e89b74de88983b718", slot="jsondata"}).json, debug=true, mode="header"}))
-- mw.logObject(p.processJsondata({jsondata=p.loadJson({title="Item:OSWa4da6664aeac466a86b09e6b32a1cb41", slot="jsondata"}).json, debug=true, mode="header"}))
-- mw.logObject(p.processJsondata({jsondata=p.loadJson({title="Category:OSWb3022bbf7e7146eb8e6f6e3264f50bbe", slot="jsondata"}).json, debug=true, mode="header", categories={"Category:Category"}}))
function p.processJsondata(args)
	local frame = p.defaultArg(args.frame, mw.getCurrentFrame())
	local jsondata = p.defaultArg(args.jsondata, {})
	local jsonschema = p.defaultArg(args.jsonschema, {})
	local template = p.defaultArg(args.template, nil)
	local categories = p.defaultArg(args.categories, nil)
	local recursive = p.defaultArg(args.recursive, true)
	local mode = p.defaultArg(args.mode, p.mode.header)
	local debug = p.defaultArg(args.debug, false)
	
	local wikitext = ""
	local msg = "" --debug msg

	if (p.nilOrEmpty(jsondata) or (p.nilOrEmpty(categories) and p.nilOrEmpty(jsonschema) and p.nilOrEmpty(jsondata[p.keys.category]))) then return {wikitext=wikitext, debug_msg=msg} end --nothing to do here
	--if (jsondata == nil or p.tableLength(jsondata) == 0 or (categories == nil and jsonschema == nil and jsondata[p.keys.category] == nil)) then return {wikitext=wikitext, debug_msg=msg} end --nothing to do here
	--jsonschema = p.defaultArg(jsonschema, {})
	--jsondata = p.defaultArg(jsondata, {})
	if (categories == nil) then categories = jsondata[p.keys.category] end
	
	local schema_res = p.walkJsonSchema({jsonschema=jsonschema, categories=categories, mode=mode, recursive=recursive, debug=debug})
	jsonschema = schema_res.jsonschema
	--mw.logObject(jsonschema)
	
	local display_label = p.defaultArgPath(jsondata, {p.keys.name}, "")
	if (display_label == "") then display_label = p.defaultArgPath(jsondata, {p.keys.label, 1, p.keys.text}, "") end
	
	local jsonld = p.copy(jsondata)
	local json_data_store = p.copy(jsondata)
	local json_data_render = p.copy(jsondata)
	json_res_store = p.expandEmbeddedTemplates({jsonschema=jsonschema, jsondata=json_data_store, mode='store'})
	msg = msg .. json_res_store.debug_msg
	--mw.log("JSONDATA STORE")
	--mw.logObject(json_res_store.res)
	
	local smw_res = nil
	if (mode == p.mode.header) then
		smw_res = p.getSemanticProperties({jsonschema=jsonschema, jsondata=json_res_store.res, store=false, debug=debug})
		jsonld["@context"] = smw_res.context
		jsonld['schema:name'] = p.defaultArgPath(jsonld, {p.keys.label, 1, p.keys.text}, jsonld['name']) --google does not support @value and @lang
		jsonld['schema:description'] = p.defaultArgPath(jsonld, {p.keys.description, 1, p.keys.text}, nil)
		for k, v in pairs(jsonld) do
			if (type(v) == "string") then
				local vpart = p.splitString(v, ':')
				if (vpart[1] == "File") then jsonld[k] = mw.getCurrentFrame():callParserFunction( 'filepath', { vpart[2] } ) end --google does not follow redirects via "File":"wiki:Special:Redirect/file/"
			end
		end
		wikitext = wikitext .. "<div class='jsonld-header' style='display:none' data-jsonld='" .. mw.text.jsonEncode( jsonld ) .. "'></div>"
	end
	
	local json_res = p.expandEmbeddedTemplates({jsonschema=jsonschema, jsondata=json_data_render, mode='render'})
	msg = msg .. json_res.debug_msg
	jsondata =json_res.res
	--mw.log("JSONDATA RENDER")
	--mw.logObject(jsondata)
	

	for i, category in ipairs(schema_res.visited) do
		local jsonschema = schema_res.jsonschemas[category]
		local template = schema_res.templates[category]
		if (template ~= nil) then
			if (debug) then msg = msg .. "Parse \n\n" .. template .. " \n\nwith params " .. mw.dumpObject( jsondata ) .. "\n<br>" end
			local stripped_jsondata={}
			for k, v in pairs(jsondata) do
				if (type(v) ~= 'table') then stripped_jsondata[k] = v end --delete object values, not supported by wiki templates	
			end
			local child = frame:newChild{args=stripped_jsondata}
			wikitext = wikitext .. child:preprocess( template )
		elseif (mode == p.mode.header) then
			local infobox_res = p.renderInfoBox({jsonschema=jsonschema, jsondata=jsondata})
			wikitext = wikitext .. frame:preprocess( infobox_res.wikitext )
		end
	end
	
	--local display_label = ""
	--if (jsondata[p.keys.label] ~= nil) then display_label = p.splitString(jsondata[p.keys.label], '@')[1] end
	wikitext = wikitext .. "\n" .. p.setCategories({categories=jsondata[p.keys.category], sortkey=display_label}).wikitext --items
	wikitext = wikitext .. p.setCategories({categories=jsondata[p.keys.subcategory], sortkey=display_label}).wikitext --classes/categories
	
	if (smw_res ~= nil) then
		if (debug) then msg = msg .. "Store page properties" end
		smw_res.properties['Display title of'] = display_label --set special property display title
		mw.ext.displaytitle.set(display_label)
		--smw_res.properties['@category'] = jsondata[p.keys.category]
		local store_res = mw.smw.set( smw_res.properties ) --store as semantic properties
		if (debug) then msg = msg .. mw.dumpObject(smw_res.properties) end
		if (store_res) then 
			if (debug) then msg = msg .. "SMW SUCCESS: " end
		else
			wikitext = wikitext .. store_res.error 
			if (debug) then msg = msg .. "SMW ERROR: " .. store_res.error end
		end
		--wikitext = mw.dumpObject(smw_res.properties) .. wikitext
	end
	
	if (debug) then mw.logObject(res) end
	return {wikitext=wikitext, debug_msg=msg}
end


-- renders a default infobox
-- test: mw.logObject(p.renderInfoBox({jsonschema=p.loadJson({title="JsonSchema:Entity"}).json, jsondata={uuid="123123"}}))
function p.renderInfoBox(args)
	local jsondata = p.defaultArg(args.jsondata, {})
	local schema = p.defaultArg(args.jsonschema, nil)
	local context = p.buildContext({jsonschema=schema}).context
	local res = ""
	if schema == nil then return res end
	local schema_label = ""
	if schema['title'] ~= nil then schema_label = schema['title'] end
	
	-- see also: https://help.fandom.com/wiki/Extension:Scribunto/HTML_Library_usage_notes
	local tbl = mw.html.create( 'table' )
	tbl
		:attr( 'class', 'info_box' )
		:tag( 'tr' )
			:tag( 'td' )
				:attr( 'class', 'subheading' )
				:attr( 'colspan', '2' )
				:wikitext( schema_label )
	for k,v in pairs(jsondata) do
		if (schema['properties'] ~= nil and schema['properties'][k] ~= nil and (type(v) ~= 'table' or v[1] ~= nil)) then --literal or literal array
			local def = schema['properties'][k]
			--mw.logObject(def)
			local label = k
			if def['title'] ~= nil then label = def['title'] end
			--res = res .. title ": " .. v
			local cell = tbl:tag( 'tr' )
								:tag( 'th' )
									:wikitext( label )
									:done()
								:tag( 'td' )
			if (type(v) == 'table') then
				for i,e in pairs(v) do 
					if (type(e) ~= 'table') then 
						local p_type = p.defaultArgPath(context, {k, '@type'}, '@value')
						if (p_type == '@id') then e = "[[" .. string.gsub(e, "Category:", ":Category:") .. "]]" end
						cell:wikitext("\n* " .. e .. "") 
					end
				end
			else
				local p_type = p.defaultArgPath(context, {k, '@type'}, '@value')
				if (p_type == '@id') then e = "[[" .. string.gsub(e, "Category:", ":Category:") .. "]]" end
				cell:wikitext( v )
			end
		end
	end	
	res = res .. tostring( tbl )
	--mw.logObject(res)
	
	return {wikitext=res}
end

-- test
-- mw.logObject(p.getCategories({jsonschema={allOf={["$ref"]="/wiki/Category:Test?action=raw&slot=jsonschema"}}, includeNamespace=true}))
-- mw.logObject(p.getCategories({jsonschema={allOf={{["$ref"]="/wiki/Category:Test?action=raw&slot=jsonschema"}, {["$ref"]="/wiki/Category:Test2?action=raw&slot=jsonschema"}}}}))
function p.getCategories(args)
	local jsonschema = p.defaultArg(args.jsonschema, {})
	local includeNamespace = p.defaultArg(args.includeNamespace, false)
	
	local categories = {}
		local allOf = jsonschema[p.keys.allOf]
		if (allOf ~= nil) then
			--properties['@category'] = {}
			for k, entry in pairs(allOf) do
				if type(entry) == 'table' then -- "allOf": [{"$ref": "/wiki/Category:Test?action=raw"}]
					for p, v in pairs(entry) do
						if (p == '$ref') then
							for category in v:gmatch("Category:([^?]+)") do -- e.g. "/wiki/Category:Test?action=raw"
								if (includeNamespace) then category = "Category:" .. category end
							    table.insert(categories, category)
							end
						end
					end
				else -- "allOf": {"$ref": "/wiki/Category:Test?action=raw"}
					if (k == '$ref') then
						for category in entry:gmatch("Category:([^?]+)") do -- e.g. "/wiki/Category:Test?action=raw"
							if (includeNamespace) then category = "Category:" .. category end
							table.insert(categories, category)
						end
					end	
				end
			end
		end	
		
	return {categories=categories}
end

--sets a list of categories on the page
--test: mw.logObject(p.setCategories({categories={"Cat1", "Category:Cat2"}}))
function p.setCategories(args)
	local categories = p.defaultArg(args.categories, {})
	local sortkey = p.defaultArg(args.sortkey, "")
	if (sortkey ~= "") then sortkey = "|" .. sortkey end
	if (type(categories) ~= 'table') then categories = {categories} end
	local res = ""
	for k, entry in pairs(categories) do
		res = res .. "[[Category:" .. string.gsub(entry, "Category:", "") .. sortkey .."]]"
	end
	return {wikitext=res}
end

--[[ test
category = "Category:Hardware"
category2 = "Category:OSW80e240a2e17d4ae5adfe6419051aa0bb"
jsonschema =p.walkJsonSchema({jsonschema=p.loadJson({title=category, slot="jsonschema"}).json, debug=true}).jsonschema
mw.logObject(p.buildContext({jsonschema=jsonschema, debug=true}))
--]]
function p.buildContext(args)
	local schema = p.defaultArg(args.jsonschema, {})
	local context = p.defaultArg(args.context, schema[p.keys.context])
	local result = {}
	if (context ~= nil) then
		for k,v in pairs(context) do
			if type(k) == 'number' and type(v) == 'string' then
				--table.insert(result, v) --skip context imports
			elseif (type(v) == 'table' and v[1] ~= nil) then --custom addtional mappings, e. g. "type*": ["Property:HasType"]
				result[k] = v
			elseif (type(v) == 'table' and v['@id'] == nil) then --subcontext
				p.tableMerge(result, p.buildContext({context=v}).context)
			else 
				result[k] = v	
			end
		end
	end
	return {context=result}
end

--maps jsondata values to semantic properties by using the @context attribute within the schema
--test: mw.logObject(p.getSemanticProperties({jsonschema={["@context"]={test="Property:TestProperty", myObjectProperty={["@id"]= "Property:MyObjectProperty", ["@type"]= "@id"}}}, jsondata={test="TestValue", myObjectProperty="123"}, debug=true}))
--test: mw.logObject(p.getSemanticProperties({jsonschema={["@context"]={"some uri",{test="Property:TestProperty", myObjectProperty={["@id"]= "Property:MyObjectProperty", ["@type"]= "@id"}}}}, jsondata={test="TestValue", myObjectProperty="123"}, debug=true}))
--[[
mw.logObject(p.getSemanticProperties({jsonschema={["@context"]={test="Property:TestProperty", subobject="Property:HasSubobject", myObjectProperty={["@id"]= "Property:MyObjectProperty", ["@type"]= "@id"}}}, jsondata={
test="TestValue", myObjectProperty="123", subobject={uuid="123-123-123", test="TestValue2"}
}, debug=true}))

mw.logObject(p.getSemanticProperties({jsonschema=p.loadJson({title="Category:OSW80e240a2e17d4ae5adfe6419051aa0bb", slot="jsonschema"}).json, p.loadJson({title="Item:OSWa4da6664aeac466a86b09e6b32a1cb41", slot="jsonsdata"}).json, debug=true}))

category = "Category:Hardware"
page = "Item:OSW7d7193567ea14e4e89b74de88983b718"
category2 = "Category:OSW80e240a2e17d4ae5adfe6419051aa0bb"
page2 = "Item:OSWa4da6664aeac466a86b09e6b32a1cb41"
jsonschema =p.walkJsonSchema({jsonschema=p.loadJson({title=category, slot="jsonschema"}).json, debug=true}).jsonschema
mw.logObject(p.getSemanticProperties({
	jsonschema=jsonschema,
	jsondata=p.expandEmbeddedTemplates({jsonschema=jsonschema, jsondata=p.loadJson({title=page, slot="jsondata"}).json}).res,
	debug=true
}).properties)

--]]
function p.getSemanticProperties(args)
	local jsondata = p.defaultArg(args.jsondata, {})
	local schema = p.defaultArg(args.jsonschema, {})
	local store = p.defaultArg(args.store, false)
	local root = p.defaultArg(args.root, true)
	local debug = p.defaultArg(args.debug, false)
	--if (debug) then mw.logObject("Call getSemanticProperties with args " .. mw.dumpObject( args ) .. "\n<br>") end
	
	local properties = {} --semantic properties
	local property_data = {}
	local context = p.defaultArg(args.context, p.buildContext({jsonschema=schema}).context) --ToDo: subcontext for specific properties
	local error = ""
	if (debug) then mw.logObject(context) end
	if schema ~= nil and context ~= nil then
		local schema_properties = p.defaultArg(schema.properties, {})
		if (debug and root) then
			for k,v in pairs(context) do
				if type(k) == 'number' then mw.logObject("imports " .. v)
				elseif type(v) == 'table' and v["@id"] ~= nil then mw.logObject("" .. k .. " maps to " .. v["@id"]) 
				else mw.logObject("" .. k .. " maps to " .. mw.dumpObject(v)) end
			end
		end
		for k,v in pairs(jsondata) do
			local property_names = {}
			local mapping_found = false
			local property_definitions = {}
			if (context[k] ~= nil) then --json-ld mapping
				if type(context[k]) == 'table' then table.insert(property_definitions, context[k]["@id"])
				else table.insert(property_definitions, context[k]) end
			end
			for term, def in pairs(context) do
				local term_parts = p.splitString(term, "*")
				if (string.find(term, "*", 0, true) and term_parts[1] == k) then --custom additional mapping term*(*...): "Property:..."
					table.insert(property_definitions, def)
				end
			end
			if (debug) then mw.logObject(property_definitions) end
			for i,e in ipairs(property_definitions) do 
				local property_definition = p.splitString(e, ':')
				if property_definition[1] == p.keys.property_ns_prefix then
					mapping_found = true
					table.insert(property_names, property_definition[2])
					local schema_property = p.defaultArg(schema_properties[k], {})
					local schema_type = p.defaultArg(schema_property.type, nil) --todo: also load smw property type on demand
					property_data[k] = {schema_type=schema_type, schema_data=schema_property, property=property_definition[2], value=v}
				end
			end
			for i, property_name in ipairs(property_names) do
				if (properties[property_name] == nil) then properties[property_name] = {} end --initialize empty list
			end
			if type(v) == 'table' then 
				--if (debug) then mw.logObject("prop " .. k .. " = " .. mw.dumpObject(v)) end
				if (mapping_found) then
					
					local values = {}
					if (v[1] == nil) then --key value array = object/dict
						local id = p.getSemanticProperties({jsonschema=schema, jsondata=v, store=true, root=false, debug=debug, context=context}).id --subobject_id
						if (id ~= nil) then 
							id = mw.title.getCurrentTitle().fullText .. '#' .. id
							table.insert(values, id) 
						end
					else --list array
						for i, e in pairs(v) do
							if (type(e) == 'table') then 
								local id = p.getSemanticProperties({jsonschema=schema, jsondata=e, store=true, root=false, debug=debug, context=context}).id --subobject_id
								if (id ~= nil) then 
									id = mw.title.getCurrentTitle().fullText .. '#' .. id
									table.insert(values, id) 
								end
							else values = v end --plain strings
						end
					end 
					for pi, property_name in ipairs(property_names) do
						for i,value in pairs(values) do table.insert(properties[property_name], value) end
						if (debug) then mw.logObject("set " .. property_name .. " = " .. mw.dumpObject(values)) end
					end
				else if (debug) then mw.logObject("not mapped: " .. k .. " = " .. mw.dumpObject(v)) end 
				end
			else
				if (mapping_found) then 
					for pi, property_name in ipairs(property_names) do
						table.insert(properties[property_name], v)
						if (debug) then mw.logObject("set " .. property_name .. " = " .. mw.dumpObject(v)) end
					end
				else 
					if (debug) then mw.logObject("not mapped: " .. k .. " = " .. mw.dumpObject(v)) end 
				end
			end
		end
	end
	
	local subobjectId = nil
	local store_res = nil
	if (store) then 
		if (root) then 
			if (debug) then mw.logObject("Store page properties") end
			store_res = mw.smw.set( properties ) --store as semantic properties
		else
			
			if jsondata['uuid'] ~= nil then subobjectId = "OSW" .. string.gsub(jsondata['uuid'], "-", "") end
			properties['@category'] = jsondata[p.keys.category]
			if (jsondata[p.keys.label] ~= nil) then properties['Display title of'] = p.splitString(jsondata[p.keys.label], '@')[1] end
			if (p.tableLength(properties) > 0) then
				store_res = mw.smw.subobject( properties, subobjectId )	--store as subobject
				if (debug) then mw.logObject("Store subobject with id " .. subobjectId) end
			end
		end
	end
	if (debug) then mw.logObject(properties) end
	if (store_res ~= nil) then 
		if (not store_res and store_res.error ~= nil) then error = error .. store_res.error end
	end
	if (debug) then mw.logObject(error) end
	return {properties=properties, definitions=property_data, id=subobjectId, context=context, error=error}
end

-- build a semantic query based on provided properties and their schema definition
--[[ test: 
mw.logObject(p.getSemanticQuery({
	jsonschema={
		["@context"]={
			test="Property:TestProperty",
			number_max="Property:HasNumber",
			date_min="Property:HasDate"
		}, 
		properties={
			test={title="Test", type="string"},
			number_max={title="Number", type="string", format="number", options={role={query={filter="max"}}}},
			date_min={title="Date", type="string", format="date", options={role={query={filter="min"}}}},
		}
	}, 
	jsondata={test="TestValue", number_max=5, date_min="01.01.2023"}
}))
--]]
function p.getSemanticQuery(args)
	--local jsondata = p.defaultArg(args.jsondata, {})
	--local schema = p.defaultArg(args.jsonschema, {})
	local res = ""
	local where = ""
	local select = ""
	local semantic_properties = p.getSemanticProperties(args)
	--mw.logObject(semantic_properties)
	for k,def in pairs(semantic_properties.definitions) do
		-- see also: https://www.semantic-mediawiki.org/wiki/Help:Search_operators
		local filter = p.defaultArgPath(def.schema_data, {'options', 'role', 'query', 'filter'}, 'eq')
		local value = def.value
		if def.schema_data.type == 'string' and (def.schema_data.format == 'number' or def.schema_data.format == 'date') then 
			if (filter == 'min') then value = "<" .. value
			elseif (filter == 'max') then value = ">" .. value
			else value = value end --exact match
		elseif def.schema_data.type == 'string' then
			value = "~*" .. value .. "*"
		end
		where = where .. "\n[[".. def.property .. "::" .. value .. "]]"
		select = select .. "\n|?" .. def.property
		if (def.schema_data.title ~= nil) then select = select .. "=" .. def.schema_data.title end
	end
	if (where ~= "") then res = "{{#ask:" .. res .. where .. select .. "}}" end
	return {wikitext=res}
end

-- HELPERS
function p.defaultArg(arg, default)
	if (arg == nil) then 
		return default
	else
		return arg
	end
end

-- returns the value of a table (dict) path or default, if the path is not defined
-- test: mw.logObject(p.defaultArgPath({some={defined={path="value"}}}, {"some", "defined", "path"}, "default_value"))
-- test: mw.logObject(p.defaultArgPath({some={defined={path="value"}}}, {"some", "undefined", "path"}, "default_value"))
function p.defaultArgPath(arg, path, default)
	if (arg == nil) then 
		return default
	elseif (path == nil) then
		return arg
	else
		key = table.remove(path,1)
		if (key == nil) then return arg end  --end of path
		return p.defaultArgPath(arg[key], path, default)
	end
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

--dumps a table to a string (replaced by mw.dumpObject())
function p.dump(o)
   return mw.dumpObject(o)
end

--true if the value is contained in the array (flat arrays only)
function p.tableContains (tab, val)
    for index, value in ipairs(tab) do
        if value == val then
            return true
        end
    end

    return false
end

--get the size of a table
function p.tableLength(t)
  local count = 0
  for _ in pairs(t) do count = count + 1 end
  return count
end

--check if a variable is nil or an empty string or table
function p.nilOrEmpty(o)
	if (o == nil) then return true
	elseif (type(o) == 'string' and o == "") then return true
	elseif (type(o) == 'table' and p.tableLength(o) == 0) then return true
	else return false 
	end
end

-- merges t2 to t1
--test: mw.logObject(p.tableMerge({"string", test1="test1", subtable1={"test"}}, {"string2", test1="test2", test3="test4"}))
function p.tableMerge(t1, t2)
    for k,v in pairs(t2) do
        if type(v) == "table" then
            if type(t1[k] or false) == "table" then
                p.tableMerge(t1[k] or {}, t2[k] or {})
            else
                if type(k) == 'number' then table.insert(t1, v)
            	else t1[k] = v end
            end
        else
        	if type(k) == 'number' then table.insert(t1, v)
            else t1[k] = v end
        end
    end
    return t1
end

-- from https://stackoverflow.com/questions/640642/how-do-you-copy-a-lua-table-by-value
function p.copy(obj, seen)
  if type(obj) ~= 'table' then return obj end
  if seen and seen[obj] then return seen[obj] end
  local s = seen or {}
  local res = setmetatable({}, getmetatable(obj))
  s[obj] = res
  for k, v in pairs(obj) do res[p.copy(k, s)] = p.copy(v, s) end
  return res
end

return p