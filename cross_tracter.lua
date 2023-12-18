local skynet = require "skynet"
local skynet_send = skynet.send
local skynet_call = skynet.call
local skynet_dispatch = skynet.dispatch

local function pairsForLocalvalue(fun)
	local id = 0
	local nextF = function ()
		id = id + 1
		local ln, lv = debug.getlocal(fun, id)
		return ln, lv
	end
	return nextF
end 

local function getUpvalue(func, upvalueName)
    local i = 1
    while true do
        local name, value = debug.getupvalue(func, i)
        if not name then break end
        if name == upvalueName then
        return value
        end
        i = i + 1
    end
    return nil
end

local function tracebacks(startIndex)
	startIndex= startIndex or 3
	local ret = {"\n"}
	repeat
		local stackInfo = debug.getinfo(startIndex)
		if stackInfo then
			local funcInfo = debug.getinfo(stackInfo.func)
			local currentline = stackInfo.currentline
			local flag = "    [" .. tostring(funcInfo.what) .. "]"
			if currentline < 0 then
				flag = flag .. tostring(funcInfo.source) .. ":" .. tostring(funcInfo.linedefined) .. "->" .. tostring(funcInfo.lastlinedefined)
			else
				flag = flag .. tostring(funcInfo.source) .. ":" .. tostring(currentline)
			end
			if stackInfo.name then
				flag = flag .. " in function:".. stackInfo.name
			end
			if stackInfo.istailcall then
				flag = flag .. "\n"
				flag = flag .. "    tail call"
			end
			ret[#ret+1] = flag
		end
		startIndex = startIndex + 1
	until not stackInfo
	return table.concat(ret, "\n")
end

local function dispatcher_traceback(session, source, arList, typename, ...)
	local arLists = skynet.tracebackStrCache[source] and skynet.tracebackStrCache[source].arLists or {}
	arLists[#arLists + 1] = arList
	skynet.tracebackStrCache[source] = {
		arLists = arLists,
		typename = typename,
		session = session,
		source = source,
		argv = {...}
	}
end

local function make_ar_list(startIndex)
	startIndex = startIndex or 3
	local ret = {}
	repeat
		local stackInfo = debug.getinfo(startIndex)
		if stackInfo then
			local funcInfo = debug.getinfo(stackInfo.func)
			funcInfo.func = nil
			ret[#ret + 1] = {
				funcInfo = funcInfo,
				currentline = stackInfo.currentline,
				name = stackInfo.name,
				istailcall = stackInfo.istailcall,
			}
		end
		startIndex = startIndex + 1
	until not stackInfo
	return ret
end

local function print_ar_lists(arlists)
	local ret = {}
	arlists[#arlists + 1] = make_ar_list()
	for i = #arlists, 1, -1 do
		local arlist = arlists[i]
		for _, ar in ipairs(arlist) do
			local funcInfo = ar.funcInfo
			local currentline = ar.currentline
			local flag = "    [" .. tostring(funcInfo.what) .. "]"
			if currentline < 0 then
				flag = flag .. tostring(funcInfo.source) .. ":" .. tostring(funcInfo.linedefined) .. "->" .. tostring(funcInfo.lastlinedefined)
			else
				flag = flag .. tostring(funcInfo.source) .. ":" .. tostring(currentline)
			end
			if ar.name then
				flag = flag .. " in function:".. ar.name
			end
			if ar.istailcall then
				flag = flag .. "\n"
				flag = flag .. "    tail call"
			end
			ret[#ret+1] = flag
		end
	end

	return table.concat(ret, "\n")
end

return function ()
	skynet.PTYPE_TRACEBACK = 14	--协议号
	skynet.tracebackStrCache = {}
	skynet.register_protocol {
		name = "traceback",
		id = skynet.PTYPE_TRACEBACK,
		pack = skynet.pack,
		unpack = skynet.unpack,
		dispatch = dispatcher_traceback,
	}
	
	skynet.send = function(addr, id, ...)
		local protos = getUpvalue(skynet.register_protocol, "proto")
		local p = protos[id]
		if type(p) == "table" and p.name ~= "traceback" then
			if p.name == "snax" or p.name == "lua" then
				skynet_send(addr, "traceback", make_ar_list(), p.name)
			end
		end
		return skynet_send(addr, id, ...)
	end
	
	skynet.call = function(addr, id, ...)
		local protos = getUpvalue(skynet.register_protocol, "proto")
		local p = protos[id]
		if type(p) == "table" and p.name ~= "traceback" then
			if p.name == "snax" or p.name == "lua" then
				skynet_send(addr, "traceback", make_ar_list(), p.name)
			end
		end
		return skynet_call(addr, id, ...)
	end
	
	skynet.dispatch = function(typeName, func)
		local newFunc = function(session, source, cmd, ...)
			local __debugInfo___
			if skynet.tracebackStrCache[source] and 
			   skynet.tracebackStrCache[source].typename == typeName
			then
				__debugInfo___ = skynet.tracebackStrCache[source]
				skynet.tracebackStrCache[source] = nil
			end
			func(session, source, cmd, ...)
		end
		skynet_dispatch(typeName, newFunc)
	end
	
	--- 直接打印跨服堆栈
	skynet.printCrossTrace = function()
		local index = 1
		while true do
		  local key, value = debug.getlocal(4, index)
		  if key == nil then
			break
		  end
		  if key == "__debugInfo___" then
			skynet.error("\r\n"..print_ar_lists(value.arLists))
			return
		  end
		  index = index + 1
		end
	end

	--- 直接打印跨服堆栈
	skynet.getCrossTrace = function()
		local index = 1
		while true do
		  local key, value = debug.getlocal(4, index)
		  if key == nil then
			break
		  end
		  if key == "__debugInfo___" then
			return print_ar_lists(value.arLists)
		  end
		  index = index + 1
		end
	end

	--- 返回跨服的栈帧列表，方便调试用
	skynet.getCrossArLists = function()
		local index = 1
		while true do
		  local key, value = debug.getlocal(4, index)
		  if key == nil then
			break
		  end
		  if key == "__debugInfo___" then
			return value.arLists
		  end
		  index = index + 1
		end
	end
end