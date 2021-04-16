#!/usr/bin/perl

# Copyright (c) 2003-2008 Juniper Networks Inc.  All rights reserved.
#
# Change history:
#  2003/08/01 - ckim - add uidToNameTable.cfg decode.
#  2003/07/31 - ckim - Initial coding.
#  2008/04/21 - ckim - added Disclaimer (by DDugal), comment out cfgsToListIndex
#  2008/06/23 - ckim - cfg file decoder included
#  2008/08/25 - ckim - perl version dependance notes
#  2009/11/09 - ckim - excludeList.cfg added
#  2010/10/13 - ckim - fixed the case of TS may have minus number
#  2010/11/08 - ckim - fixed non-30,40,50 part
#  2011/03/21 - ckim - log.cfg didnt have signature in e320_9-3-3p0-2-1.rel (case 2011-0321-0041)
#
# Disclaimer:
#  Juniper Networks is providing this script on an "AS IS" basis.
#  No warranty or guarantee of any kind is expressed in this script and none
#  should be implied. Juniper Networks expressly excludes and disclaims any
#  warranties regarding this script or materials referred to in this script,
#  including, without limitation, any implied warranty of merchantability,
#  fitness for a particular purpose, absence of hidden defects, or of
#  noninfringement. Your use or reliance on this script or materials referred
#  to in this script is at your own risk.
#
#  Juniper Networks may change this notice or script at any time.
#

#
# Perl dependancy:
#  version 5.8 works fine
#  verison 5.0 had some problem
#

########
use integer ;
#use strict;
#
package cnfFile;

use constant DATA_SIGNATURE => 0xabbadaba ;
use constant MIN_HD_SIZE => 73 ;
#
#
%cfgsToSave = ();
#%cfgsToSave = ("ipLocAddrCommonHybridData.cfg","excludeList.cfg");
#%cfgsToListIndex = ( "atm1483DataServiceCircuits.cfg", 1 );
%cfgsToListIndex = ();
#
# printIndex( $id, $count );
sub printIndex {
    my ($id, $count) = @_ ;
    my $flag = unpack( "C", substr($id, 0, 1) );
    printf "%02x ", $flag ;
    for( my $i = 1 ; $i < length $id ; $i++ ){
      printf "%02x", unpack( "C", substr( $id, $i, 1 ) ) ;
    }
    print " - $count entries" if $count ;
    print " #this is deleted, but abnormal" if( not ( ( $flag == 0 ) or ($flag == 0x7f) or ($flag == 0xff) ) ) ;
    print "\n" ;
}

sub printDupIds {
  my ($self, $data, $data_len, $kl, $el, $cfgName, $toList, $cfg) = @_ ;
  my %ids = () ;
  my %oops = () ;
  my $entries = 0;
  for( my $i = 16 ; $i < $data_len ; $i += $el ){
    $id = substr( $data, $i, $kl + 1 );
    printIndex($id) if( $toList );
    $entries++;
### uncomment this to list keys
#  printIndex($id, 0);
# zero of bit 0 (0x00 - 0x7f) means it is deleted.
    next if ord($id) == 0x7f ;
    next if ord($id) == 0x00 ;
    if( exists $ids{$id} ) {
      $ids{$id}++ ;
      $oops{$id} = $ids{$id};
    } else {
      $ids{$id} = 1;
    }
  }
  print "total $entries entries.\n" if( $cfg eq "cfg" ) ;

  @ks = keys( %oops );
  if( $#ks != -1 ){
    print "!!!!!!!! $cfgName: " if($cfg eq "cnf" ) ;
    printf "%d duplicate ids.\n", $#ks + 1 ;
    for my $id (sort keys %oops) {
      printIndex($id, $oops{$id});
    }
  } else {
    print "no duplicate keys.\n" if( $cfg eq "cfg" );
  } 
}

sub readHd {
  my $self = shift;
  my $lineBuf = "";
  my $hdBuf = "";
###  print "-" x 20 . "\n" ;
# Hd Sz  105\nVer 1 0\nTS 1058436706\nTyp 0\nIs cl 1\nBHd Sz   74\nD Sz    58980\n
  $self->{rtnSz} = MIN_HD_SIZE ;
  return "Error: Hd Read, $self->{leftSz} left"
    if(MIN_HD_SIZE != read( $self->{fd}, $hdBuf, MIN_HD_SIZE )) ;
# 2010/10/13 TS changed from (\d+) to ([-\d]\d+)
  if( $hdBuf =~ /Hd Sz\s+(\d+)\nVer 1 0\nTS ([-\d]\d+)\nTyp 0\nIs cl (\d)\nBHd Sz\s+(\d+)\nD Sz\s+(\d+)\n/ ){
    $self->{HdSz} = $1 ; $self->{TS} = $2 ; $self->{Iscl} = $3 ; $self->{BHdSz} = $4 ; $self->{DSz} = $5 ;
    if( ($self->{BHdSz} < MIN_HD_SIZE) || ($self->{HdSz} < $self->{BHdSz}) || ($self->{Iscl} > 1)
     || ($self->{DSz} < 12 ) ){
      return "Error:[B Hd data" ;
    }
  } else { return "Hd Fmt Error" ; }
#
  read( $self->{fd}, $lineBuf, $self->{BHdSz} - MIN_HD_SIZE );
  $self->{rtnSz} = $self->{BHdSz} ;
  chomp($lineBuf);
  $self->{cfgName} = $lineBuf ;
###  printf "%x %.8d %s\n", $self->{TS}, $self->{DSz}, $self->{cfgName};
#
  if( $self->{Iscl} == 1 ){
    read( $self->{fd}, $lineBuf, $self->{HdSz} - $self->{BHdSz} );
###    print $lineBuf;
    $self->{rtnSz} = $self->{HdSz} ;
    $self->{cnfSz} = $self->{leftSz} = $self->{DSz} ;
    $self->{unresCnt} = 0;
    $self->{warnMsg} = "";
    return "OK";
  }
# cfg name
  bless $self;
  return readData($self);
}
###############
use constant MIN_DATA_SIZE => 12 ;
#
sub readData {
  my $self = shift ;
  return "Error: Data size" if( $self->{DSz} < MIN_DATA_SIZE ) ;
  $self->{rtnSz} = $self->{DSz} + $self->{HdSz} + 2 ;
  $self->{leftSz} -= $self->{rtnSz};
  return "Error: Read Data"
    if(read( $self->{fd}, $self->{dBuf}, ($self->{DSz}+2)) != ($self->{DSz}+2)) ;
  ($self->{sign}, $self->{s1}, $self->{s2}, $self->{n1})
    = unpack( "NnnN", substr($self->{dBuf}, 0, MIN_DATA_SIZE) );

  $self->{cfgCode} = $self->{cfgName} ;
  $self->{cfgCode} =~ s/[\/.]/_/g ;

# save corrupted files
# if( $self->{sign} != DATA_SIGNATURE ){
# save specific files 
  if(exists $cfgsToSave{$self->{cfgName}}) {
      open( BADFILE, ">$self->{cfgCode}" ) ;
      syswrite BADFILE, $self->{dBuf} ;
      close BADFILE ;
  } 

  if( $self->{cfgName} eq "coreDump.cfg" ){
#00 00 00 04 00 00 01 3C 00 00 02 02 00 00 00 02
      for( my $j = 0 ; $j < 40 ; $j += 4){
###        printf "%08x ", unpack( "N", substr( $self->{dBuf}, $j, 4 ) );
      }
###      print "\n" ;
    return "OK" ;
  }

  if( $self->{cfgName} eq "excludeList.cfg" ){
###   print "excludeList: \n$self->{dBuf}\n" ;   
    return "OK" ;
  }

  if( $self->{cfgName} eq "log.cfg" ){
# 2011/03/21 ckim - log.cfg didnt have signature in e320_9-3-3p0-2-1.rel (case 2011-0321-0041)
    return "OK" ;
  }

# check signature
  printf "Error: Data signature (0x%08x) for $self->{cfgName}\n", $self->{sign} if $self->{sign} != DATA_SIGNATURE ;
# print 2 long words
###  printf "%04x %04x %08x($self->{n1})", $self->{s1}, $self->{s2}, $self->{n1} ;
### 2010/11/8 fixed to compare from 0x3000 to 0x30
  if( ( $self->{s1} / 0x100 ) == 0x30 ){
    $self->{idSize} = unpack( "N", substr( $self->{dBuf}, 12, 4 ) ) ;
    $self->{rsize} = $self->{n1} + $self->{idSize} + 1;
###    printf " : id size = %04x($self->{idSize})\n", $self->{idSize} ;
### 2010/11/8 fixed to compare from 0x5000 to 0x50
  } elsif( ( $self->{s1} / 0x100 ) == 0x50 ){
    $self->{idSize} = 0 ;
    $self->{rsize} = $self->{n1} + $self->{idSize} + 1;
###    print "\n" ;
### 2010/11/8 fixed to compare from 0x4000 to 0x40
  } elsif( ( $self->{s1} / 0x100 ) == 0x40 ){
    $self->{idSize} = 0 ;
    $self->{rsize} = $self->{n1} + $self->{idSize} ;
###    print "\n" ;
  } else {
    print "ERROR: non-30,40,50 for $self->{cfgName}\n"
  }
#
#
###  return hostmap_cfg($self) if( $self->{cfgName} =~ /^hostmap\// ) ;


###  return &{$self->{cfgCode}}($self) if( defined &{$self->{cfgCode}} ) ;
#
###  $self->{unResolved} .= "$self->{cfgName} ";
###  $self->{unresCnt} ++ ;
  if( $self->{s1} == 0x3000 ){
    my $cfgName = $self->{cfgName} ;
    my $toList = exists $cfgsToListIndex{$cfgName} ;
#    my $toList = 1 ;
    print "Listing Index of $cfgName\n" if( $toList ) ;

    my %ids = () ;
#    my $idSize = $self->{idSize} ;
    my %oops = () ;

    $self->printDupIds( $self->{dBuf}, $self->{DSz}, $self->{idSize}, $self->{rsize}, $cfgName, $toList, "cnf" );
  }
  return "OK" ;
}

