#!/bin/sh 

if [ "$1" = "" ]; then
  echo "Specify an asciidoc file"
  exit
fi

TARGET=`basename $1 .txt`.html

handleimages.py $1 | asciidoc -d book -o $TARGET - 
