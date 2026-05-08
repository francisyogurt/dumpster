type Cleanup<T> = (...T) -> ()
export type Object = {
	Add: <T>(self: Object, instance: T) -> T,
	Cleanup: (self: Object) -> (),
	Connect: (
		self: Object, 
		signal: RBXScriptSignal | SignalConnection,
		callback: () -> ()
	) -> (),
	Construct: <T>(self: Object, source: { new: () -> T } | () -> T, ...T) -> T,
	Extend: (self: Object) -> Object,
	WrapClean: <T>(self: Object) -> Cleanup<T>,

	Destroy: (self: Object) -> ()
}

type SignalConnection = {
	Disconnect: (self: SignalConnection) -> (),
	Destroy: (self: SignalConnection) -> (),
	Connected: boolean,
}

local function differentiate_type<T>(object: T): Cleanup<T>
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
	local self = {} :: Object
	
	local _cleaning = false
	local _objects: {[any]: Cleanup<any>} = {}

	function self.Add<T>(self: Object, instance: T): T
		_objects[instance] = differentiate_type(instance)
		return instance
	end

	function self.Cleanup(self: Object)
		if _cleaning then return end
		_cleaning = true

		for instance, cleanup in _objects do
			cleanup(instance)
		end
		table.clear(_objects)

		_cleaning = false
	end

	function self.Construct<T>(
		self: Object, 
		source: { new: () -> T } | () -> T, ...: T
	): T
		local instance: T
		if typeof(source) == "table" then
			instance = (source :: { new: () -> T }).new(...)
		else
			instance = (source :: () -> T)(...)
		end
		return self.Add(self, instance)
	end

	function self.Extend(self: Object): Object
		return self.Add(self, new())
	end

	function self.WrapClean<T>(self: Object): Cleanup<T>
		return function() self.Cleanup(self) end
	end

	function self.Connect(
		self: Object, 
		signal: RBXScriptSignal | SignalConnection,
		callback: () -> ()
	)
		self.Add(self, signal:Connect(callback))
	end

	function self.Destroy(self: Object)
		self.Cleanup(self)
	end
	
	return self
end

return {
	new = new
}
