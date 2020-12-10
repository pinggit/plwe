
findRandomTcpPort(){
        port=$(( 100+( $(od -An -N2 -i /dev/random) )%(1023+1) ))
        while :
        do
                (echo >/dev/tcp/localhost/$port) &>/dev/null &&  port=$(( 100+( $(od -An -N2 -i /dev/random) )%(1023+1) )) || break
        done
        echo "$port"
}
 
p=$(findRandomTcpPort)
p=`expr $p + 50000`

#ssh -fNL10122:192.168.45.227:22 scooby2
ssh -fNL$p:$1:22 scooby2
#sshfs -p 10122 j-tac-nz1@localhost:/ $2
cd ~/mnt/att-router/
mkdir $2
sshfs -o idmap=user -p $p $3@localhost:/ $2
cd ~/mnt/att-router/$2

