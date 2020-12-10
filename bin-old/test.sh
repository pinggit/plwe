#!/bin/bash
cat "$1" | uuencode "$1" | mail -s "file:$1, from ping's PC" $2
