#!/bin/bash
zip -jq - $1 | uuencode $1.zip | mail -s "file:$1.zip" $2
