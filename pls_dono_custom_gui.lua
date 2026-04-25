local function characterHasShirtOrPants(pl, shirtIds, pantsIds)
    if not pl then
        return false, false
    end
    local shirtId
    local pantsId
    pcall(function()
        if pl.Character and pl.Character:FindFirstChild("Shirt") then
            shirtId = parseIdFromTemplate(pl.Character.Shirt.ShirtTemplate)
        end
    end)
    pcall(function()
        if pl.Character and pl.Character:FindFirstChild("Pants") then
            pantsId = parseIdFromTemplate(pl.Character.Pants.PantsTemplate)
        end
    end)

    local hasShirt = shirtId and table.find(shirtIds, shirtId) and true or false
    local hasPants = pantsId and table.find(pantsIds, pantsId) and true or false
    return hasShirt, hasPants
end

local function isBaconOutfit(pl)
    if not pl then
        return false
    end

    local hasShirt, hasPants = characterHasShirtOrPants(pl, baconShirtIds, baconPantsIds)
    local hasHair = characterHasMeshId(pl, baconHairIds)
    local desc = getHumanoidDescriptionForPlayer(pl)

    if desc then
        local descShirt = tonumber(desc.Shirt)
        local descPants = tonumber(desc.Pants)
        local descHairList = parseIdsFromCsv(desc.HairAccessory)
        if descShirt and table.find(baconShirtIds, descShirt) then
            hasShirt = true
        end
        if descPants and table.find(baconPantsIds, descPants) then
            hasPants = true
        end
        if listHasAny(descHairList, baconHairIds) then
            hasHair = true
        end
    end