########################
#
sub printDel {
    my $aFlag = shift;
    if($aFlag == 0xff){
        print "  " ;
    } elsif($aFlag == 0x7f){
        print "--" ;
    } else {
        printf "%02x", aFlag ;
    }
}
########################
#system.cfg
#cli.cfg
sub cli_cfg {
#AB BA DA BA 30 00 00 0b 00 00 00 98 00 00 00 02
  $self = shift;
  for( my $i = 16; $i < $self->{DSz} ; $i += $self->{rsize} ){
    my($ff, $id, $unknown) = unpack( "CnA$self->{n1}", substr( $self->{dBuf}, $i, $self->{rsize} ) );
    printDel($ff) ;
    printf "<%04x> ", $id ;
    for( my $j = 0 ; $j < 80 ; $j += 4){
      printf "%08x ", unpack( "N", substr( $unknown, $j, 4 ) );
    }
    print "\n" ;
#    my($lw1, $str1, $bw1, $str2) = unpack( "NZ20CZ15", $unknown );
#    printf "%x \"$str1\" %x \"$str2\"\n", $lw1, $bw1 ;
  }
  return "OK" ;
}

#cliVtyCfg.cfg
#cliMisc.cfg
#cliXyzzy.cfg
#console.cfg
sub console_cfg {
#AB BA DA BA 30 00 00 02 00 00 00 08 00 00 00 04
  $self = shift;
  for( my $i = 16; $i < $self->{DSz} ; $i += $self->{rsize} ){
    my($ff, $id, $v1, $v2) = unpack( "CNNN", substr( $self->{dBuf}, $i, $self->{rsize} ) );
    printDel($ff) ;
    printf "<%08x> %08x %08x\n", $id, $v1, $v2 ;
  }
  return "OK" ;
}

#httpd.cfg
#lineAttrib.cfg
#log.cfg
sub log_cfg {
#AB BA DA BA 30 00 00 04 00 00 00 01 00 00 00 20
  $self = shift;
  for( my $i = 16; $i < $self->{DSz} ; $i += $self->{rsize} ){
    my($ff, $id, $val)
      = unpack( "CA32C", substr( $self->{dBuf}, $i, $self->{rsize} ) );
    next if($val == 0xe3) ;
    printDel($ff) ;
    my $sev = $val / 16 ;
    print "log sev $sev $id\n" ;
    print "log ber high $id\n" if($val & 0x08) ;
  }
return "OK" ;
}

#logFilters.cfg
#logMeta.cfg
#nvs.cfg
#syslog.cfg
#syslogSources.cfg
#timezone.cfg
#uidToNameTable.cfg
sub uidToNameTable_cfg {
#AB BA DA BA 30 00 0F A0 00 00 02 00 00 00 00 04
#AB BA DA BA 30 00 00 00 00 00 01 00 00 00 00 04
  my $self = shift;
  for( my $i = 16; $i < $self->{DSz} ; $i += $self->{rsize} ){
    if( $self->{n1} == 0x0200 ){ # $self->{s2} = 0x0fa0
      my($ff, $id, $name, $desc)
        = unpack( "CNZ256Z256", substr( $self->{dBuf}, $i, $self->{rsize} ) );
      printDel($ff) ;
      printf "<%08x> \"%s\" \"%s\"\n", $id, $name, $desc ;
    } elsif( $self->{n1} == 0x0100 ){ # $self->{s2} = 0x0000
      my($ff, $id, $name)
        = unpack( "CNZ256", substr( $self->{dBuf}, $i, $self->{rsize} ) );
      printDel($ff) ;
      printf "<%08x> \"%s\"\n", $id, $name ;
    } else { # unknown
      $self->{warnMsg} .= "uidToNameTable.cfg - unknown leng ($self->{n1})\n" ;
      my($ff, $id, $name)
        = unpack( "CNZ256", substr( $self->{dBuf}, $i, $self->{rsize} ) );
      printDel($ff) ;
      printf "<%08x> \"%s\"\n", $id, $name ;
    }    
  }
  return "OK" ;
}

