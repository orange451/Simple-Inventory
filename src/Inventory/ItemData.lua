local module = {}

export type ItemData = {
	Name: string,
	MaxStack: number,
	ItemClass: string,
	Reference: ModuleScript,
}

local DEFAULT_ITEM: ItemData = {
	Name = "Item",
	ItemClass = "BaseItem",
	MaxStack = 1,
	Reference = nil,
}

local item_types: {[string]: ItemData} = {}

function module.get(item_class: string) : ItemData
	return item_types[item_class]
end

-- Load in the items
for _,v in pairs(script.Parent.Items:GetChildren()) do
	local item_info = require(v) :: ItemData
	
	item_info.Name = v.Name
	item_info.Reference = v
	item_info.MaxStack = item_info.MaxStack or DEFAULT_ITEM.MaxStack
	item_info.ItemClass = item_info.ItemClass or DEFAULT_ITEM.ItemClass
	
	item_types[v.Name] = item_info
	table.freeze(item_info)
end

return module
