
function data.add_report(reporter_id, report)
    local code = [[

    ]]
    local now = os.time()
    return execute_bind_one(code, "add report", reporter_id, report, now)
end

function data.get_reports(from_time)
    local code = [[

    ]]
    return get_full_ntable(code, "get reports", from_time)
end
