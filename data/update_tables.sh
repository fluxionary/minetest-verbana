#!/usr/bin/env bash
wget -O -              http://thyme.apnic.net/current/data-used-autnums | iconv -o data-used-autnums -f iso-8859-1 -t utf-8

wget -O data-raw-table http://thyme.apnic.net/current/data-raw-table
wget -O ipv6-raw-table https://thyme.apnic.net/current/ipv6-raw-table
