
register_chatcommand("verification", {
    description="Turn universal verification on or off",
    params="on | off",
    privs={[admin_priv]=true},
    func=function(caller, params)
        local value
        if params == "on" then
            value = true
        elseif params == "off" then
            value = false
        else
            return false, "Invalid parameters"
        end
        if settings.universal_verification == value then
            return true, ("Universal verification is already %s"):format(params)
        end
        settings.set_universal_verification(value)
        return true, ("Turned universal verification %s"):format(params)
    end
})
