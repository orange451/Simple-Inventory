--!strict

local module = {}

local HttpService = game:GetService("HttpService")

local ItemData = require("./ItemData")

local Signal = require("../Library/Signal")

module.ItemStackCache = {} :: {[string]: ItemStack}

export type ItemStack = {
	Type: string,
	Quantity: number,
	UUID: string,
	
	GetItemData: (self: ItemStack)->(ItemData.ItemData),
	
	ToBuffer: (self: ItemStack)->(buffer),
	
	Destroy: (self: ItemStack)->(),
	
	SetQuantity: (self: ItemStack, quantity: number) -> (),
	
	QuantityChanged: Signal.Signal<(quantity: number) -> (), number>,
}

local itemstack = {}

function module.new(item_type: string, quantity: number, uuid: string?) : ItemStack
	if ( uuid ) then
		local cached_item = module.ItemStackCache[uuid]
		if ( cached_item ) then
			return cached_item
		end
	end
	
	local self = {
		Type = item_type,
		
		Quantity = tonumber(quantity) or 1,
		QuantityChanged = Signal.new(),
		
		UUID = uuid or HttpService:GenerateGUID(true),
	} :: ItemStack
	
	local meta = {
		__tostring = function()
			return `ItemStack\{Type={item_type}, Quantity={self.Quantity}\}`
		end,
		
		__index = itemstack,
	}

	setmetatable(self :: any, meta)
	
	module.ItemStackCache[self.UUID] = self
	
	return self :: ItemStack
end

function itemstack.GetItemData(self: ItemStack)
	return ItemData.get(self.Type)
end

function itemstack.Destroy(self: ItemStack)
	if ( (self :: any).Destroyed ) then
		return
	end

	for k,_ in pairs(self) do
		self[k] = nil
	end

	(self :: any).Destroyed = true
end

function itemstack.SetQuantity(self: ItemStack, quantity: number)
	self.Quantity = quantity
	self.QuantityChanged:Fire(self.Quantity)
end

function itemstack.ToBuffer(self: ItemStack)
	local bin = {}

	-- Write UUID: length (uint32) + string data
	table.insert(bin, string.pack("I4", #self.UUID) .. self.UUID)

	-- Write Type: length (uint32) + string data
	table.insert(bin, string.pack("I4", #self.Type) .. self.Type)

	-- Write quantity as uint32 (4 bytes)
	table.insert(bin, string.pack("I4", self.Quantity))
	
	-- Create and return the buffer
	return buffer.fromstring(table.concat(bin))
end

function module.FromBuffer(buf: buffer)
	-- Convert the buffer to a string
	local str = buffer.tostring(buf)
	local pos = 1

	-- Read UUID (4 bytes) + string data
	local uuid_len = string.unpack("I4", str, pos)
	pos = pos + 4
	local uuid = string.sub(str, pos, pos + uuid_len - 1)
	pos = pos + uuid_len

	-- Read Type (4 bytes) + string data
	local type_len = string.unpack("I4", str, pos)
	pos = pos + 4
	local item_type = string.sub(str, pos, pos + type_len - 1)
	pos = pos + type_len

	-- Read Quantity (4 bytes)
	local quantity = string.unpack("I4", str, pos)
	pos = pos + 4

	-- Create a new ItemStack and set its properties
	return module.new(item_type, quantity, uuid)
end

function module.FromUUID(uuid: string)
	return module.ItemStackCache[uuid]
end

return module
