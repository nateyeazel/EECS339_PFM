#!/usr/bin/perl -w

use strict;
use CGI qw(:standard);
use DBI;
use Time::ParseDate;

BEGIN {
  $ENV{PORTF_DBMS}="oracle";
  $ENV{PORTF_DB}="cs339";
  $ENV{PORTF_DBUSER}="pdinda";
  $ENV{PORTF_DBPASS}="pdinda";

  unless ($ENV{BEGIN_BLOCK}) {
    use Cwd;
    $ENV{ORACLE_BASE}="/raid/oracle11g/app/oracle/product/11.2.0.1.0";
    $ENV{ORACLE_HOME}=$ENV{ORACLE_BASE}."/db_1";
    $ENV{ORACLE_SID}="CS339";
    $ENV{LD_LIBRARY_PATH}=$ENV{ORACLE_HOME}."/lib";
    $ENV{BEGIN_BLOCK} = 1;
    exec 'env',cwd().'/'.$0,@ARGV;
  }
};

use stock_data_access;

my $symbol = param('symbol');
my $timerange = param('timerange');
print header(-type => 'image/png', -expires => '-1h' );

my $results = `./time_series_symbol_project.pl $symbol $timerange AWAIT 200 AR 16`;

my @predictionArray;

while ($results =~ /(\d+.\d+)\n/g){
  if($1 eq '0.000000'){
    next;
  }
  push(@predictionArray, $1);
}

my $index = 0;
open(GNUPLOT,"| gnuplot") or die "Cannot run gnuplot";

  print GNUPLOT "set term png\n";           # we want it to produce a PNG
  print GNUPLOT "set output\n";             # output the PNG to stdout
  print GNUPLOT "plot '-' using 1:2 with linespoints\n"; # feed it data to plot
  foreach my $r (@predictionArray) {
    $index += 1;
    print GNUPLOT $index, "\t", $r, "\n";
  }
  print GNUPLOT "e\n"; # end of data
  #
  # Here gnuplot will print the image content
  #
  close(GNUPLOT);
