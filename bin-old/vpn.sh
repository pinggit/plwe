#!/bin/bash
PIN=0000
token=$1
jvpn -s americas -r RSA-Employee -u pings -p $PIN$token --cache --curses
