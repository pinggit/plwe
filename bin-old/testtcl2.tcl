#!/usr/bin/env expect
puts "argv is $argv"
set argvar [join $argv :]
set argvar ":$argvar:"
puts "argvar is $argvar"
set match_e_s [regexp -all -inline {:-e:(\S+):-s:(.*):} $argvar]
puts "match_e_s is $match_e_s"
