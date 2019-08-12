Verbana: Verification and banning mod for Minetest
==================================================

CURRENTLY A NON-FUNCTIONAL WIP. DO NOT USE UNTIL THIS MESSAGE HAS BEEN REMOVED.

Name
----
A portmanteau of "verification", "ban", and the herb verbena.

Terminology
-----------

The terms `network` and `ASN` are used interchangeably in this document.  

Motivation
----------

This mod is a response to sban, an IP-aware banning mod derived from xban,
and BillyS's verification mod for Blocky Survival. Both of these mods have
problems that I've long wanted to resolve, and it seemed the best resolution
to those problems was to create a new integrating the features of both.

Sban is a good first attempt at IP-aware bans, but it has several major flaws:
1. Multiple users may be associated with an IP, and banning one often bans
   them all.
2. Banned IPs can still "hack" into existing accounts of other players by
   brute-forcing weak passwords.
3. For many trolls, getting access to a new IP is far too easy, and there is no
   effective way to keep them off the server.

BillyS's verification mod was created to deal with one particular troll on
the BlockySurvival server, who repeatedly got around sban by getting new IPs
from VPNs and his regular mobile service provider. When enabled, it requires 
all new players to be verified by a player with moderator privileges before 
they can interact with the server or communicate with non-moderator players.

The flaws in the verification mod are
1. Verification is all-or-nothing; either all new players require verification,
   or none of them do.
2. Moderators are not always online to verify new players.
3. New players come from all over the world, and may not be able to communicate
   with the moderator.
4. New players are of all ages, and may not be able to communicate in chat at
   all.

Verbana aims to provide name-based banning, as well as ip and network based
blocking and verification.
1. IPs and Networks may be marked as "untrusted" - all new players from
   untrusted IPs/networks must go through verification, while other new
   players may join at will.
2. A "verification jail" can optionally be specified, which prevents unverified
   players from getting loose on the server.  
3. IPs and Networks may be blocked or temporarily blocked, should the need
   arise.

Some features of sban that the first release of Verbana will likely lack:
* A GUI. The sban GUI does not work particularly well anyway, and I don't know 
  formspec. Use commands.
* Import/export from various other ban formats. I plan to import data from sban, 
  but I don't have a use case for the rest. However, if someone wants to write
  a module to import from e.g. xban2, be my guest.

Requirements
============

* Minetest 5.0 or later.
* Verbana must be listed as a trusted mod in minetest.conf (`secure.trusted_mods`), 
  in order to use a sqlite database.
* lsqlite3 (SQLite3 for Lua) must be installed and accessible to Minetest's Lua.
 * The easiest way I know how to do this: install luarocks, and execute 
   `luarocks --lua-version 5.1 install lsqlite3` or the appropriate variation. 
* The Minetest server must use IPv4 exclusively. I've made zero attempt to support 
  IPv6. 
* There's some soft dependencies on linux. Windows users may need to make some changes,
  which I would gladly accept as a PR.

Optional Dependencies
---------------------

Verbana can make use of the stock IRC mod, as well as the "IRC2" mod that is used on
the Blocky Survival server to connect to a second IRC server. 

Sban and verification are also listed as optional dependencies, but this is primarily
in order for verbana to detect their presence. By default, verbana will run in 
"debug mode" if these mods are detected. If you wish to use verbana as intended, you do
*not* want these mods installed.

Installation
============

If you don't know the basics of installing a minetest mod, please see
* https://wiki.minetest.net/Installing_Mods
* https://dev.minetest.net/Installing_Mods

Trust the mod
-------------

Verbana must be marked as a trusted mod, with a line like the following added to
minetest.conf:
```
secure.trusted_mods = verbana
``` 

The only "trusted" thing verbana does is load lsqlite so that it can interact with
its database. To our knowledge, verbana cannot leak the insecure environment, but 
it can leak the lsqlite interface in minetest 5.0.1 and development versions before
commit ecd20de. 

Download ASN tables
-------------------

Once you have put the verbana mod in the correct place, you will need to download the
ASN tables that verbana uses to correlate IP numbers with networks. On Linux
systems, you should just be able to run the script `update_tables.sh`. On other systems,
you will need to find another way to download those files, and convert the 
data-used-autnums file from ths ISO-8859-1 encoding to utf8. 

The ASN tables update regularly, though for the most part nothing major changes.
You should put a process in place that updates these automatically (or manually)
some period between daily and monthly. 

Configuration
-------------

The following configuration options are available, and can be set in your `minetest.conf`
file.

* `verbana.db_path` 
  
  The location verbana will store its database. Defaults to `${WORLD_ROOT}/verbana.sqlite`.
   
* `verbana.asn_description_path`

  The location of the ASN description file. Defaults to `${MOD_ROOT}/data-used-autnums`

* `verbana.asn_data_path`

  The location of the ASN data file. Defaults to `${MOD_ROOT}/data-raw-table`

* `verbana.admin_priv`

  The privilege needed to administer verbana. Defaults to `ban_admin`. This privilege will
  be created if it does not currently exist.

* `verbana.moderator_priv`

  The privilege needed to administer verbana. Defaults to `basic_privs`. This privilege will
  be created if it does not currently exist.

* `verbana.unverified_privs`

  The privileges granted to users with the "unverified" status. Defaults to `shout`. 
  If there are multiple privileges, they should be comma-delimited.

* `default_privs`

  This is a core setting, not a verbana-specific one. Verbana uses it to determine what
  privileges to give to players once they are verified. Defaults to `shout,interact`.
  If there are multiple privileges, they should be comma-delimited.

* `verbana.whitelisted_privs`

  A list of privileges that are equivalent to the `whitelisted` status. If a player has
  all of the listed privileges, they skip the suspicious network checks on login. By
  default, it is blank i.e. disabled.  

