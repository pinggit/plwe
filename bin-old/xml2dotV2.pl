#! /usr/bin/perl

# This script converts the output from 
# "show ospf database router extensive | display xml | no-more" 
# or
# "show isis database detail | display xml | no-more" 
# into .dot graph format
# for visualization using graph tools like graphviz, gephi etc

# Set to the level you want to graph
my $level = "2";
 
#v1.1 Added metric to edges.  Comment out if it gets too cluttered.
#v2.0 Added IS-IS support.  Will graph anything it finds, does not filter out levels.
#    Beware of pseudonodes.  An ethernet link that is not configured as p2p will show as
#    a pseudonode, with one link to each real router, whith the non zero metric.
#    In this graph we show the link once, so it could appear that the metric is double 
#    We draw the metric TO the pseudonode, but the metric FROM the pseudonode is 0.
#    Pseudonodes show as dots in the drawing.  Metrics have a *

use strict;
my $thisline;			#line being analyzed
my $advrouter;			#router ID
my $destrouter;			#dest router
my $metric; 			#cost
my $linktype;			#Flag set if link is point to point
my $protocol; 			#OSPF or ISIS
my %names;

#Check if a host file is provided (for OSPF RID->name mapping only)

if ($ARGV[0]) {
	open FILE, $ARGV[0] or die $!;
	while (<FILE>) {
		$_ =~ '([0-9a-fA-F\.\:]+)[\s\t]+([a-zA-Z0-9]+)';
		$names{$1} = $2;	#add to hash
	}
}

#Now, try to find if this is an OSPF database, or IS-IS

$protocol = "";

while($protocol eq "") {
	$thisline = <STDIN>;
	if($thisline =~ /(....).database\-information/) {
		$protocol = $1;
	}
}


if ($protocol eq "ospf") {

	#print "digraph ospf_net \{\n";    	#Directed Graph. Good for TE for example.
	print "graph ospf_net \{\n";	

	# Process line by line, replace rids with names if available
	while(<STDIN>) {	
		$thisline = $_;
		if($thisline =~ '<advertising-router>([a-zA-Z0-9\.\:]+)') {
			$advrouter = $1;
			if(exists $names{$advrouter}) {
				$advrouter = $names{$advrouter};
			}
		} elsif ($thisline =~ '<bits>0x([0-9]+)') {
			#Check if ABR, ASBR or both or some other bit set
			if($1 eq '0') {
				print "\t\"$advrouter\" [fontsize = 8, shape=box];\n";	
			} else {
				print "\t\"$advrouter\" [fontsize = 8, shape=oval];\n";
			}
		} elsif ($thisline =~ '<link-id>([0-9a-fA-F\.\:]+)') { 
			$destrouter = $1;
			if(exists $names{$destrouter}) {
				$destrouter = $names{$destrouter};
			}
		} elsif ($thisline =~ '<link-type-name>([a-zA-Z]+)') {
			$linktype = $1;
		} elsif ($thisline =~ '<metric>([0-9]+)') {
			$metric = $1;
		} elsif ($thisline =~ '/ospf-link') {
			if ($linktype eq 'PointToPoint') {
				#To print only one direction just compare the strings
				#This doesn't mean anything, but ony one direction will be printed
				if ($advrouter gt $destrouter) {
					print "\t\"$advrouter\" -- \"$destrouter\" [fontsize = 8, label = $metric, weight = $metric];\n"; #With metric
					#print "\t\"$advrouter\" -- \"$destrouter\";\n";			   #Without metric
				}
			}
		}
	}
} elsif ($protocol eq "isis") {

	print "graph isis_net \{\n";	
	$destrouter = "";

	while(<STDIN>) {	
		$thisline = $_;
		if($thisline =~ '<lsp\-id>([a-zA-Z0-9\.\-]+0[0-9])(-0[0-9])') {
			$advrouter = $1;
			$destrouter = "";
			if($advrouter =~ /0[1-9]$/) {
				#We are here if this is pseudonode
				print "\t\"$advrouter\" [shape=point, fontsize = 8];\n";
			} else {
				print "\t\"$advrouter\" [shape=oval, fontsize = 8];\n";
			}
		} elsif ($thisline =~ 'is\-neighbor\-id\>([a-zA-Z0-9\.\-]+)') { 
			$destrouter = $1;
		} elsif ($thisline =~ '<metric>([0-9]+)') {
			$metric = $1;
			if ($destrouter ne "") {   #Should enter here if this metric belongs to a neighbor
				#Check if this is a pseudonode LSP
				if ($advrouter =~ /0[1-9]$/) {	#This is a pseudonode LSP (metric 0), do not draw
					#Don't do anything
				} elsif ($destrouter =~ /0[1-9]$/) { #This link goes to pseudonode, draw it
					print "\t\"$advrouter\" -- \"$destrouter\" [fontsize = 8, label = \"$metric*\", weight = $metric, color = gray] ;\n"; #With metric
					#print "\t\"$advrouter\" -- \"$destrouter\";\n";			   #Without metric
				} elsif ($advrouter gt $destrouter) {   #No pseudonode involved, we graph one direction only		
					print "\t\"$advrouter\" -- \"$destrouter\" [fontsize = 8, label = $metric, weight = $metric];\n"; #With metric
					#print "\t\"$advrouter\" -- \"$destrouter\";\n";			   #Without metric
				}
				$destrouter = "";
			}
		} 
	}	
}

#close 
print "}\n";
