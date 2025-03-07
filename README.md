Simple Inventory and ItemStack concept in luau. Similar to Bukkit/Spigot inventory solution used in Minecraft.

This does not handle any networking or synchronization, but a networking layer is easy to set up using the provided events and buffer implementations.

Feel free to use for anything.

Example Usage:
```lua
local Inventory = require(game.ReplicatedStorage.Core.Inventory.Inventory)
local PlayerInventory = require(game.ReplicatedStorage.Core.Inventory.PlayerInventory)
local ItemStack = require(game.ReplicatedStorage.Core.Inventory.ItemStack)

local function newPlayer(player: Player)
	local player_inv = PlayerInventory.new(player)

	local test_item2 = ItemStack.new("Coins", 25)
	player_inv.Inventory:AddItem(test_item2)

	local test_item3 = ItemStack.new("Coins", 64)
	player_inv.Inventory:AddItem(test_item3)

	player_inv.Inventory:AddItem(ItemStack.new("LeatherTunic", 1))
	player_inv:SetChestplate(player_inv.Inventory:FindFirstItemOfType("LeatherTunic"))
	
	-- Dequip test
	player_inv:SetChestplate(nil)
	
	-- Swap test
	player_inv.Inventory:SetItem(1, player_inv.Inventory.Slots[2])

	print("PlayerInventory:", player_inv)
end

game.Players.PlayerAdded:Connect(newPlayer)
for _,v in pairs(game.Players:GetPlayers()) do
	task.spawn(newPlayer, v)
end
```