#vtyBanners.cfg
#coreDump.cfg
#IkeConfigurationParameters.cfg
#TmSeed.cfg
#TmTbl.cfg
sub TmTbl_cfg {
#AB BA DA BA 30 00 0F A0 00 00 02 00 00 00 00 04
  $self = shift;
  for( my $i = 16; $i < $self->{DSz} ; $i += $self->{rsize} ){
    my($ff, $nameLeng, $name, $id)
      = unpack( "CNZ80N", substr( $self->{dBuf}, $i, $self->{rsize} ) );
    printDel($ff) ;
    printf "($nameLeng) $name <%08x>\n", $id ;
    $self->{warnMsg} .= "TmTbl.cfg leng too long ($nameLeng)\n"
      if( $nameLeng > 80 );
# $id will be used for pppProfiles.cfg ...
  }
  return "OK" ;
}

#aaa/aaaBrasLicenseFile.cfg
#aaa/aaaDomainToRouterConfigFile.cfg
sub aaa_aaaDomainToRouterConfigFile_cfg {
#AB BA DA BA 30 00 00 15 00 00 03 68 00 00 00 40
  $self = shift;
  for( my $i = 16; $i < $self->{DSz} ; $i += $self->{rsize} ){
    if( $self->{s2} == 0x15 ){ # $self->{n1} == 0x0368
      my($ff, $domainId, $vRouter, $ext, $loo)
        = unpack( "CA64A64A450A4", substr( $self->{dBuf}, $i, $self->{rsize} ) );
      printDel($ff) ;
      print "aaa domain $domainId virtual-router $vRouter loopback $loo\n" ;
    } else {
      $self->{warnMsg} .= "aaa/aaaDomainToRouterConfigFile.cfg - unknown ver ($self->{s2})\n" ;
      my($ff, $domainId, $vRouter)
        = unpack( "CA64A64", substr( $self->{dBuf}, $i, $self->{rsize} ) );
      printDel($ff) ;
      print "aaa domain $domainId virtual-router $vRouter\n" ;
    }
  }
return "OK" ;
}

#aaa/aaaGlobalConfigFile.cfg
#aaa/aaaMethodConfigFile.cfg
#aaa/aaaMorePerServerConfigFile.cfg
#aaa/aaaPerServerConfigFile.cfg
#aaa/aaaPerSessionConfigFile.cfg
#aaa/aaaTunnelConfigFile.cfg
#aaa/ar1InterfaceConfigFile.cfg
#ar1CmCfgChecker.cfg
#ar1Ds1.cfg
#ar1Ds1Uid.cfg
#ar1Ds3.cfg
#ar1Ds3Uid.cfg
#ar1Ethernet.cfg
#ar1EthernetUid.cfg
sub ar1EthernetUid_cfg {
#AB BA DA BA 30 00 00 01 00 00 00 04 00 00 00 04
  $self = shift;
  for( my $i = 16; $i < $self->{DSz} ; $i += $self->{rsize} ){
    my($ff, $id, $v1) = unpack( "CNN", substr( $self->{dBuf}, $i, $self->{rsize} ) );
    printDel($ff) ;
    printf "<%08x> %08x\n", $id, $v1 ;
  }
  return "OK" ;
}

#ar1Hdlc.cfg
#ar1HdlcUid.cfg
#ar1Scm.cfg
#ar1ScmUid.cfg
#ar1Sonet.cfg
#ar1SonetUid.cfg
sub ar1SonetUid_cfg {
#AB BA DA BA 30 00 00 01 00 00 00 04 00 00 00 10
  $self = shift;
  for( my $i = 16; $i < $self->{DSz} ; $i += $self->{rsize} ){
    my($ff, $id1, $id2, $id3, $id4, $v1) = unpack( "CNNNNN", substr( $self->{dBuf}, $i, $self->{rsize} ) );
    printDel($ff) ;
    printf "<%08x-%08x-%08x-%08x> %08x\n", $id1, $id2, $id3, $id4, $v1 ;
  }
  return "OK" ;
}

#ar1System.cfg
#atm.cfg
#atm1483DataService.cfg
#atm1483DataServiceCircuits.cfg
#atm1483DataServiceInterfaces.cfg
#atm1483StaticMap.cfg
#atm1483StaticMapEntry.cfg
#atmAal5.cfg
#atmAal5Interfaces.cfg
#atmF4OamCircuit.cfg
#atmInterfaces.cfg
sub atmInterfaces_cfg {
#AB BA DA BA 30 00 0f a2 00 00 08 a0 00 00 00 04
  $self = shift;
  for( my $i = 16; $i < $self->{DSz} ; $i += $self->{rsize} ){
    my($ff, $id, $unknown) = unpack( "CNA$self->{n1}", substr( $self->{dBuf}, $i, $self->{rsize} ) );
    printDel($ff) ;
    printf "<%08x> ", $id ;
    for( my $j = 0 ; $j < 40 ; $j += 4){
      printf "%08x ", unpack( "N", substr( $unknown, $j, 4 ) );
    }
    print "\n" ;
  }
  return "OK" ;
}

#bgp/addressFamilies.cfg
sub bgp_addressFamilies_cfg {
#AB BA DA BA 30 00 0f a0 00 00 00 70 00 00 00 2c
  $self = shift;
  for( my $i = 16; $i < $self->{DSz} ; $i += $self->{rsize} ){
    my($ff, $vr, $strID, $l1, $l2, $unknown) = unpack( "CNA32NNA$self->{n1}", substr( $self->{dBuf}, $i, $self->{rsize} ) );
    printDel($ff) ;
    printf "<%08x-%32s-%08x-%08x> ", $vr, $strID, $l1, $l2 ;
    for( my $j = 0 ; $j < 12 ; $j += 4){
      printf "%08x ", unpack( "N", substr( $unknown, $j, 4 ) );
    }
    print "\n" ;
  }
  return "OK" ;
}

#bgp/aggregates.cfg
#bgp/bgp.cfg
#bgp/confederationPeers.cfg
#bgp/networks.cfg
#bgp/peerAfs.cfg
#bgp/peerGroupAfs.cfg
#bgp/peerGroups.cfg
#bgp/peers.cfg
#bgp/vrfs.cfg
sub bgp_vrfs_cfg {
#AB BA DA BA 30 00 10 04 00 00 00 38 00 00 00 28
  $self = shift;
  for( my $i = 16; $i < $self->{DSz} ; $i += $self->{rsize} ){
    my($ff, $vr, $strID, $l1, $unknown) = unpack( "CNA32NA$self->{n1}", substr( $self->{dBuf}, $i, $self->{rsize} ) );
    printDel($ff) ;
    printf "<%08x-%32s-%08x> ", $vr, $strID, $l1 ;
    for( my $j = 0 ; $j < 12 ; $j += 4){
      printf "%08x ", unpack( "N", substr( $unknown, $j, 4 ) );
    }
    print "\n" ;
  }
  return "OK" ;
}

