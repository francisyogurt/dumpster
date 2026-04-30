type Cleanup<T> = (...T) -> ()
export type Object = {
	Add: <T>(self: Object, instance: T) -> (),
	Cleanup: (self: Object) -> (),
	Connect: (
		self: Object, 
		signal: RBXScriptSignal | SignalConnection,
		callback: () -> ()
	) -> (),
	Extend: (self: Object) -> Object,
	WrapClean: (self: Object) -> Cleanup,
	
	Destroy: (self: Object) -> ()
}

type SignalConnection = {
	Disconnect: (self: SignalConnection) -> (),
	Destroy: (self: SignalConnection) -> (),
	Connected: boolean,
}

local function differentiate_type<T>(object: T): Cleanup
	local type = typeof(object)
	local is_table = (type == "table")
	
	if (type == "Instance") or (is_table and object.Destroy) then
		return function() object:Destroy() end
	elseif (type == "RBXScriptConnection") or (is_table and object.Disconnect) then
		return function() object:Disconnect() end
	elseif (type == "function") then
		return function() object() end
	elseif (type == "thread") then
		return function() task.cancel(object) end
	end
end

local function new(): Object
	local _cleaning = false
	local _objects: {[any]: Cleanup} = {}
	
	local function add<T>(self: Object, instance: T): T
		_objects[instance] = differentiate_type(instance)
		return instance
	end
	
	local function cleanup(self: Object)
		if _cleaning then return end
		_cleaning = true
		
		for instance, cleanup in _objects do
			cleanup(instance)
		end
		table.clear(_objects)
		
		_cleaning = false
	end
	
	local function extend(self: Object): Object
		return add(self, new())
	end
	
	local function wrap_clean(self: Object)
		return function() cleanup(self) end
	end
	
	local function connect(
		self: Object, 
		signal: RBXScriptSignal | SignalConnection,
		callback: () -> ()
	)
		add(self, signal:Connect(callback))
	end
	
	local function destroy(self: Object)
		cleanup(self)
	end
	
	return {
		Add = add,
		
		Cleanup = cleanup,
		Connect = connect,
		
		Extend = extend,
		WrapClean = wrap_clean,
		
		Destroy = destroy
	}
end

return {
	new = new
}