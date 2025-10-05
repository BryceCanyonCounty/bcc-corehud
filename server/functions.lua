VorpCore = exports.vorp_core:GetCore()
BccUtils = exports['bcc-utils'].initiate()

-- Helper function for debugging in DevMode
if Config.devMode then
    function devPrint(message)
        print("^1[DEV MODE] ^4" .. message .. "^1")
    end
else
    function devPrint(message) end -- No-op if DevMode is disabled
end