#bridgedEthernet.cfg
#bridgedEthernetInterfaces.cfg
#bulkfiles.cfg
#bulkrsxfaces.cfg
#bulkscalar.cfg
#bulksels.cfg
#cacIntf.cfg
#cbf/cbf.cfg
#cbf/connections.cfg
#cbf/interfaces.cfg
#claclId.cfg
#cliAaaNewModel.cfg
#dcmProfAssign.cfg
#dhcp.cfg
#dhcpExAdd.cfg
sub dhcpExAdd_cfg {
#AB BA DA BA 30 00 00 00 00 00 00 04 00 00 00 0C
  $self = shift;
  for( my $i = 16; $i < $self->{DSz} ; $i += $self->{rsize} ){
    my($ff, $id, $l1, $l2, $l3) = unpack( "CNNNN", substr( $self->{dBuf}, $i, $self->{rsize} ) );
    printDel($ff) ;
    printf "<%08x> %08x %08x %08x\n", $id, $l1, $l2, $l3 ;
  }
  return "OK" ;
}

#dhcpPool.cfg
#dhcpPrx.cfg
#dhcpPrxConfig.cfg
#dhcpRel.cfg
sub dhcpRel_cfg {
#AB BA DA BA 30 00 00 02 00 00 00 08 00 00 00 08
  $self = shift;
  for( my $i = 16; $i < $self->{DSz} ; $i += $self->{rsize} ){
    my($ff, $id, $ip, $l1, $l2) = unpack( "CNA4NN", substr( $self->{dBuf}, $i, $self->{rsize} ) );
    printDel($ff) ;
    printf "<%08x-%s> 0x%x, 0x%x\n", $id, strIP($ip), $l1, $l2 ;
  }
  return "OK" ;
}

#dhcpRelConfig.cfg
#dhcpRsvdAdd.cfg
#dhcpSvr.cfg
#dnsClientResolverBindingGroup.cfg
#dnsConfigGroup.cfg
#dnsLocalDomainGroup.cfg
sub dnsLocalDomainGroup_cfg {
#AB BA DA BA 30 00 00 01 00 00 04 08 00 00 00 08
  $self = shift;
  for( my $i = 16; $i < $self->{DSz} ; $i += $self->{rsize} ){
    my($ff, $id1, $id2, $unknown) = unpack( "CNNA$self->{n1}", substr( $self->{dBuf}, $i, $self->{rsize} ) );
    printDel($ff) ;
    printf "<%08x-%08x> ", $id1, $id2 ;
    for( my $j = 0 ; $j < 40 ; $j += 4){
      printf "%08x ", unpack( "N", substr( $unknown, $j, 4 ) );
    }
    print "\n" ;
  }
  return "OK" ;
}

#dnsSbeltGroup.cfg
#ds1.cfg
#ds1Interfaces.cfg
#ds3.cfg
#ds3Interfaces.cfg
#dvmrpAclDistNbr.cfg
#dvmrpGlobalGrp.cfg
#dvmrpIfGrp.cfg
#dvmrpSummaryAddrGroup.cfg
#entPhysical.cfg
#ethernetInterfaces.cfg
sub ethernetInterfaces_cfg {
#AB BA DA BA 30 00 00 04 00 00 00 54 00 00 00 04
  $self = shift;
  for( my $i = 16; $i < $self->{DSz} ; $i += $self->{rsize} ){
    my($ff, $id, $unknown) = unpack( "CNA$self->{n1}", substr( $self->{dBuf}, $i, $self->{rsize} ) );
    printDel($ff) ;
    printf "<%08x> ", $id ;
    for( my $j = 0 ; $j < 40 ; $j += 4){
      printf "%08x ", unpack( "N", substr( $unknown, $j, 4 ) );
    }
    print "\n" ;
  }
  return "OK" ;
}

#ethernetSubInterfaces.cfg
#ethernetSubUidSeed.cfg
#ethernetVlanMajorUidSeed.cfg
#ethernetVlanSubUidSeed.cfg
#fileSysAgent.cfg
#fileSysAgentScalar.cfg
#frameRelay.cfg
#frameRelayBundle.cfg
#frameRelayCircuits.cfg
#frameRelayMajor.cfg
#frameRelayMajorInterfaces.cfg
#frameRelayMapClassInterfaces.cfg
#frameRelayMapClasses.cfg
#frameRelayMultilink.cfg
#frameRelayMultilinkInterfaces.cfg
#frameRelaySub.cfg
#frameRelaySubInterfaces.cfg
#ft1.cfg
#ft1Interfaces.cfg
#ftpClientSettings.cfg
#ftpServer.cfg
#hdlc.cfg
#hdlcHssiInterfaces.cfg
#hdlcInterfaces.cfg
#hdlcV35Interfaces.cfg
#hostmap/2147483649.cfg
sub hostmap_cfg {
#AB BA DA BA 30 00 00 03 00 00 00 80 00 00 00 30
  $self = shift;
  my($id, $hostname, $ll0, $ip1, $ip2, $ip3, $ip4, $mask, $fid, $fpw, $ll1, $ll2, $fid2, $ll3, $ll4, $fpw2, $ll5)
    = unpack( "NZ40NCCCCNZ21Z23NNZ24NNZ32N", substr( $self->{dBuf}, 17, $self->{rsize} ) );
  printDel($id) ;
  print "host $hostname $ip1.$ip2.$ip3.$ip4 $fid $fpw\n" ;
  printf "! %08x %08x %08x %08x %08x %08x\n", $ll0, $ll1, $ll2, $ll3, $ll4, $ll5 ;
  return "OK" ;
}

#http/deamon.cfg
#http/scalar.cfg
#igmpGlobalGroup.cfg
#igmpGrpGroup.cfg
#igmpIntfGroup.cfg
#igmpProfileGroup.cfg
#igmpProfileGrpGroup.cfg
#igmpProxyIntfGroup.cfg
#ikePolicyRule.cfg
#ikePreSharedKey.cfg
#ipASPAccLst.cfg
#ipAccListFilter.cfg
sub ipAccListFilter_cfg {
#AB BA DA BA 30 00 0F A0 00 00 00 04 00 00 00 48
  $self = shift;
  for( my $i = 16; $i < $self->{DSz} ; $i += $self->{rsize} ){
    my($ff, $sName, $rId, $aName, $l1, $l2) 
      = unpack( "CZ32NZ32NN", substr( $self->{dBuf}, $i, $self->{rsize} ) );
    printDel($ff) ;
    printf "$sName <%08x> $aName, $l1, $l2\n", $rId ;
  }
  return "OK" ;
}

#ipAccLst.cfg
sub ipAccLst_cfg {
#AB BA DA BA 30 00 0F A0 00 00 00 24 00 00 00 28
  $self = shift;
  for( my $i = 16; $i < $self->{DSz} ; $i += $self->{rsize} ){
    my($ff, $rId, $aName, $aId, $isDeny, $ip1, $ip2, $ip3, $ip4, $m1, $m2, $m3, $m4, $ip5, $ip6, $ip7, $ip8, $m5, $m6, $m7, $m8, $l1, $l2, $l3, $l4) 
      = unpack( "CNZ32NNCCCCCCCCCCCCCCCCNNNN", substr( $self->{dBuf}, $i, $self->{rsize} ) );
    printDel($ff) ;
    printf "<%08x> $aName <$aId>\n", $rId ;
    print $isDeny ? "  deny " : " permit " ;
    print "ip $ip1\.$ip2\.$ip3\.$ip4-$m1\.$m2\.$m3\.$m4 - $ip5\.$ip6\.$ip7\.$ip8-$m5\.$m6\.$m7\.$m8 [$l1, $l2, $l3]" ;
    print $l4 ? " filter\n" : "\n" ;
    print "\n" ;
  }
  return "OK" ;
}

