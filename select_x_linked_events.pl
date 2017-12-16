#!/usr/bin/perl -w 
#
# USAGE: select_x_linked_events.pl
#
# The environment variables must be set
#
# Version: v1.1
#
# Author: Nenad Noveljic
#
# See also: http://nenadnoveljic.com/blog/event-propagation-in-oracle-12-2
#
# The script traverses the doubly linked list for the session events on 
# a 12.2 Oracle database. The script produces result only if at least one event is set.
# If the internal implementation changes, the script
# will not show the correct result. Since no latches are set, the view might 
# be inconsistent in the case of  concurrent changes.
#
# For experimental purposes only, not intended for production !!!
#

#$ENV{ORACLE_HOME} = '/u00/oracle/orabase/product/12.2.0.1.0' ;
#$ENV{ORACLE_SID} 

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
  my $is_sql ;
  print "\n$i. element:\n" ;
  foreach my $offset 
    ( 0x0, 0x28, 0x38, 0x48, 0x50, 0x68, 0x70, 0xb8 ) 
  {
    my $value = print_offset( $base , $offset ) ;
    if ( $offset == 0x48 and hex $value ) {
      $is_sql = 1 ;
      print "  => " ;
      print_string( $value ) ;
    }
    if ( $offset == 0xb8 and $is_sql  ) {
      print "  = " ;
      print_string( add_offset($base , $offset) ) ;
    }
    
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

sub get_value {
  my ( $addr , $opts_ref ) = @_ ;
  my $value =  oradebug_peek($addr, $opts_ref ) ;
  return $value ;
}

sub print_offset {
  my ( $base , $offset  ) = @_ ;
  my $addr =  add_offset($base, $offset ) ;
  my $value = get_value( $addr  ) ;
  print qq{$base+} . sprintf('%2X', $offset) . ": *" . $addr . " = $value\n";
  return $value ;
}

sub print_string {
  my $address = shift @_ ;
  
  my $double_quads = 1 ;
  
  DOUBLE_QUAD:
  while (1) {
    my $sql_id_hex = get_value( $address , { len => 16}) ;
    
    foreach my $word ( split m{\s+}xms , $sql_id_hex ) {
      #little endian assumed here
      for ( my $i = 3 ; $i >= 0 ; $i-- ) {
        my $ascii = substr $word , $i * 2 , 2 ;
        last DOUBLE_QUAD if  ( $ascii eq '00' ) ;
        print chr(hex $ascii)   ; 
      }
    }
    last DOUBLE_QUAD if ($double_quads > 4) ; 
    $address = sprintf("%X",hex($address) + 16 );
    $double_quads++ ;
  }
  print "\n" ;
}

sub oradebug_peek {
  my ( $addr , $opts_ref ) =  @_ ;
  my $len = $opts_ref->{len} ? $opts_ref->{len} : 1 ; 
  my $addr_presented = '0' . $addr ;
  my @out = exec_sqlplus(qq{
oradebug setmypid
oradebug peek 0x$addr $len
}) ; 
  
  my $value ;
  LINE:
  foreach my $line (@out) {
    next LINE if $line !~ m{\[${addr_presented}.*=\s*(.*)}xms ;
    $value = $1 ; 
    last LINE
  } 
  chomp $value ;
  return $value ;
}
