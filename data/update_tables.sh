#!/usr/bin/env bash
wget -O -              http://thyme.apnic.net/current/data-used-autnums | iconv -o used-autnums -f iso-8859-1 -t utf-8

wget -O ipv4-raw-table http://thyme.apnic.net/current/data-raw-table
wget -O ipv6-raw-table https://thyme.apnic.net/current/ipv6-raw-table
