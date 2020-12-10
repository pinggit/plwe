#!/usr/bin/perl
###############################################################################
use diagnostics;
use Net::Telnet;
#use strict;
#use warnings;
##############################################################################
my $user = "Juniper";
my $pass = "Juniper";

###############################################################################
my $host = undef;
if ( $0 =~m/jnpr-fabric-drops_(.+)*$/) {
        $host = $1;
}
exit 2 unless defined $host;
###############################################################################
## Initiate Telnet Session
my $t = Net::Telnet->new(Prompt  => '/\#/',
                         Timeout => 10);

###############################################################################
if ($ARGV[0] and $ARGV[0] eq "config") {
  print "host_name " . $host . "\n";
  print "graph_args --base 1000 -l 0 -r --lower-limit 0\n";
  print "graph_scale no\n";
  print "graph_title Fabric Drops in PR-VIOCE [SLOT5]\n";
  print "graph_category network\n";
  print "graph_info This graph shows fabric-queue PR-VOICE COMMITED drops and fwd packets for EGRESS SLOT 5\n";
  print "DropppedBytes.label PR-VOICE Dropped (Bytes)\n";
  print "DropppedBytes.type GAUGE\n";
  print "DropppedBytes.draw AREA\n";
  print "DropppedPackets.label PR-VOICE Dropped (pkts)\n";
  print "DropppedPackets.type GAUGE\n";
  print "DropppedPackets.draw AREASTACK\n";
  exit;
}

###############################################################################

$t->open($host);
$t->login($user, $pass);
$t->cmd('term length 0');
my @array = $t->cmd('show fabric-queue traffic-class PR-VOICE egress-slot 5');
my ($COMFWDPKT, $COMFWDBYTES,$COMDROPPKT,$COMDROPBYTES) = undef;
  foreach my $Line (@array) {
    if ($Line =~ m/^PR-VOICE.*committed\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)/) {
      $COMFWDPKT = $1;
      $COMFWDBYTES = $2;
      $COMDROPPKT = $3;
      $COMDROPBYTES = $4;
    }
    }
print "DropppedBytes.value " . $COMDROPBYTES . "\n";
print "DropppedPackets.value " . $COMDROPPKT . "\n";
$t->close;