* `static_spawnpoint`

  This is a core setting, not a verbana-specific one. Verbana uses this to determine
  where a normal (verified) player will spawn, and where to move players that are
  newly verified. It is a list of coordinates `(x,y,z)`, and defaults to  `(0,0,0)`.

* `verbana.unverified_spawn_pos`

  Coordinates where unverified players will spawn. It is a list of coordinates
  `(x,y,z)` and defaults to the value of `static_spawnpoint`.

* `verbana.jail_bounds`

  Boundaries for the verification "jail" area, if one exists. It needs to be specified
  as a pair of coordinates, (x1,y1,z1),(x2,y2,z2), that specify the 3d bounding box
  of the jail. If a jail is defined, `verbana.unverified_spawn_pos` should be
  *inside* of the jail, or unexpected behavior may result. 

* `verbana.jail_check_period`

  A period, specified in seconds, between checks of whether an unverified player has
  escaped the verification jail. It defaults to 0, which disables the jail.
  
  Both `verbana.jail_bounds` and `verbana.jail_check_period` must be defined in
  order for the verification jail to be enabled.

* `verbana.universal_verification`

  If set to `true`, all new users must be verified. Otherwise, only players from suspicious 
  networks need be verified. Defaults to `false`

* `verbana.debug_mode`

  Whether to run verbana in debug mode. By default, verbana will run in debug mode if 
  the sban or verification mod are installed and enabled. Setting this will override
  that behavior, if that is desired.
  
  In debug mode, verbana will (1) reload the schema on every server startup
  (2) automatically import data from sban, if its DB is found (3) not make any changes
  to player privileges (4) not block any users from connecting to the server (5) not 
  kick any users from the server. 

Functionality
=============

Verbana assigns a "status" to all players, IPs, and networks that determines in what 
cases players can connect to the server. 

Player Status
-------------

* `default`

  Most players will have the `default` status.

* `banned`

  A player who has been banned will not be able to connect to the server. Note
  that banning one account does not generally prevent other accounts from
  connecting from IPs or Networks that the user has been associated with. However,
  it will temporarily mark the last-known IP of the user as suspicious.

* `unverified`

  A new player that connects from a suspicious IP or network is automatically
  marked as `unverified`. Unverified users have reduced privileges (by default,
  they lack `interact`), and must be verified by a verbana admin or moderator 
  before they can play the game or communicate with ordinary players. 

* `suspicious`

  A player that has been marked as `suspicious` has no real restrictions,
  but verbana moderators and admins will be alerted when the player logs in or
  performs certain other actions.

* `whitelisted`

  A player that has been whitelisted will be allowed to bypass the suspicious
  network checks when they join the server. 

IP status
---------

* `default`

  Most IPs will have the `default` status.

* `blocked`

  All connections from blocked IPs will be denied, except for whitelisted players.

* `suspicious`

  A new player connecting from a `suspicious` IP will be forced to go through
  verification, unless the player is whitelisted. An attempt to connect from a 
  suspicious IP as an existing player will be denied, if that player has never 
  connected from that network before. 

* `trusted`

  An IP in a suspicious network may be marked as `trusted`, which indicates that
  connections from that IP will bypass suspicious network checks. 
  
ASN status
----------

* `default`

  Most networks will have the `default` status.

* `blocked`

  All connections from this network will be denied, unless the player is whitelisted
  or the IP is trusted.

* `suspicious`

  A new player connecting from a `suspicious` network will be forced to go through
  verification, unless the player is whitelisted. An attempt to connect from a 
  suspicious network as an existing player will be denied, if that player has never 
  connected from that network before. 

Master accounts and alts
------------------------

It is possible to link accounts together in a master/alt account relationship. In
such a relationship, changes in the status to one account will be reflected by them
all. This can be used to associate new accounts w/ existing accounts that are
banned, to quickly ban those accounts. 

An account can have only one master. A master account cannot have another account as its master;
you can't chain the master/alt relationship.  

Commands
========

# Administration
sban_import  [<filename>]
verification on | off

# General status
reports [<timespan>=1w]
bans    [<number>=20]
who2

# Player inspection
pgrep      <pattern> [<limit>=20]
asn        <player_name> | <IP>
cluster    <player_name>
status     <player_name> [<number>]
inspect    <player_name>
ban_record <player_name>
logins     <player_name> [<number>=20]

# Player management
kick        <player_name> [<reason>]
ban         <player_name> [<timespan>] [<reason>]
unban       <player_name> [<reason>]
suspect     <player_name> [<reason>]
unsuspect   <player_name> [<reason>]
verify      <player_name> [<reason>]
unverify    <player_name> [<reason>]
whitelist   <player_name> [<reason>]
unwhitelist <player_name> [<reason>]
master     <alt> <master>
unmaster  <player_name>

# IP inspection
ip_inspect <IP> [<timespan>=1w]
ip_status  <IP> [<number>]

# IP management
ip_block     <IP> [<timespan>] [<reason>]
ip_unblock   <IP> [<reason>]
ip_suspect   <IP> [<reason>]
ip_unsuspect <IP> [<reason>]
ip_trust     <IP> [<reason>]
ip_untrust   <IP> [<reason>]

# ASN inspection
asn_inspect <ASN> [<timespan>=1w]
asn_status  <ASN> [<number>]
asn_stats   <ASN>

# ASN management
asn_block     <ASN> [<timespan>] [<reason>]
asn_unblock   <ASN> [<reason>]
asn_suspect   <ASN> [<reason>]
asn_unsuspect <ASN> [<reason>]

# Available to all players
report  <message>
first-login <player_name>