#ipAddGrp.cfg
sub ipAddGrp_cfg {
#AB BA DA BA 30 00 0f a0 00 00 00 1c 00 00 00 08
  $self = shift;
  for( my $i = 16; $i < $self->{DSz} ; $i += $self->{rsize} ){
    my($ff, $id1, $id2, $unknown) = unpack( "CNNA$self->{n1}", substr( $self->{dBuf}, $i, $self->{rsize} ) );
    printDel($ff) ;
    printf "<%08x-%08x> ", $id1, $id2 ;
    for( my $j = 0 ; $j < $self->{n1} ; $j += 4){
      printf "%08x ", unpack( "N", substr( $unknown, $j, 4 ) );
    }
    print "\n" ;
  }
  return "OK" ;
}

#ipCommAccLst.cfg
#ipDampingParams.cfg
#ipDynRedist.cfg
#ipExtCommLst.cfg
#ipGroup.cfg
sub ipGroup_cfg {
#AB BA DA BA 30 00 10 05 00 00 00 60 00 00 00 04
  $self = shift;
  for( my $i = 16; $i < $self->{DSz} ; $i += $self->{rsize} ){
    my($ff, $id, $l1, $l2, $l3, $ss1, $st1, $ss2, $l4, $l5, $l6  ) 
      = unpack( "CNNNNnA12nNNN", substr( $self->{dBuf}, $i, $self->{rsize} ) );
    printDel($ff) ;
    printf "<%08x> %x, %x, %x, %x, %s, %x, %x, %x, %x\n",
      $id, $l1, $l2, $l3, $ss1, $st1, $ss2, $l4, $l5, $l6 ;
  }
  return "OK" ;
}

#routerId.cfg
#ipInterfaceId.cfg
#ipIntf.cfg
sub ipIntf_cfg {
#AB BA DA BA 30 00 10 04 00 00 00 58 00 00 00 08
  $self = shift;
  for( my $i = 16; $i < $self->{DSz} ; $i += $self->{rsize} ){
    my($ff, $id1, $id2, $unknown) = unpack( "CNNA$self->{n1}", substr( $self->{dBuf}, $i, $self->{rsize} ) );
    printDel($ff) ;
    printf "<%08x-%08x> ", $id1, $id2 ;
    for( my $j = 0 ; $j < 40 ; $j += 4){
      printf "%08x ", unpack( "N", substr( $unknown, $j, 4 ) );
    }
    print "\n" ;
  }
  return "OK" ;
}

#ipMcastStatRt.cfg
#ipN2Med.cfg
#ipPolicyAsPathId.cfg
#ipPolicyExtCommId.cfg
#ipPolicyId.cfg
#ipPolicyLog.cfg
#ipPreLst.cfg
sub ipPreLst_cfg {
#AB BA DA BA 30 00 0f a0 00 00 00 54 00 00 00 24
  $self = shift;
  for( my $i = 16; $i < $self->{DSz} ; $i += $self->{rsize} ){
    my($ff, $id, $strID, $unknown) = unpack( "CNA32A$self->{n1}", substr( $self->{dBuf}, $i, $self->{rsize} ) );
    printDel($ff) ;
    printf "<%08x-%32s> ", $id, $strID ;
    for( my $j = 0 ; $j < 40 ; $j += 4){
      printf "%08x ", unpack( "N", substr( $unknown, $j, 4 ) );
    }
    print "\n" ;
  }
  return "OK" ;
}

#ipPreLstEnt.cfg
sub ipPreLstEnt_cfg {
#AB BA DA BA 30 00 0f a0 00 00 00 14 00 00 00 28
  $self = shift;
  for( my $i = 16; $i < $self->{DSz} ; $i += $self->{rsize} ){
    my($ff, $id, $strID, $id2, $unknown) = unpack( "CNA32NA$self->{n1}", substr( $self->{dBuf}, $i, $self->{rsize} ) );
    printDel($ff) ;
    printf "<%08x-%32s-%02x> ", $id, $strID, $id2 ;
    for( my $j = 0 ; $j < 20 ; $j += 4){
      printf "%08x ", unpack( "N", substr( $unknown, $j, 4 ) );
    }
    print "\n" ;
  }
  return "OK" ;
}

#ipPreTr.cfg
#ipPreTrEnt.cfg
#ipRedist.cfg
#ipRtMap.cfg
sub ipRtMap_cfg {
#AB BA DA BA 30 00 0F A0 00 00 00 08 00 00 00 28
  $self = shift;
  for( my $i = 16; $i < $self->{DSz} ; $i += $self->{rsize} ){
    my($ff, $id, $name, $tag, $l1, $l2)
      = unpack( "CNZ32NNN", substr( $self->{dBuf}, $i, $self->{rsize} ) );
    printDel($ff) ;
    printf "<%08x-%32s-$tag> $l1, $l2\n", $id, $name ;
  }
  return "OK" ;
}

#ipRtMapEnt.cfg
sub ipRtMapEnt_cfg {
#AB BA DA BA 30 00 0F A0 00 00 00 34 00 00 00 30
  $self = shift;
  for( my $i = 16; $i < $self->{DSz} ; $i += $self->{rsize} ){
    my($ff, $id, $name, $tag, $l1, $l2, $d1, $d2, $d3, $d4, $str, $d5)
      = unpack( "CNZ32NNNNNNNZ32N", substr( $self->{dBuf}, $i, $self->{rsize} ) );
    printDel($ff) ;
    printf "<%08x-%32s-$tag-$l1-$l2> $d1, $d2, $d3, $d4, \"$str\", $d5\n", $id, $name ;
  }
  return "OK" ;
}

#ipStatRt.cfg
sub ipStatRt_cfg {
#AB BA DA BA 30 00 10 04 00 00 00 10 00 00 00 18
  $self = shift;
  for( my $i = 16; $i < $self->{DSz} ; $i += $self->{rsize} ){
    my($ff, $id, $ip1, $ip2, $t1, $ipn, $t2, $d1, $d2, $d3, $d4) = 
      unpack( "CNA4A4NA4NNNNN", substr( $self->{dBuf}, $i, $self->{rsize} ) );
    printDel($ff) ;
    printf "<%08x-%s/%s-%d-%s-%d> 0x%08x,0x%04x, %d, %d\n",
      $id, strIP($ip1), strIP($ip2), $t1, strIP($ipn), $t2, $d1, $d2, $d3, $d4 ;
  }
  return "OK" ;
}


#ipTem.cfg
#ipTem1.cfg
#ipTunnel.cfg
#ipTunnelInterfaces.cfg
#ipVrfRouteMap.cfg
#ipVrfRouteTarget.cfg
sub ipVrfRouteTarget_cfg {
#AB BA DA BA 30 00 0f a0 00 00 00 09 00 00 00 0c
  $self = shift;
  for( my $i = 16; $i < $self->{DSz} ; $i += $self->{rsize} ){
    my($ff, $vr, $id1, $id2, $l1, $l2, $c1) = 
      unpack( "CNNNNNC", substr( $self->{dBuf}, $i, $self->{rsize} ) );
    printDel($ff) ;
    printf "<%08x-%08x-%08x> %08x %08x,%02x\n", $vr, $id1, $id2, $l1, $l2, $c1 ;
  }
  return "OK" ;
}

