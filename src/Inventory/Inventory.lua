--!strict

local module = {}

local ItemStack = require("./ItemStack")

local Signal = require("../Library/Signal")

local HttpService = game:GetService("HttpService")

export type Inventory = {
	Slots: {ItemStack.ItemStack?},
	Size: number,
	
	Viewers: {Player},
	
	UUID: string,
	
	FindFirstEmptySlot: (self: Inventory)->(number?),
	
	Destroy: (self: Inventory)->(),
	Destroyed: Signal.Signal<() -> ()>,

	SetItem: (self: Inventory, slot: number, item: ItemStack.ItemStack?)->(),
	AddItem: (self: Inventory, item: ItemStack.ItemStack)->(boolean, {number}),
	CanAddItem: (self: Inventory, item: ItemStack.ItemStack)->(boolean),
	RemoveItem: (self: Inventory, item: ItemStack.ItemStack)->(boolean),
	GetItemSlot: (self: Inventory, item: ItemStack.ItemStack)->(number?),
	HasItem: (self: Inventory, item: ItemStack.ItemStack)->(boolean),
	FindFirstItemOfType: (self: Inventory, item_type: string)->(ItemStack.ItemStack?),
	GetItems: (self: Inventory)->({ItemStack.ItemStack}),

	AddViewer: (self: Inventory, player: Player)->(),
	RemoveViewer: (self: Inventory, player: Player)->(),

	ViewerAdded: Signal.Signal<(player: Player) -> (), Player>,
	ViewerRemoved: Signal.Signal<(player: Player) -> (), Player>,
	
	ToBuffer: (self: Inventory) -> (buffer),

	ItemAdded: Signal.Signal<(item: ItemStack.ItemStack, slot: number) -> (), ItemStack.ItemStack, number>,
	ItemChanged: Signal.Signal<(item: ItemStack.ItemStack, slot: number) -> (), ItemStack.ItemStack, number>,
	ItemRemoved: Signal.Signal<(item: ItemStack.ItemStack, slot: number) -> (), ItemStack.ItemStack, number>,
	ItemMoved: Signal.Signal<(item: ItemStack.ItemStack, new_slot: number, old_slot: number) -> (ItemStack.ItemStack, number, number), ItemStack.ItemStack, number, number>,
}

module.InventoryMap = {} :: {[string]: Inventory}
module.InventoryAdded = Signal.new() :: Signal.Signal<(inventory: Inventory) -> (), Inventory>
module.InventoryRemoved = Signal.new() :: Signal.Signal<(inventory: Inventory) -> (), Inventory>

local tracking_items: {[string]: {[string]: {Signal.Connection}}} = {}

local inventory = {}

function module.new(size: number, uuid: string?) : Inventory
	if ( uuid ) then
		local cached_inventory = module.InventoryMap[uuid]
		if ( cached_inventory ) then
			return cached_inventory
		end
	end
	
	local self = setmetatable({
		Size = size,
		Slots = table.create(size),
		
		ItemAdded = Signal.new(),
		ItemChanged = Signal.new(),
		ItemRemoved = Signal.new(),
		ItemMoved = Signal.new(),
		
		Viewers = {},
		ViewerAdded = Signal.new(),
		ViewerRemoved = Signal.new(),
		
		Destroyed = Signal.new(),

		UUID = uuid or HttpService:GenerateGUID(true)
	} :: any, {__index = inventory}) :: Inventory

	table.freeze(self)
	
	module.InventoryMap[self.UUID] = self
	module.InventoryAdded:Fire(self)
	
	return self
end

function inventory.Destroy(self: Inventory)
	if ( (self :: any).Destroyed ) then
		return
	end
	
	tracking_items[self.UUID] = nil
	module.InventoryMap[self.UUID] = nil
	module.InventoryRemoved:Fire(self)
	self.Destroyed:Fire()
	
	task.defer(function()
		for _,v in pairs(self:GetItems()) do
			v:Destroy()
		end

		for k,_ in pairs(self) do
			self[k] = nil
		end
		
		(self :: any).Destroyed = true
	end)
end

