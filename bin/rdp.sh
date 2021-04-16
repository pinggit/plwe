
case $1 in
    radius )	address="172.25.84.169"
    		user=Administrator
		pass=herndon1
		;;

    testers )	address="172.25.84.218"
    		user=lab
		pass=lab
		;;

    winxp ) 	address="172.25.83.84"
    		user=pings
		pass=123	
		;;
    *|\? )	
		#echo -e "wrong usage!\nusage:rdp radius|testers|winxp\n"
		address=$1
		;;
esac

#rdp to the servers
rdesktop -u $user -p $pass -f -r clipboard:PRIMARYCLIPBOARD -r disk:work=~/work/ $address & 

