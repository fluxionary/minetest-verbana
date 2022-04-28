

-- prevent players from flooding reports
local report_times_by_player = {}

register_chatcommand("report", {
    description="Send a report to server staff",
    params="<report>",
    func=function(reporter, report)
        -- TODO make the hard-coded values here settings
        local now = os.time()
        local report_times = report_times_by_player[reporter]
        if not report_times then
            report_times_by_player[reporter] = {now}
        else
            while #report_times > 0 and (now - report_times[1]) > 3600 do
                table.remove(report_times, 1)
            end
            if #report_times >= 5 then
                return false, "You may only issue 5 reports in an hour."
            end
            table.insert(report_times, now)
        end
        if report == "" then
            return false, "You must enter a report!"
        end
        local reporter_id = data.get_player_id(reporter)
        if not data.add_report(reporter_id, report) then
            return false, "Error: check server log"
        end
        return true, "Report sent."
    end
})

register_chatcommand("reports", {
    description="View recent reports",
    params="[<timespan>=1w]",
    privs={[mod_priv]=true},
    func=function(caller, timespan_str)
        local timespan
        if timespan_str ~= "" then
            timespan = parse_timespan(timespan_str)
            if not timespan then
                return false, "Invalid timespan"
            end
        else
            timespan = 60*60*24*7
        end
        local from_time = os.time() - timespan
        local rows = data.get_reports(from_time)
        if not rows then
            return false, "An error occurred (see server logs)"
        elseif #rows == 0 then
            return true, "No records found."
        end
        for _, row in ipairs(rows) do
            local message = ("%s % 20s: %s"):format(
                iso_date(row.timestamp),
                row.reporter,
                row.report
            )
            chat_send_player(caller, message)
        end
    end
})
