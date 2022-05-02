local db = verbana.db

-- constants
db.player_status = {
    default={name="default", id=1, color="#FFF"},
    suspicious={name="suspicious", id=2, color="#FF0"},
    banned={name="banned", id=3, color="#F00"},
    whitelisted={name="whitelisted", id=4, color="#0F0"},
    unverified={name="unverified", id=5, color="#0FF"},
    kicked={name="kicked", id=6, color="#F0F"},  -- for logging kicks
}
db.player_status_name = {}
db.player_status_color = {}
for _, value in pairs(db.player_status) do
    db.player_status_name[value.id] = value.name
    db.player_status_color[value.id] = value.color
end

db.ip_status = {
    default={name="default", id=1, color="#FFF"},
    suspicious={name="suspicious", id=2, color="#FF0"},
    blocked={name="blocked", id=3, color="#F00"},
    trusted={name="trusted", id=4, color="#00F"},
}
db.ip_status_name = {}
db.ip_status_color = {}
for _, value in pairs(db.ip_status) do
    db.ip_status_name[value.id] = value.name
    db.ip_status_color[value.id] = value.color
end

db.asn_status = {
    default={name="default", id=1, color="#FFF"},
    suspicious={name="suspicious", id=2, color="#FF0"},
    blocked={name="blocked", id=3, color="#F00"},
}
db.asn_status_name = {}
db.asn_status_color = {}
for _, value in pairs(db.asn_status) do
    db.asn_status_name[value.id] = value.name
    db.asn_status_color[value.id] = value.color
end

db.verbana_player = "!verbana!"
db.verbana_player_id = 1
