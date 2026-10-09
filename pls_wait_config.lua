local Config = {}

function Config.initializeSettings(settings, touchEnabled, defaultBoothText)
    settings.antiAfk = settings.antiAfk or false
    settings.serverStayTime = settings.serverStayTime or 30
    settings.persistToggles = settings.persistToggles or false
    settings.touchPreventAFK = settings.touchPreventAFK or (touchEnabled and true or false)
    settings.staffHop = settings.staffHop or false
    settings.spinOnDonation = settings.spinOnDonation or false
    settings.spinSet = settings.spinSet or settings.spinOnDonation or false
    settings.spinSpeedMultiplier = settings.spinSpeedMultiplier or 1
    settings.chatAutoThankYou = settings.chatAutoThankYou or false
    settings.thankYouMessages = settings.thankYouMessages or {"thanks!", "thank you", "ty (:"}
    settings.emotePlaying = settings.emotePlaying or false
    settings.boothText = settings.boothText or defaultBoothText
end

function Config.create(dependencies)
    assert(type(dependencies) == "table", "config dependencies are required")
    local HttpService = assert(dependencies.HttpService, "HttpService is required")
    local settings = assert(dependencies.settings, "settings table is required")
    local path = assert(dependencies.path, "config path is required")
    local getRuntimeState = assert(dependencies.getRuntimeState, "runtime-state getter is required")
    local applyRuntimeState = assert(dependencies.applyRuntimeState, "runtime-state setter is required")
    local readFile = dependencies.readFile
    local writeFile = dependencies.writeFile
    local isFile = dependencies.isFile

    local function save()
        if type(writeFile) ~= "function" then
            return false, "No supported file-writing function is available."
        end

        local data = {
            webhookToggle = settings.webhookToggle,
            webhookUrl = settings.webhookUrl,
            antiAfk = settings.antiAfk,
            touchPreventAFK = settings.touchPreventAFK,
            persistToggles = settings.persistToggles,
            spinOnDonation = settings.spinSet,
            spinSet = settings.spinSet,
            spinSpeedMultiplier = settings.spinSpeedMultiplier,
            populationHopper = settings.populationHopper,
            populationThreshold = settings.populationThreshold,
            emoteId = settings.emoteId,
            boothText = settings.boothText,
            staffHop = settings.staffHop,
            emotePlaying = settings.emotePlaying and true or false,
            chatAutoThankYou = settings.chatAutoThankYou,
            thankYouMessages = settings.thankYouMessages,
        }
        for key, value in pairs(getRuntimeState()) do
            data[key] = value
        end

        local encodedOk, encoded = pcall(function()
            return HttpService:JSONEncode(data)
        end)
        if not encodedOk then
            return false, "Could not encode settings: " .. tostring(encoded)
        end

        local writeOk, writeError = pcall(writeFile, path, encoded)
        if not writeOk then
            return false, "Could not write settings: " .. tostring(writeError)
        end
        return true
    end

    local function load()
        if type(readFile) ~= "function" then
            return false, "No supported file-reading function is available."
        end
        if type(isFile) == "function" then
            local checkOk, exists = pcall(isFile, path)
            if checkOk and not exists then
                return false, "not-found"
            end
        end

        local readOk, content = pcall(readFile, path)
        if not readOk then
            return false, "Could not read settings: " .. tostring(content)
        end
        if type(content) ~= "string" or content == "" then
            return false, "not-found"
        end

        local decodeOk, decoded = pcall(function()
            return HttpService:JSONDecode(content)
        end)
        if not decodeOk or type(decoded) ~= "table" then
            return false, "Could not decode settings: " .. tostring(decoded)
        end

        if decoded.webhookToggle ~= nil then settings.webhookToggle = decoded.webhookToggle end
        settings.webhookUrl = decoded.webhookUrl or settings.webhookUrl
        if decoded.antiAfk ~= nil then settings.antiAfk = decoded.antiAfk end
        if decoded.touchPreventAFK ~= nil then settings.touchPreventAFK = decoded.touchPreventAFK end
        if decoded.persistToggles ~= nil then settings.persistToggles = decoded.persistToggles end
        if decoded.spinSet ~= nil then settings.spinSet = decoded.spinSet end
        if decoded.spinOnDonation ~= nil then settings.spinSet = decoded.spinOnDonation end
        if decoded.spinSpeedMultiplier ~= nil then settings.spinSpeedMultiplier = decoded.spinSpeedMultiplier end
        if decoded.populationHopper ~= nil then settings.populationHopper = decoded.populationHopper end
        if decoded.populationThreshold ~= nil then settings.populationThreshold = decoded.populationThreshold end
        settings.emoteId = decoded.emoteId or settings.emoteId
        settings.boothText = decoded.boothText or settings.boothText
        if decoded.staffHop ~= nil then settings.staffHop = decoded.staffHop end
        if decoded.emotePlaying ~= nil then settings.emotePlaying = decoded.emotePlaying end
        if decoded.chatAutoThankYou ~= nil then settings.chatAutoThankYou = decoded.chatAutoThankYou end
        if type(decoded.thankYouMessages) == "table" then
            settings.thankYouMessages = decoded.thankYouMessages
        end

        applyRuntimeState(decoded)
        return true
    end

    return {
        save = save,
        load = load,
    }
end

return Config
