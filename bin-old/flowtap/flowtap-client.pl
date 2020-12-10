#!/usr/bin/env perl 
##!/usr/bin/perl -w
# COPYRIGHT AND LICENSE
# Copyright (c) 2006-2007, Juniper Networks, Inc.  
# All rights reserved.  
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are
# met:
#       1.      Redistributions of source code must retain the above
# copyright notice, this list of conditions and the following
# disclaimer. 
#       2.      Redistributions in binary form must reproduce the above
# copyright notice, this list of conditions and the following disclaimer
# in the documentation and/or other materials provided with the
# distribution. 
#       3.      The name of the copyright owner may not be used to 
# endorse or promote products derived from this software without specific 
# prior written permission. 
# THIS SOFTWARE IS PROVIDED BY THE AUTHOR ``AS IS'' AND ANY EXPRESS OR
# IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
# WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
# DISCLAIMED. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY DIRECT,
# INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
# (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
# SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
# HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT,
# STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING
# IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
# POSSIBILITY OF SUCH DAMAGE.
#
# flowtap-client.pl -- flow-tap-dtcp test client
#
# Spawn ssh connection and send dtcp command. 
#
#
use lib qw(. /homes/xwu/lib /volume/labtools/lib);
use Expect;
use Digest::HMAC_SHA1 qw(hmac_sha1 hmac_sha1_hex);
 
if ($#ARGV < 3) {
    die("Usage: flowtap-client.pl <router> <user_name> <password> <input_file> [dtcp_seq_number]\n");
}
 
my $exp = new Expect;
 
my $router = $ARGV[0];
my $user = $ARGV[1];
my $password = $ARGV[2];
my $input_file = $ARGV[3];
my $seq_num = $ARGV[4];
my $command = "ssh -l $user -p 32001 $router -s flow-tap-dtcp";
my $key = "Juniper";
my $digest;
my $hexdata;
my $dtcp_cmd = "";
my $opt_seq_num = 0;
my $seq_num_found_int_file = 0;
 
if ($seq_num eq "") {
   $seq_num = "1";
} else {
   $opt_seq_num = 1;
}
print "$command\n";
print "My PID: $$\n";
print "Press xx to exit out of flowtap client\n";

open PID_FILE, ">flowtap_$router.pid";
print PID_FILE "$$\n";
close PID_FILE;


$exp->raw_pty(1);
$exp->spawn($command) or die "Cannot spawn $command: $!\n";
 
$exp->expect(15, '-re', "assword:");
$exp->send("$password\n");
sleep 3;
print "\n";
 
open(DAT, $input_file) || die("Could not open file!");
@raw_data=<DAT>;
 
print "start processing input file\n";
foreach $line (@raw_data)
{
    print "get a line: $line";
    chomp($line);
    if ($line eq "") {
        if ($opt_seq_num || !$seq_num_found_int_file) {
            # Add DTCP Sequence number
            $dtcp_cmd = $dtcp_cmd . "Seq: " . $seq_num . "\r\n";
        }

        $digest = hmac_sha1($dtcp_cmd, $key);
 
        # converts binary to hex
        $hexdata = unpack("H*", $digest);
 
        $dtcp_cmd = $dtcp_cmd . "Authentication-Info: " . $hexdata . "\r\n\r\n";
        print "Sending DTCP cmd:\n" . $dtcp_cmd;
        $exp->send($dtcp_cmd);
        $dtcp_cmd = "";
        sleep 1;
    } else {
        if ($line =~ m/^seq:*/i) {
            $seq_num_found_int_file = 1;
            if (!$opt_seq_num) {
                $dtcp_cmd = $dtcp_cmd . $line . "\r\n";
            }
        } else {
            $dtcp_cmd = $dtcp_cmd . $line . "\r\n";
        }
    }
}
my $x;

# Press xx to exit out of interact
$exp->interact($x, 'xx');
