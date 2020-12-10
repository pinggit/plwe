set a "
    set aa 123
    set bb 456
"
eval $a
puts "a is:\n$a"
puts "now eval \$a"
eval $a
puts "aa is $aa;bb is $bb"

