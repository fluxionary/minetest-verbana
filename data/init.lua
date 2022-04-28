local http = verbana.ie.http
local iconv = verbana.ie.iconv

if not http then
    return
end

verbana.data = {}

function verbana.data.do_update_data_used_autnums(result)
    if result.completed and result.succeeded then
        assert(filename)
        verbana.lib.util.write_file(filename, iconv.from("iso-8859-1", result))
    else
        verbana.log("warning", "problem updating ")
    end
end

function verbana.data.do_update_data_raw_table(result)

end

function verbana.data.do_update_ipv6_raw_table(result)

end

function verbana.data.update_data()
    http.fetch({
        url = "http://thyme.apnic.net/current/data-used-autnums"
    }, verbana.data.do_update_data_used_autnums)
    http.fetch({
        url = "http://thyme.apnic.net/current/data-raw-table"
    }, verbana.data.do_update_data_raw_table)
    http.fetch({
        url = "https://thyme.apnic.net/current/ipv6-raw-table"
    }, verbana.data.do_update_ipv6_raw_table)
end
