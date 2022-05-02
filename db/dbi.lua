local dbi = verbana.lib.make_class()
verbana.db.dbi = dbi

function dbi.register_asn(asn)
    error("missing")
end

function dbi.get_asn_status(asn, create_if_new)
    error("missing")
end

function dbi.set_asn_status(asn, executor_id, status_id, reason, expires)
    error("missing")
end

function dbi.get_asn_stats(asn)
    error("missing")
end

function dbi.assoc(player_id, ipint, asn)
    error("missing")
end

function dbi.has_asn_assoc(player_id, asn)
    error("missing")
end

function dbi.has_ip_assoc(player_id, ipint)
    error("missing")
end

function dbi.get_player_associations(player_id)
    error("missing")
end

function dbi.get_ip_associations(ipint, from_time)
    error("missing")
end

function dbi.get_asn_associations(asn, from_time)
    error("missing")
end

function dbi.get_player_cluster(player_id)
    error("missing")
end

function dbi.register_ip(ipint)
    error("missing")
end

function dbi.get_ip_status(ipint, create_if_new)
    error("missing")
end

function dbi.set_ip_status(ipint, executor_id, status_id, reason, expires)
    error("missing")
end

function dbi.log(player_id, ipint, asn, success)
    error("missing")
end

function dbi.get_player_status_log(player_id)
    error("missing")
end

function dbi.get_ip_status_log(ipint)
    error("missing")
end

function dbi.get_asn_status_log(asn)
    error("missing")
end

function dbi.get_first_login(player_id)
    error("missing")
end

function dbi.get_player_connection_log(player_id, limit)
    error("missing")
end

function dbi.get_ip_connection_log(ipint, limit)
    error("missing")
end

function dbi.get_asn_connection_log(asn, limit)
    error("missing")
end

function dbi.get_player_id(name, create_if_new)
    error("missing")
end

function dbi.flag_player(player_id, flag)
    error("missing")
end

function dbi.get_player_status(player_id, create_if_new)
    error("missing")
end

function dbi.set_player_status(player_id, executor_id, status_id, reason, expires, no_update_current)
    error("missing")
end

function dbi.get_all_banned_players()
    error("missing")
end

function dbi.get_ban_log(limit)
    error("missing")
end

function dbi.get_master(player_id)
    error("missing")
end

function dbi.set_master(player_id, master_id)
    error("missing")
end

function dbi.swap_master(player_id, master_id)
    error("missing")
end

function dbi.unset_master(player_id)
    error("missing")
end

function dbi.get_alts(player_id)
    error("missing")
end

function dbi.grep_player(pattern, limit)
    error("missing")
end

function dbi.add_report(reporter_id, report)
    error("missing")
end

function dbi.get_reports(from_time)
    error("missing")
end
