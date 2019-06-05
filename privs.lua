if not verbana then verbana = {} end
verbana.privs = {}

minetest.register_privilege('ban_admin', 'administrator for verification/bans')

verbana.privs.admin = 'ban_admin'  -- TODO load from settings
verbana.privs.moderator = 'basic_privs' -- TODO load from settings
