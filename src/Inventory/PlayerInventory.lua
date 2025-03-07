--!strict

local Inventory = require("./Inventory")

local ItemStack = require("./ItemStack")

local Signal = require("../Library/Signal")

export type PlayerInventory = {
	Inventory: Inventory.Inventory,
	Equipment: Inventory.Inventory,
	
	Player: Player,
	
	Destroy: (self: PlayerInventory)->(),

	GetHelmet: (self: PlayerInventory)->(ItemStack.ItemStack?),
	SetHelmet: (self: PlayerInventory, item: ItemStack.ItemStack?)->(boolean),

	GetChestplate: (self: PlayerInventory)->(ItemStack.ItemStack?),
	SetChestplate: (self: PlayerInventory, item: ItemStack.ItemStack?)->(boolean),

	GetLeggings: (self: PlayerInventory)->(ItemStack.ItemStack?),
	SetLeggings: (self: PlayerInventory, item: ItemStack.ItemStack?)->(boolean),

	GetBoots: (self: PlayerInventory)->(ItemStack.ItemStack?),
	SetBoots: (self: PlayerInventory, item: ItemStack.ItemStack?)->(boolean),

	GetWeapon: (self: PlayerInventory)->(ItemStack.ItemStack?),
	SetWeapon: (self: PlayerInventory, item: ItemStack.ItemStack?)->(boolean),

	GetShield: (self: PlayerInventory)->(ItemStack.ItemStack?),
	SetShield: (self: PlayerInventory, item: ItemStack.ItemStack?)->(boolean),

	GetGloves: (self: PlayerInventory)->(ItemStack.ItemStack?),
	SetGloves: (self: PlayerInventory, item: ItemStack.ItemStack?)->(boolean),

	GetCape: (self: PlayerInventory)->(ItemStack.ItemStack?),
	SetCape: (self: PlayerInventory, item: ItemStack.ItemStack?)->(boolean),

	GetNecklace: (self: PlayerInventory)->(ItemStack.ItemStack?),
	SetNecklace: (self: PlayerInventory, item: ItemStack.ItemStack?)->(boolean),

	GetQuiver: (self: PlayerInventory)->(ItemStack.ItemStack?),
	SetQuiver: (self: PlayerInventory, item: ItemStack.ItemStack?)->(boolean),
} 

local EquipmentSlotMap = {
	Helmet		= 1,
	Chestplate	= 2,
	Leggings	= 3,
	Boots		= 4,
	Weapon		= 5,
	Shield		= 6,
	Gloves		= 7,
	Cape		= 8,
	Necklace	= 9,
	Quiver		= 10,
}

local module = {}

module.InventoryMap = {} :: {[number]: PlayerInventory}
module.InventoryAdded = Signal.new() :: Signal.Signal<(inventory: PlayerInventory) -> (), PlayerInventory>

function module.new(player: Player) : PlayerInventory
	local inventory = Inventory.new(28)
	local equipment = Inventory.new(10)
	
	return module.link(player, inventory.UUID, equipment.UUID)
end

function module.link(player: Player, inventory_uuid: string, equipment_uuid: string)
	local self = setmetatable({} :: any, {__index = module}) :: PlayerInventory
	
	-- Wait for inventory (TODO Replace with event)
	local inv = nil
	while (not inv) do
		inv = Inventory.FromUUID(inventory_uuid)
		if ( not inv ) then
			task.wait()
		end
	end
	
	-- Wait for Equipment (TODO Replace with event)
	local equip = nil
	while (not equip) do
		equip = Inventory.FromUUID(equipment_uuid)
		if ( not equip ) then
			task.wait()
		end
	end

	self.Player = player
	self.Inventory = inv
	self.Equipment = equip

	self.Inventory:AddViewer(player)
	self.Equipment:AddViewer(player)

	table.freeze(self)

	module.InventoryMap[player.UserId] = self
	module.InventoryAdded:Fire(self)
	
	return self
end

function module.Destroy(self: PlayerInventory)
	if ( (self :: any).Destroyed ) then
		return
	end

	self.Inventory:Destroy()
	self.Equipment:Destroy()
	
	module.InventoryMap[self.Player.UserId] = nil
	
	for k,_ in pairs(self) do
		self[k] = nil
	end
	
	(self :: any).Destroyed = true
end

