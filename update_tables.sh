#!/usr/bin/env bash
wget -O data-raw-table http://thyme.apnic.net/current/data-raw-table
wget -O -              http://thyme.apnic.net/current/data-used-autnums | iconv -t utf-8 -f iso-8859-1 > data-used-autnums
