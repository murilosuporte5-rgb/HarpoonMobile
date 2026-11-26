-- Harpoon a Fish | Fish ESP v0.1
-- Client-side visual prototype; object names are unverified.
local Players = game:GetService("Players")
local player = Players.LocalPlayer
if game.PlaceId ~= 113384248926706 then
    warn("Jogo incompativel")
    return
end

local names = {
    "fish", "shark", "kraken", "megalodon",
    "crocodon", "nightcrawler", "hexjaw"
}
local active = {}
local gui = player:WaitForChild("PlayerGui")
local function matches(name)
    name = string.lower(name)
    for _, keyword in ipairs(names) do
        if string.find(name, keyword, 1, true) then
            return true
        end
    end
    return false
end
local function highlight(object)
    if active[object] or not object:IsA("Model") or not matches(object.Name) then
        return
    end
    local esp = Instance.new("Highlight")
    esp.Name = "FishESP"
    esp.Adornee = object
    esp.FillColor = Color3.fromRGB(0, 190, 255)
    esp.OutlineColor = Color3.new(1, 1, 1)
    esp.FillTransparency = 0.6
    esp.Parent = gui
    active[object] = esp
    object.Destroying:Connect(function()
        esp:Destroy()
        active[object] = nil
    end)
end
workspace.DescendantAdded:Connect(highlight)
for _, object in ipairs(workspace:GetDescendants()) do
    highlight(object)
end
print("Harpoon Fish ESP iniciado")
