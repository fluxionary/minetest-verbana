
-- constants
data.player_status = {
    default={name="default", id=1, color="#FFF"},
    suspicious={name="suspicious", id=2, color="#FF0"},
    banned={name="banned", id=3, color="#F00"},
    whitelisted={name="whitelisted", id=4, color="#0F0"},
    unverified={name="unverified", id=5, color="#0FF"},
    kicked={name="kicked", id=6, color="#F0F"},  -- for logging kicks
}
data.player_status_name = {}
data.player_status_color = {}
for _, value in pairs(data.player_status) do
    data.player_status_name[value.id] = value.name
    data.player_status_color[value.id] = value.color
end

data.ip_status = {
    default={name="default", id=1, color="#FFF"},
    suspicious={name="suspicious", id=2, color="#FF0"},
    blocked={name="blocked", id=3, color="#F00"},
    trusted={name="trusted", id=4, color="#00F"},
}
data.ip_status_name = {}
data.ip_status_color = {}
for _, value in pairs(data.ip_status) do
    data.ip_status_name[value.id] = value.name
    data.ip_status_color[value.id] = value.color
end

data.asn_status = {
    default={name="default", id=1, color="#FFF"},
    suspicious={name="suspicious", id=2, color="#FF0"},
    blocked={name="blocked", id=3, color="#F00"},
}
data.asn_status_name = {}
data.asn_status_color = {}
for _, value in pairs(data.asn_status) do
    data.asn_status_name[value.id] = value.name
    data.asn_status_color[value.id] = value.color
end

data.verbana_player = "!verbana!"
data.verbana_player_id = 1
