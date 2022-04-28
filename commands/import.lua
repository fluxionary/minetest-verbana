
register_chatcommand("sban_import", {
    description="Import records from sban into verbana",
    params="[<filename>]",
    privs={[admin_priv]=true},
    func=function (caller, filename)
        if not filename or filename == "" then
            filename = worldpath .. "/sban.sqlite"
        end
        if not util.file_exists(filename) then
            return false, ("Could not open file %q."):format(filename)
        end
        chat_send_player(caller, "Importing SBAN. This can take a while...")
        if data.import_from_sban(filename) then
            return true, "Successfully imported."
        else
            return false, "Error importing SBAN db (see server log)"
        end
    end
})
