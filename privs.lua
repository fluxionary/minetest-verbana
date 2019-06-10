if not verbana then verbana = {} end
verbana.privs = {}

minetest.register_privilege('ban_admin', 'administrator for verification/bans')
-- note: unverified is not registered as a priv so you don't get it with "grant all"...

verbana.privs.admin = 'ban_admin'  -- TODO load from settings
verbana.privs.moderator = 'basic_privs' -- TODO load from settings
verbana.privs.unverified = 'unverified' -- TODO load from settings
