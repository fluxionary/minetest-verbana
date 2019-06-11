Verbana: Verification and banning mod for minetest
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
the BlockySurvival server. When enabled, it requires all new players to be
verified by a player with moderator privileges before they can interact with
the server or communicate with non-moderator players.

The flaws in the verification mod are
1. Moderators are not always online to verify new players.
2. New players come from all over the world, and may not be able to communicate
   with the moderator.
3. New players are of all ages, and may not be able to communicate in chat at
   all.

Verbena aims to provide name-based banning, as well as ip and network based
blocking and verification.
1. IPs and Networks may be marked as "untrusted" - all new players from
   untrusted IPs/networks must go through verification, while other new
   players may join at will.
2. IPs and Networks may be blocked or temporarily blocked, should the need
   arise.
3. There is a three tiered privilege system: Normal players, moderators,
   and admins. Moderators may ban and verify players, but only admins have
   the ability to mark IPs and networks as untrusted. This way, player's
   personal details may be kept private. However, operators may execute queries-
   to determine if a player is associated with other banned players by IP or
   network.

Some features of sban that the first release of Verbana will likely lack:
* A GUI. The sban GUI does not work particularly well anyway, and I don't know formspec. Use commands.
* Import/export from various other ban formats. I plan to import data from sban, but I don't have a use case for the rest.

Requirements
============

* Verbana must be listed as a trusted mod in minetest.conf (`secure.trusted_mods`)
* lsqlite3 (SQLite3 for Lua) must be installed and accessible to minetest's Lua.
 * The easiest way I know how to do this: install luarocks, and execute `sudo luarocks --lua-version 5.1 install lsqlite3`
* The minetest server must use IPv4 exclusively. I've made zero attempt to support IPv6.