function inventory.GetItems(self: Inventory)
	local items = {}
	
	for i=1,self.Size do
		local item = self.Slots[i]
		if ( item ) then
			table.insert(items, item)
		end
	end
	
	return items
end

function inventory.FindFirstEmptySlot(self: Inventory) : number?
	for i = 1, self.Size do
		if ( not self.Slots[i] ) then
			return i
		end
	end
	
	return nil
end

function inventory.FindFirstItemOfType(self: Inventory, item_type: string) : ItemStack.ItemStack?
	for i = 1, self.Size do
		local test_item = self.Slots[i]
		if ( test_item and test_item:GetItemData().Name == item_type ) then
			return test_item
		end
	end

	return nil
end

local function attemptAddItem(self: Inventory, item: ItemStack.ItemStack, can_modify: boolean) : (boolean, {number})
	local modified_slot_id = {}

	-- Item cannot already exist in inventory
	if ( self:HasItem(item) ) then
		return false, modified_slot_id
	end
	
	local input_quantity = item.Quantity

	-- try to merge it in to existing slots
	for i = 1, self.Size do
		local temp_item = self.Slots[i]
		if ( not temp_item ) then
			continue
		end
		
		-- Check if stacks are mergable
		local can_merge = temp_item.Type == item.Type
		if ( not can_merge ) then
			continue
		end
		
		-- Check merge
		local quantity_add = math.min(item.Quantity, temp_item:GetItemData().MaxStack - temp_item.Quantity)
		if ( quantity_add > 0 ) then
			if ( can_modify ) then
				temp_item:SetQuantity(temp_item.Quantity + quantity_add)
				item:SetQuantity(item.Quantity - quantity_add)
			end

			input_quantity -= quantity_add
			table.insert(modified_slot_id, i)
		end
	end

	-- If we merged the input stack fully, quit out
	if ( input_quantity <= 0 ) then
		return true, modified_slot_id
	end

	-- Find empty slot to add remaining item stack to
	local emptySlot = self:FindFirstEmptySlot()
	if not emptySlot then
		return false, modified_slot_id
	end

	-- Add it to a new slot
	if ( can_modify ) then
		self:SetItem(emptySlot, item)
	end
	table.insert(modified_slot_id, emptySlot)

	return true, modified_slot_id
end

local function getItemConnections(self: Inventory, item: ItemStack.ItemStack)
	local item_connection_map = tracking_items[self.UUID]
	if ( not item_connection_map ) then
		item_connection_map = {}
		tracking_items[self.UUID] = item_connection_map
	end
	
	local item_connections = item_connection_map[item.UUID]
	if ( not item_connections ) then
		item_connections = {}
		item_connection_map[item.UUID] = item_connections
	end
	
	return item_connections
end

local function itemAdded(self: Inventory, item: ItemStack.ItemStack, slot: number)
	self.ItemAdded:Fire(item, slot)
	
	local item_connections = getItemConnections(self, item)
	
	table.insert(item_connections, item.QuantityChanged:Connect(function()
		self.ItemChanged:Fire(item, slot)
	end))
end

local function itemRemoved(self: Inventory, item: ItemStack.ItemStack, slot: number)
	local item_connections = getItemConnections(self, item)
	
	for _,v in pairs(item_connections) do
		v:Disconnect()
	end
	
	self.ItemRemoved:Fire(item, slot)
end

function inventory.SetItem(self: Inventory, slot: number, item: ItemStack.ItemStack?)
	if ( item ) then
		local old_slot = self:GetItemSlot(item)
		if ( old_slot ) then
			if ( old_slot ~= slot ) then
				local swapped_item = self.Slots[slot]
				if ( swapped_item ) then
					self.Slots[old_slot] = swapped_item
					self.ItemMoved:Fire(swapped_item, old_slot, slot)
				else
					self.Slots[old_slot] = nil
				end
				
				self.Slots[slot] = item
				self.ItemMoved:Fire(item, slot, old_slot)
			end
		else
			self.Slots[slot] = item
			
			itemAdded(self, item, slot)
		end
	else
		local old_item = self.Slots[slot]
		if ( old_item ) then
			self:RemoveItem(old_item)
		end
	end
