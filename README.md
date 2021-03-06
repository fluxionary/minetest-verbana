Verbana: Verification and banning mod for Minetest
==================================================

Copyright flux 2021 AGPLv3

Name
----
A portmanteau of "verification", "ban", and the herb verbena.

Terminology
-----------

The terms `network` and `ASN` are used interchangeably in this document. 

The terms `player` and `account` are also used interchangeably in most contexts;
sometimes `player` will refer to a physical person, however.

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
\*not\* want these mods installed.

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

  The privilege needed to use verbana for moderation. Defaults to `ban`. 
  This privilege will be created if it does not currently exist.

* `verbana.kick_priv`

  The privilege needed to kick users. By default, the moderator privilege will be used. If
  you want a separate privilege just for kicking, you can set this value. Usually you'll want
  to give it the value "kick".

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


Flagged accounts
----------------

Accounts that have been banned, kicked, unverified, or marked as suspicious retain a 
separate "flagged" status, which is used to restrict the output of certain other
commands. 

Commands
========

Arguments in angle brackets "\<player\_name\>" are mandatory. Arguments in square brackets
are optional e.g. "[\<filename\>]". Some optional arguments have default values e.g.
[\<timespan\>=1w]. 

# Administration

These commands are available only to administrators.

* sban\_import [\<filename\>]

  Import data from the sban database. If no filename is specified, it looks for the
  DB in its default location, $WORLD\_ROOT/sban.sqlite 

* verification on | off

  Turn universal verification on or off. When universal verification is on,
  all new players must be verified before they can interact with the server.

# Available to all players

These commands are available to all players

* report  \<message\>

  Create a "report" that admins and moderators can read. Players
  can use this to communicate problems to staff if staff is not currently
  around.

* first-login \<player\_name\>

  Get the original login date for an account. Corresponds to /last-login

# General status

General query commands for verbana staff.

* reports [\<timespan\>=1w]

  Show recent reports.

* bans    [\<number\>=20]

  Show recent bans.

* who2

  Show currently connected players, along with IPs, networks, and statuses.

# Player inspection

Commands for looking up info about a player or players. All 
queries involving a player name are case-insensitive.

* pgrep      \<pattern\> [\<limit\>=20]

  Search for player accounts that match a certain "pattern".
  The pattern is a glob-type pattern, e.g. *flux* will search for any
  player name containing the string "flux".

* asn        \<player\_name\> | \<IP\>

  Look up the network of a player (currently connected or not) or
  an IP.

* cluster    \<player\_name\>

  Get a list of other player accounts that have used an IP that
  the given player has used.

* status     \<player\_name\> [\<number\>=20]

  Get the most recent status changes for a player.

* inspect    \<player\_name\>

  Get a list of IPs and networks associated with a player.

* logins     \<player\_name\> [\<number\>=20]

  View the most recent login info of a player.
  
* alts       \<player\_name\>

  List the registered alt accounts associated with a player. 

* ban\_record \<player\_name\>

  Get a summary of important information about a player, including
  other accounts associated by IP, flagged accounts associated by network,
  and their status log.

# Player management

Commands to change the status of a player.

* kick        \<player\_name\> [\<reason\>]

  Kick a player from the server. Kicks go into the player's status log,
  but do not alter the player's status.

* ban         \<player\_name\> [\<timespan\>] [\<reason\>]

  Ban a player. If a timespan is given e.g. 3d (three days) or 1w (one week) 
  then the ban is temporary, and will expire after the given time. Banning
  has the side effect of marking the most recently used IP of the player as suspicious.

* unban       \<player\_name\> [\<reason\>]

  Unban a player.

* suspect     \<player\_name\> [\<reason\>]

  Mark a player as suspicious. Suspicious players have the same privileges as
  regular players, but certain actions e.g. logging in, are reported to 
  verbana staff.  

* unsuspect   \<player\_name\> [\<reason\>]

  Remove a player's suspicious status.

* verify      \<player\_name\> [\<reason\>]

  Verify an unverified player.

* unverify    \<player\_name\> [\<reason\>]

  Reset a player's "unverified" status. This will revoke their ability to interact
  or communicate with non-staff players. If a verification jail is defined, the player
  will be returned to the verification jail.

* whitelist   \<player\_name\> [\<reason\>]

  An admin command. Mark a certain account as whitelisted, which allows
  it to bypass the suspicious network checks at login.

* unwhitelist \<player\_name\> [\<reason\>]

  Remove a player's whitelisted status.

## Managing account clusters

* master     \<alt\> \<master\>

  Associate an alt account with a master account. 

* unmaster  \<player\_name\>

  Remove the associated master account for a given alt. 

* unflag    \<player\_name\>

  Remove the "flag" from an account.

# IP inspection

* ip\_inspect \<IP\> [\<timespan\>=1w]

  List players and statuses associated with an IP.

* ip\_status  \<IP\> [\<number\>]

  List the status of an IP.

# IP management
* ip\_block     \<IP\> [\<timespan\>] [\<reason\>]

  Block an IP, with an optional timespan. No connections from this IP will
  be allowed.
  
* ip\_unblock   \<IP\> [\<reason\>]

  Unblock an IP.

* ip\_suspect   \<IP\> [\<reason\>]

  Mark an IP as suspicious. New players connecting from this IP will
  be forced to go through manual verification.

* ip\_unsuspect \<IP\> [\<reason\>]

  Remove the supicious status from an IP.

* ip\_trust     \<IP\> [\<reason\>]

  Mark an IP as trusted. Connections from a trusted IP that is part of a suspicious
  network will bypass the suspicious network checks.

* ip\_untrust   \<IP\> [\<reason\>]

  Unmark an IP as suspicious.

# ASN inspection
* asn\_inspect \<ASN\> [\<timespan\>=1y]

  Show flagged accounts associated with the network. 

* asn\_status  \<ASN\> [\<number\>]

  Show the status log for the network.

* asn\_stats   \<ASN\>

  Show some statistics for the usage of the network.

# ASN management
* asn\_block     \<ASN\> [\<timespan\>] [\<reason\>]

  Block all connections from the network.

* asn\_unblock   \<ASN\> [\<reason\>]

  Unblock connections from the network.

* asn\_suspect   \<ASN\> [\<reason\>]

  Mark the network as suspicious.

* asn\_unsuspect \<ASN\> [\<reason\>]

  Unmark the network as suspicious.