local function setEquipmentItem(self: PlayerInventory, new_item: ItemStack.ItemStack?, slot: number) : boolean
	-- Make sure this item is in our inventory
	if ( new_item and not self.Inventory:HasItem(new_item) ) then
		return false
	end
	
	-- Check if we can put old item back in inventory
	local old_item = self.Equipment.Slots[slot]
	if ( old_item ) then
		local canPutBack = self.Inventory:CanAddItem(old_item)
		if ( not canPutBack ) then
			return false
		end
	end
	
	-- 1. Remove new item from inventory
	if ( new_item ) then
		self.Inventory:RemoveItem(new_item)
	end
	
	-- 2. Remove old item from equipment
	if ( old_item ) then
		self.Equipment:RemoveItem(old_item)
	end

	-- 3. Add new item to equipment
	self.Equipment:SetItem(slot, new_item)

	-- 4. Add old item to inventory
	if ( old_item ) then
		self.Inventory:AddItem(old_item)
	end
	
	return true
end

local function getEquipmentItem(self: PlayerInventory, slot: number) : ItemStack.ItemStack?
	return self.Equipment.Slots[slot]
end


-- Helmet
function module.GetHelmet(self: PlayerInventory)
	return getEquipmentItem(self, EquipmentSlotMap.Helmet)
end

function module.SetHelmet(self: PlayerInventory, item: ItemStack.ItemStack?) : boolean
	return setEquipmentItem(self, item, EquipmentSlotMap.Helmet)
end
-----------------


-- Chestplate
function module.GetChestplate(self: PlayerInventory)
	return getEquipmentItem(self, EquipmentSlotMap.Chestplate)
end

function module.SetChestplate(self: PlayerInventory, item: ItemStack.ItemStack?) : boolean
	return setEquipmentItem(self, item, EquipmentSlotMap.Chestplate)
end
-----------------


-- Leggings
function module.GetLeggings(self: PlayerInventory)
	return getEquipmentItem(self, EquipmentSlotMap.Leggings)
end

function module.SetLeggings(self: PlayerInventory, item: ItemStack.ItemStack?) : boolean
	return setEquipmentItem(self, item, EquipmentSlotMap.Leggings)
end
-----------------


-- Boots
function module.GetBoots(self: PlayerInventory)
	return getEquipmentItem(self, EquipmentSlotMap.Boots)
end

function module.SetBoots(self: PlayerInventory, item: ItemStack.ItemStack?) : boolean
	return setEquipmentItem(self, item, EquipmentSlotMap.Boots)
end
-----------------


-- Weapon
function module.GetWeapon(self: PlayerInventory)
	return getEquipmentItem(self, EquipmentSlotMap.Weapon)
end

function module.SetWeapon(self: PlayerInventory, item: ItemStack.ItemStack?) : boolean
	return setEquipmentItem(self, item, EquipmentSlotMap.Weapon)
end
-----------------


-- Shield
function module.GetShield(self: PlayerInventory)
	return getEquipmentItem(self, EquipmentSlotMap.Shield)
end

function module.SetShield(self: PlayerInventory, item: ItemStack.ItemStack?) : boolean
	return setEquipmentItem(self, item, EquipmentSlotMap.Shield)
end
-----------------


-- Gloves
function module.GetGloves(self: PlayerInventory)
	return getEquipmentItem(self, EquipmentSlotMap.Gloves)
end

function module.SetGloves(self: PlayerInventory, item: ItemStack.ItemStack?) : boolean
	return setEquipmentItem(self, item, EquipmentSlotMap.Gloves)
end
-----------------


-- Cape
function module.GetCape(self: PlayerInventory)
	return getEquipmentItem(self, EquipmentSlotMap.Cape)
end

function module.SetCape(self: PlayerInventory, item: ItemStack.ItemStack?) : boolean
	return setEquipmentItem(self, item, EquipmentSlotMap.Cape)
end
-----------------


-- Necklace
function module.GetNecklace(self: PlayerInventory)
	return getEquipmentItem(self, EquipmentSlotMap.Necklace)
end

function module.SetNecklace(self: PlayerInventory, item: ItemStack.ItemStack?) : boolean
	return setEquipmentItem(self, item, EquipmentSlotMap.Necklace)
end
-----------------


-- Quiver
function module.GetQuiver(self: PlayerInventory)
	return getEquipmentItem(self, EquipmentSlotMap.Quiver)
end

function module.SetQuiver(self: PlayerInventory, item: ItemStack.ItemStack?) : boolean
	return setEquipmentItem(self, item, EquipmentSlotMap.Quiver)
end
-----------------

return module