#isisAreaAuthenticationGrp.cfg
#isisCircGrp.cfg
#isisDomainAuthenticationGrp.cfg
#isisGroup.cfg
#isisHostNameGrp.cfg
#isisIntfL1AuthenticationGrp.cfg
#isisIntfL2AuthenticationGrp.cfg
#isisManAreaAddGrp.cfg
#isisPassiveIntfGrp.cfg
#isisSummGrp.cfg
#l2f.cfg
#l2fChassis.cfg
#l2fDestinationProfiles.cfg
#l2fDestinations.cfg
#l2fHostProfiles.cfg
#l2fSessions.cfg
#l2fTunnels.cfg
#l2tp.cfg
#l2tpChassis.cfg
#l2tpDestinationProfiles.cfg
#l2tpDestinations.cfg
#l2tpHostProfiles.cfg
#l2tpSessions.cfg
#l2tpTunnels.cfg
#las.cfg
#lasRange.cfg
#mgtmGlobalGroup.cfg
#mplsExplicitPath.cfg
#mplsExplicitPathNode.cfg
#mplsFiconTraceMasks.cfg
#mplsFiconUidSeed.cfg
#mplsLdpLabelAdvAccList.cfg
#mplsLdpProfile.cfg
#mplsLsr.cfg
#mplsMajorInterface.cfg
#mplsMajorInterfaceUidSeed.cfg
#mplsMinorInterface.cfg
#mplsMinorInterfaceUidSeed.cfg
#mplsPathOption.cfg
#mplsRsvpProfile.cfg
#mplsTargetInterface.cfg
#mplsTunnelProfile.cfg
#mplsTunnelProfileDynEndpoints.cfg
#mplsTunnelProfileStaticEndpoints.cfg
#ntpGlobalGrp.cfg
#ntpIfGrp.cfg
#ntpServerGrp.cfg
#ntpVrConfigGrp.cfg
#ospfAggRange.cfg
#ospfArea.cfg
#ospfGeneral.cfg
#ospfIntf.cfg
#ospfIpIntf.cfg
#ospfMd5IntfKeys.cfg
#ospfMd5VirtIntfKeys.cfg
#ospfNbr.cfg
#ospfNetRange.cfg
sub ospfNetRange_cfg {
#AB BA DA BA 30 00 00 01 00 00 00 01 00 00 00 10
  $self = shift;
  for( my $i = 16; $i < $self->{DSz} ; $i += $self->{rsize} ){
# ff router-id ospf-area ip-add ip-mask ??
    my($ff, $id, $area, $ip, $mask, $dt)
      = unpack( "CNA4A4A4C", substr( $self->{dBuf}, $i, $self->{rsize} ) );
    printDel($ff) ;
    printf "<%08x-%s-%s-%s> %02x\n",
      $id, strIP($area), strIP($ip), strIP($mask), $dt ;
  }
  return "OK" ;
}

#ospfRemoteNbr.cfg
#ospfStub.cfg
#ospfSummImport.cfg
#ospfVirtIf.cfg
#pimAccessListTable.cfg
#pimCandRPTable.cfg
#pimDomainInfoTable.cfg
#pimGeneralGroup.cfg
#pimIntfTable.cfg
#pimRPSetTable.cfg
#pimRemoteNbrTable.cfg
#policyId.cfg
#policyMgrClaclIcmpTable.cfg
#policyMgrClaclIgmpTable.cfg
#policyMgrClaclPortTable.cfg
#policyMgrClaclRuleTable.cfg
#policyMgrClaclTable.cfg
#policyMgrColorRuleTable.cfg
#policyMgrFilterRuleTable.cfg
#policyMgrForwardRuleTable.cfg
#policyMgrLogRuleTable.cfg
#policyMgrMarkingRuleTable.cfg
#policyMgrNextHopRuleTable.cfg
#policyMgrNextInterfaceRuleTable.cfg
#policyMgrPolicyIfTable.cfg
#policyMgrPolicyTable.cfg
#policyMgrPolicyTemplateTable.cfg
#policyMgrRateLimitProfileTable.cfg
#policyMgrRateLimitRuleTable.cfg
#policyMgrTrafficClassRuleTable.cfg
#ppp.cfg
#pppBundle.cfg
#pppIfAlias.cfg
#pppInterfaces.cfg
#pppLink.cfg
#pppLinkIfAlias.cfg
#pppLinkInterfaces.cfg
#pppNetwork.cfg
#pppNetworkIfAlias.cfg
#pppNetworkInterfaces.cfg
#pppProfiles.cfg
sub pppProfiles_cfg {
#AB BA DA BA 30 00 00 0D 00 00 00 18 00 00 00 04
  $self = shift;
  for( my $i = 16; $i < $self->{DSz} ; $i += $self->{rsize} ){
    my($ff, $id, $v1, $v2, $v3, $v4, $v5, $v6)
     = unpack( "CNNNNNNN", substr( $self->{dBuf}, $i, $self->{rsize} ) );
    printDel($ff) ;
    printf "<%08x> %08x-%08x-%08x-%08x-%08x-%08x\n", $id, $v1, $v2, $v3, $v4, $v5, $v6 ;
  }
  return "OK" ;
}

#pppoeAcCookieSeed.cfg
#pppoeMajor.cfg
#pppoeMajorSeed.cfg
#pppoeProfiles.cfg
#pppoeRedbackMode.cfg
#pppoeSub.cfg
#pppoeSubSeed.cfg
#pppoeTemplate.cfg
#qos/interfaceQosAttachment.cfg
#qos/profile.cfg
sub qos_profile_cfg {
#AB BA DA BA 30 00 00 01 00 00 00 10 00 00 00 04
  $self = shift;
  for( my $i = 16; $i < $self->{DSz} ; $i += $self->{rsize} ){
    my($ff, $id, $v1, $v2, $v3, $v4)
     = unpack( "CNNNNN", substr( $self->{dBuf}, $i, $self->{rsize} ) );
    printDel($ff) ;
    printf "<%08x> %08x-%08x-%08x-%08x\n", $id, $v1, $v2, $v3, $v4 ;
  }
  return "OK" ;
}

#qos/qosMgr.cfg
#qos/qosModePort.cfg
#qos/qosProfile.cfg
sub qos_qosProfile_cfg {
#AB BA DA BA 30 00 00 01 00 00 00 60 00 00 00 04
  $self = shift;
  for( my $i = 16; $i < $self->{DSz} ; $i += $self->{rsize} ){
    my($ff, $id, $l1, $str, $unknown) =
      unpack( "CNNA32A60", substr( $self->{dBuf}, $i, $self->{rsize} ) );
    printDel($ff) ;
    printf "<%08x> %x-%32s ", $id, $l1, $str ;
    for( my $j = 0 ; $j < 60 ; $j += 4){
      printf "%x ", unpack( "N", substr( $unknown, $j, 4 ) );
    }
    print "\n" ;
  }
  return "OK" ;
}

