Verbana: Verification and banning mod for Minetest
==================================================

CURRENTLY A NON-FUNCTIONAL WIP. DO NOT USE UNTIL THIS MESSAGE HAS BEEN REMOVED.

Name
----
A portmanteau of "verification", "ban", and the herb verbena.

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

Setup
=====

If you don't know the basics of installing a minetest mod, please see
* https://wiki.minetest.net/Installing_Mods
* https://dev.minetest.net/Installing_Mods

Verbana must be marked as a trusted mod, with a line like the following added to
minetest.conf:
```secure.trusted_mods = verbana``` 

The only "trusted" thing verbana does is load lsqlite so that it can interact with
its database. To our knowledge, verbana cannot leak the insecure environment, but 
it can leak the lsqlite interface in minetest 5.0.1 and development versions 





--------------
list of commands for documentation:

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
