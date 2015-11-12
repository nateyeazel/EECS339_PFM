#!/usr/bin/perl

use Getopt::Long;
use Time::ParseDate;
use FileHandle;

use stock_data_access;

$close=1;

$field1='close';
$field2='close';

&GetOptions( "field1=s" => \$field1,
	     "field2=s" => \$field2,
	     "from=s"   => \$from,
	     "to=s"     => \$to,
             "simple"   => \$simple,
	     "corrcoeff"=>\$docorrcoeff);
if (defined $from) { $from=parsedate($from);}
if (defined $to) { $to=parsedate($to); }


$usage = "usage: get_covar.pl [--field1=field] [--field2=field] [--from=time] [--to=time] [--simple (two symbols only)] [--corrcoeff] SYMBOL SYMBOL+\n";
$#ARGV>=1 or die $usage;


@symbols=@ARGV;


for ($i=0;$i<=$#symbols;$i++) {
    $s1=$symbols[$i];
    $s2='DOW13';
    
#first, get means and vars for the individual columns that match
    
    $sql = "select count(*),avg(l.$field1),stddev(l.$field1),avg(r.$field2),stddev(r.$field2) from allStockData l join allStockData r on l.timestamp= r.timestamp where l.symbol='$s1' and r.symbol='$s2'";
    $sql.= " and l.timestamp>=$from" if $from;
    $sql.= " and l.timestamp<=$to" if $to;
    
    ($count, $mean_f1,$std_f1, $mean_f2, $std_f2) = ExecStockSQL("ROW",$sql);
    
    #skip this pair if there isn't enough data

    if ($count<30) { # not enough data
      $covar{$s1}{$s2}='NODAT';
      $corrcoeff{$s1}{$s2}='NODAT';
    } else {
      
      #otherwise get the covariance

      $sql = "select avg((l.$field1 - $mean_f1)*(r.$field2 - $mean_f2)) from allStockData l join allStockData r on  l.timestamp=r.timestamp where l.symbol='$s1' and r.symbol='$s2'";
      $sql.= " and l.timestamp>= $from" if $from;
      $sql.= " and l.timestamp<= $to" if $to;

      ($covar{$s1}{$s2}) = ExecStockSQL("ROW",$sql);

#and the correlationcoeff
        if ($i == 0) {
          print "Coefficient of Variation:\t";
          print $std_f1/$mean_f1;
        }
    }
}

print "\nBeta Coefficient:\t";
print ($covar{$symbols[0]}{$symbols[1]})/($covar{$symbols[1]}{$symbols[1]});