end

function inventory.AddItem(self: Inventory, item: ItemStack.ItemStack) : (boolean, {number})
	return attemptAddItem(self, item, true)
end

function inventory.CanAddItem(self: Inventory, item: ItemStack.ItemStack) : (boolean)
	local added_fully, _ = attemptAddItem(self, item, false)
	return added_fully
end

function inventory.RemoveItem(self: Inventory, item: ItemStack.ItemStack) : boolean
	for i = 1, self.Size do
		local test_item = self.Slots[i]
		if ( test_item and test_item.UUID == item.UUID ) then
			self.Slots[i] = nil

			itemRemoved(self, test_item, i)
			return true
		end
	end
	
	return false
end

function inventory.GetItemSlot(self: Inventory, item: ItemStack.ItemStack) : number?
	for i = 1, self.Size do
		local test_item = self.Slots[i]
		if ( test_item and test_item.UUID == item.UUID ) then
			return i
		end
	end

	return nil
end

function inventory.HasItem(self: Inventory, item: ItemStack.ItemStack) : boolean
	return self:GetItemSlot(item) ~= nil
end

function inventory.AddViewer(self: Inventory, viewer: Player)
	if ( table.find(self.Viewers, viewer) ) then
		return
	end

	table.insert(self.Viewers, viewer)
	self.ViewerAdded:Fire(viewer)
end

function inventory.RemoveViewer(self: Inventory, viewer: Player)
	local index = table.find(self.Viewers, viewer)
	if ( not index ) then
		return
	end

	table.remove(self.Viewers, index)
	self.ViewerRemoved:Fire(viewer)
end

function inventory.ToBuffer(self: Inventory) : buffer
	local bin = {}
	
	-- Write UUID: length (uint32) + string data
	table.insert(bin, string.pack("I4", #self.UUID) .. self.UUID)

	-- Write size as uint32 (4 bytes)
	table.insert(bin, string.pack("I4", self.Size))
	
	-- compute amount of items
	local amt_items = 0
	for i=1,self.Size do
		local item = self.Slots[i]
		if ( item ) then
			amt_items += 1
		end
	end
	
	-- Write items
	table.insert(bin, string.pack("I4", amt_items))
	for i=1,self.Size do
		local item = self.Slots[i]
		if ( item ) then
			-- Write size as uint32 (4 bytes)
			table.insert(bin, string.pack("I4", i))
			
			-- Write itemstack buffer
			local item_buffer = item:ToBuffer()
			local item_str = buffer.tostring(item_buffer)
			table.insert(bin, string.pack("I4", #item_str)) -- Item buffer length
			table.insert(bin, item_str) -- Item buffer data
		end
	end

	-- Create and return the buffer
	return buffer.fromstring(table.concat(bin))
end

function module.FromBuffer(buf)
	local str = buffer.tostring(buf)
	local pos = 1

	-- Read UUID length
	local uuid_len = string.unpack("I4", str, pos)
	pos = pos + 4

	-- Read UUID
	local uuid = string.sub(str, pos, pos + uuid_len - 1)
	pos = pos + uuid_len

	-- Read inventory size
	local size = string.unpack("I4", str, pos)
	pos = pos + 4

	-- Read number of items
	local amt_items = string.unpack("I4", str, pos)
	pos = pos + 4

	-- Initialize the Inventory object
	local inv = module.new(size, uuid)

	-- Read each item
	for i = 1, amt_items do
		-- Read slot index
		local slot_index = string.unpack("I4", str, pos)
		pos = pos + 4

		-- Read item buffer length
		local item_len = string.unpack("I4", str, pos)
		pos = pos + 4

		-- Extract item buffer
		local item_str = string.sub(str, pos, pos + item_len - 1)
		pos = pos + item_len

		-- Convert to buffer and parse item
		local item_buffer = buffer.fromstring(item_str)
		local item = ItemStack.FromBuffer(item_buffer)

		-- Assign to slot
		inv.Slots[slot_index] = item
	end

	return inv
end

function module.FromUUID(uuid: string)
	return module.InventoryMap[uuid]
end

return module