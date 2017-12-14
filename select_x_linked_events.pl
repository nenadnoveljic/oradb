#!/usr/bin/perl -w 
#
#  Copyright: (c) Nenad Noveljic - All rights reserved
#
# http://nenadnoveljic.com
#
# The script traverses the doubly linked list for the session events on 
# a 12.2 Oracle database. If the internal implementation changes, the script
# will not show the correct result. Since no latches are set, the view might 
# be inconsistent in the case of  concurrent changes.
#
# For experimental purposes only, not intended for production !!!
#

use strict ;

#starting dbgdInitEventGr chunk
my @dbgdInitEventGr_addr = exec_sqlplus(
q{select trim(leading 0 from ksmchptr) from x\$ksmsp 
  where ksmchcom='dbgdInitEventGr' and ksmchidx=1 
  order by ksmchidx fetch first 1 rows only ;
}) ;
my  $dbgdInitEventGr_addr = $dbgdInitEventGr_addr[0] ;
chomp $dbgdInitEventGr_addr ;

print "linked list ptr to root entry:\n" ;
my $root_entry =  print_offset($dbgdInitEventGr_addr, 0x28) ;
print "\n" ;

print "root_Entry:\n" ;
print_offset( $root_entry , 0x0 ) ;
my $root_entry_0xb8_addr = add_offset($root_entry, 0xb8) ;
my $first_element_0x68 = print_offset( $root_entry , 0xb8 ) ;
my $first_element =  add_offset($first_element_0x68, -0x68) ;
print "\n" ;

print "Traversing linked list:\n" ;
my @element_bases ;
my $next = $first_element ;
FOLLOW_POINTER:
foreach my $i (1, 2, 3) {
  push @element_bases, $next ;
  my $offset_0x68_value = print_offset($next, 0x68) ;
  $next = add_offset($offset_0x68_value, -0x68) ;
  last FOLLOW_POINTER 
  if ( hex($offset_0x68_value) == hex($root_entry_0xb8_addr) ) ; 
}

my $i = 1 ;
foreach my $base (@element_bases) {
  print "\n$i. element:\n" ;
  foreach my $offset ( 0x0, 0x28, 0x38, 0x50, 0x68, 0x70 ) {
    print_offset( $base , $offset ) ;
  }
  $i++ ;
}

sub add_offset {
  my ( $base , $offset ) = @_ ;
  return sprintf('%X', hex($base) + $offset ) ; 
}

sub exec_sqlplus {
  my $sql = shift @_ ;
  my $command = qq{sqlplus -s "/ as sysdba" << EOD
set head off 
set pagesize 0
$sql 
EOD} ;
  my @out = `$command` ; 
  die ( 'Error' , $command , @out )  
    if ( (grep m{ORA-}xms,  @out) or (grep m{SP2-}xms, @out)  )  ;  
  return @out ;
}

sub print_offset {
  my ( $base , $offset ) = @_ ;
  my $addr =  add_offset($base, $offset ) ;
  my $value =  oradebug_peek($addr) ;
  print qq{$base+} . sprintf('%2X', $offset) . ": *" . $addr . " = $value\n";
  return $value ;
}

sub oradebug_peek {
  my $addr = shift @_ ;
  my $addr_presented = '0' . $addr ;
  my @out = exec_sqlplus(qq{
oradebug setmypid
oradebug peek 0x$addr 1
}) ; 
  
  my $value ;
  LINE:
  foreach my $line (@out) {
    next LINE if $line !~ m{\[${addr_presented}.*=\s*(\S+)}xms ;
    $value = $1 ; 
    last LINE
  } 
   return $value ;
}