#qos/qosProfileEntry.cfg
#qos/queueProfile.cfg
#qos/schedulerProfile.cfg
#qos/trafficClass.cfg
#qos/trafficClassGroup.cfg
#qos/trafficClassGroupEntry.cfg
#radius/radiusAccounting.cfg
#radius/radiusAuthentication.cfg
#radius/radiusPerServerConfigFile.cfg
#radius/radiusPerServerMoreConfigFile.cfg
#remOps/pingControl.cfg
#remOps/traceControl.cfg
#ripCfgNbrGrp.cfg
#ripGlobalGrp.cfg
#ripIfGrp.cfg
#ripNetworkGrp.cfg
sub ripNetworkGrp_cfg {
#AB BA DA BA 30 00 00 00 00 00 00 04 00 00 00 0C
  $self = shift;
  for( my $i = 16; $i < $self->{DSz} ; $i += $self->{rsize} ){
    my($ff, $vr, $ip, $msk, $l1) = unpack( "CNA4A4N", substr( $self->{dBuf}, $i, $self->{rsize} ) );
    printDel($ff) ;
    printf "<%08x-%s/%s> %08x\n", $vr, strIP($ip), strIP($msk), $l1 ;
  }
  return "OK" ;
}

#ripSummAddrGrp.cfg
sub ripSummAddrGrp_cfg {
#AB BA DA BA 30 00 00 02 00 00 00 02 00 00 00 0C
  $self = shift;
  for( my $i = 16; $i < $self->{DSz} ; $i += $self->{rsize} ){
    my($ff, $vr, $ip, $msk, $c1, $c2) = unpack( "CNA4A4CC", substr( $self->{dBuf}, $i, $self->{rsize} ) );
    printDel($ff) ;
    printf "<%08x-%s/%s> %02x%02x\n", $vr, strIP($ip), strIP($msk), $c1, $c2 ;
  }
  return "OK" ;
}

#rlpId.cfg
#routerTunIpReasm.cfg
#slep.cfg
#slepInterfaces.cfg
#slotDb.cfg
sub slotDb_cfg {
#AB BA DA BA 30 00 00 03 00 00 00 05 00 00 00 01
  $self = shift;
  for( my $i = 16; $i < $self->{DSz} ; $i += $self->{rsize} ){
    my($ff, $id, $v1, $v2, $v3, $v4, $v5)
      = unpack( "C7", substr( $self->{dBuf}, $i, $self->{rsize} ) );
    printDel($ff) ;
    printf "<$id> %02x($boardId{$v1})-%02x-%02x-%02x-%02x\n", $v1, $v2, $v3, $v4, $v5 ;
  }
  return "OK" ;
}

%boardId = (
    1 => "SRP-5G", # Srp2G, /* SRP-5G */
    2 => "Ct3",
    3 => "Oc3Single",
    4 => "Oc3Dual",
    5 => "Oc3P2Single",
    6 => "Oc3P2Dual",
    7 => "Ct3P2",
    8 => "Ut3a",
    9 => "Ut3f",
    0xa => "Ue3a",
    0xb => "Ue3f",
    0xc => "E1",
    0xd => "SRP-10G", #Srp5G, /* SRP-10G non-ECC */
    0xe => "Oc12Pos",
    0xf => "Ct3P4", #/* CT3 with classifier */
    0x10 => "Oc3P3Single", #/* OC3 with classifier */
    0x11 => "Oc3P3Dual", #/* OC3 with classifier */
    0x12 => "T1",
    0x13 => "FeDual",
    0x14 => "E1Full",
    0x15 => "T1Full",
    0x16 => "Oc12Atm",
    0x17 => "Oc3QuadPos",
    0x18 => "Oc3QuadAtm",
    0x19 => "SRP-10GECC", # Srp5GEcc, /* SRP 5G with ECC -->> SRP-10G ECC */
    0x1a => "GeFe", #/* generic GE/FE card (P1)*/
    0x1b => "Fe8", #/* GE/FE card (P1) with FE8 IOA */
    0x1c => "Vts",
    0x1d => "Srp40G",
####
    0x22 => "COcx",
    0x23 => "12PtCt3", #/* 12 port CT3 */
    0x24 => "OcxPos", #/* generic OcPos card used by SRP software only */
    0x25 => "OcxAtm", #/* generic OcAtm card - used by SRP software only */
    0x26 => "Oc12Server",
    0x27 => "Hssi", #/* HSSI board same as the ut3f */
    0x28 => "OcxAtmHybrid",
    0x29 => "OcxPosP3",
    0x2a => "GeFeP2", #/* Pass 2 generic Gigabit/Fast Ethernet card */
    0x2b => "COc3", #/* channelized oc12 used by SRP software only */
    0x2c => "COc12", #/* channelized oc3 used by SRP software only */
    0x2d => "Oc3AtmHybrid", #/* oc3Atm Hybrid used by SRP software only */ /* OC3 quad port, ATM */
    0x2e => "Oc12AtmHybrid", #/* oc12Atm Hybrid used by SRP software only */
    0x2f => "Oc3PosP3", #/* oc3Pos pass 3 used by SRP software only */
    0x30 => "Oc12PosP3", #/* oc12Pos pass 3 used by SRP software only */
    0x31 => "OcxAtmHybridVe", #/* OCX ATM */
    0x32 => "OcxPosP3Ve",
    0x33 => "GeFeP2Ve",
    0x34 => "Oc12ServerVe",
    0x35 => "OC48-obsoleted",
    0x38 => "Slc16", #/* 16 port serial line card (X21/V35) */
    0x39 => "Ge", #/* GE/FE card (P1) with GE IOA */
    0x3a => "GeP2", #/* GE/FE card pass 2 with GE IOA */
    0x3b => "Fe8P2", #/* GE/FE card pass 2 with FE8 IOA */
    0x3c => "Ut3F12", #/* Unchannelized 12 port ct3 */
    0x3d => "COcxVe", #/* coc12 vrtx-e */
    0x3e => "Srp40GPlus",
    0x40 => "Srp5GPlus",
####
    0x62 => "OC48" );


#smdsInterfaces.cfg
#smdsMajorInterfaces.cfg
#smdsSubInterfaces.cfg
#snmpAccessCfg.cfg
#snmpCommunityCfg.cfg
#snmpEngineCfg.cfg
#snmpGlobalCfg.cfg
#snmpNotifyCfg.cfg
#snmpNotifyFilterCfg.cfg
#snmpScalarCfg.cfg
#snmpTargetAddrCfg.cfg
#snmpTargetParamsCfg.cfg
#snmpTrapHostCfg.cfg
#snmpUserCfg.cfg
#snmpViewCfg.cfg
#sonetInterfaces.cfg
sub sonetInterfaces_cfg {
#AB BA DA BA 30 00 0a a1 00 00 00 f8 00 00 00 04
  $self = shift;
  for( my $i = 16; $i < $self->{DSz} ; $i += $self->{rsize} ){
    my($ff, $id, $unknown) = unpack( "CNA$self->{n1}", substr( $self->{dBuf}, $i, $self->{rsize} ) );
    printDel($ff) ;
    printf "<%08x> ", $id ;
    for( my $j = 0 ; $j < 40 ; $j += 4){
      printf "%08x ", unpack( "N", substr( $unknown, $j, 4 ) );
    }
    print "\n" ;
  }
  return "OK" ;
}

#sonetPath.cfg
#sonetPathInterfaces.cfg
sub sonetPathInterfaces_cfg {
#AB BA DA BA 30 00 0f a1 00 00 01 2c 00 00 00 04
  my $self = shift;
  for( my $i = 16; $i < $self->{DSz} ; $i += $self->{rsize} ){
    my($ff, $id, $unknown) = unpack( "CNA$self->{n1}", substr( $self->{dBuf}, $i, $self->{rsize} ) );
    printDel($ff) ;
    printf "<%08x> ", $id ;
    for( my $j = 0 ; $j < 40 ; $j += 4){
      printf "%08x ", unpack( "N", substr( $unknown, $j, 4 ) );
    }
    print "\n" ;
  }
  return "OK" ;
}

#sonetScalar.cfg
#sonetVT.cfg
#sonetVTInterfaces.cfg
#sshServer.cfg
sub sshServer_cfg {
#  if( $self->{cfgName} eq "sshServer.cfg" ){
#AB BA DA BA 30 00 00 03 00 00 00 4c 00 00 00 04
  my $self = shift;
  for( my $i = 16; $i < $self->{DSz} ; $i += $self->{rsize} ){
    my($ff, $id, $unknown) = unpack( "CNA$self->{n1}", substr( $self->{dBuf}, $i, $self->{rsize} ) );
    printDel($ff) ;
    printf "<%08x> ", $id ;
    for( my $j = 0 ; $j < 40 ; $j += 4){
      printf "%08x ", unpack( "N", substr( $unknown, $j, 4 ) );
    }
    print "\n" ;
  }
  return "OK" ;
}

#sssClient.cfg
#st.cfg
#stGlobalLifetime.cfg
#stInterfaces.cfg
#stLocalEndpoint.cfg
#stTransformSet.cfg
#tclId.cfg
#telnetport.cfg
sub telnetport_cfg {
#AB BA DA BA 30 00 00 00 00 00 00 04 00 00 00 04 FF 00 00 00 01 00 00 00 17
  $self = shift;
  for( my $i = 16; $i < $self->{DSz} ; $i += $self->{rsize} ){
    my($ff, $id, $val) = unpack( "CNN", substr( $self->{dBuf}, $i, 9 ) );
    printDel($ff) ;
    printf "<%08x> = %d\n", $id, $val ;
  }
return "OK" ;
}

#vlanMajorInterfaces.cfg
sub vlanMajorInterfaces_cfg {
#AB BA DA BA 30 00 00 02 00 00 00 54 00 00 00 04
  $self = shift;
  for( my $i = 16; $i < $self->{DSz} ; $i += $self->{rsize} ){
    my($ff, $id, $unknown) = unpack( "CNA$self->{n1}", substr( $self->{dBuf}, $i, $self->{rsize} ) );
    printDel($ff) ;
    printf "<%08x> ", $id ;
    for( my $j = 0 ; $j < 40 ; $j += 4){
      printf "%08x ", unpack( "N", substr( $unknown, $j, 4 ) );
    }
    print "\n" ;
  }
  return "OK" ;
}

#vlanSubInterfaces.cfg
sub vlanSubInterfaces_cfg {
#AB BA DA BA 30 00 00 03 00 00 00 68 00 00 00 04
  $self = shift;
  for( my $i = 16; $i < $self->{DSz} ; $i += $self->{rsize} ){
    my($ff, $id, $unknown) = unpack( "CNA$self->{n1}", substr( $self->{dBuf}, $i, $self->{rsize} ) );
    printDel($ff) ;
    printf "<%08x> ", $id ;
    for( my $j = 0 ; $j < 40 ; $j += 4){
      printf "%08x ", unpack( "N", substr( $unknown, $j, 4 ) );
    }
    print "\n" ;
  }
  return "OK" ;
}

#vrrp/vrrpAssoc.cfg
#vrrp/vrrpOper.cfg
#vrrp/vrrpRouter.cfg
#vrrp/vrrpScalar.cfg
##########################
sub vRouterGlobal_cfg {
#AB BA DA BA 50 00 0F A0 00 00 00 0C
#FF 80 00 00 42 80 00 00 01 00 00 00 00
  $self = shift;
  for( my $i = 12; $i < $self->{DSz} ; $i += $self->{rsize} ){
    my($ff, $id, $id1, $id2) = unpack( "CNNN", substr( $self->{dBuf}, $i, $self->{rsize} ) );
    printDel($ff) ;
    printf "<%08x> %08x, %08x\n", $id, $id1, $id2 ;
  }
  return "OK" ;
}

###########################
###########################
sub strIP {
#strIP( substr( $i103, 0, 4 ) );
  return sprintf( "%d.%d.%d.%d", unpack( "C4", shift ) );
}
###########################
sub new {
  my ($this, $filePath) = @_;
  my $class = ref($this) || $this;
  my $self = {};
  $self->{filePath} = $filePath;
#  open( $self->{fd}, $self->{filePath} ) or return undef;
  open( $self->{fd}, $self->{filePath} ) or die $!;
  binmode( $self->{fd} );
  bless $self, $class;
#  $self->initialize();
  return $self;
}  

###############
package main;

my $cnfFile = shift;
my $option = "" ;
if( $cnfFile =~ /^-/ ){
    $option = $cnfFile ;
    $cnfFile = shift ;
}
my $cF = cnfFile->new( $cnfFile );
my $readCount = 0;
my $headCount = 0;

# cfg file will be tested here.
if( $cF->{filePath} =~ /\.cfg$/ ) {
  print "it is cfg file.\n" ;
  my $c = read $cF->{fd}, $data, 100000000; # 100M max size
  print "data size: $c\n" ;
  die "size less than 4: $c" if ($c<4) ;

  my ($sign, $tp, $ver, $dl, $kl) = unpack( "NnnNN", substr($data, 0, 16 ));
  my $el = $kl + $dl + 1 ;

  printf "expected %d entries", (($c - 16)/$el ) ;
  my $mod = ($c - 16) % $el ;
  print ", mod $mod - SHOULD BE 0" if $mod ;
  print ".\n" ;

  printf "Error: Data signature (0x%08x)\n", $sign if $sign != 0xabbadaba ;
  printf "Type: 0x%x, ver: $ver, data_length: $dl, key_length: $kl\n", $tp ;

  $cF->printDupIds( $data, length($data), $kl, $el, "", 0, "cfg");
  exit();
}


while(1){
  my $resultStr = "";
  my $resultCount = 0;
  $resultStr = $cF->readHd() ;
  $readCount += $cF->{rtnSz};
  $headCount++;
###  print "$resultStr\n" if $resultStr ne "OK" ;
  last if eof $cF->{fd} ;
}
### print "\n$headCount files ($cF->{unresCnt} unresolved), $readCount bytes read\n" ;
### print "Warning:\n$cF->{warnMsg}\n" ;
### print "Unresolved = $cF->{unResolved}\n" ;
die "\n$headCount files ($cF->{unresCnt} unresolved), $readCount bytes read\n" ;

##########

