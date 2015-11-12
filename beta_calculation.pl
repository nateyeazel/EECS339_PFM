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
my $from = param('from');
my $to = param('to');

print header(-type => 'text/html', -expires => '-1h' );
print "HELLO HELLO\n\n";
my $nasdaqresults = `./quotehist.pl --close --from=$from --to=$to "^IXIC"`;

my @nasdaqTimes;
my @nasdaqPrices;
my @nasdaqArray = [\@nasdaqTimes, \@nasdaqPrices];

while ($nasdaqresults =~ /(\d+)\s+(\d+.\d+)\n/g){
  push(@nasdaqTimes, $1);
  push(@nasdaqPrices, $2);
}
# print @nasdaqArray;

my $marketSTD = std_dev(@nasdaqPrices);
print $marketSTD;


sub average {
        my (@values) = @_;

        my $count = scalar @values;
        my $total = 0;
        $total += $_ for @values;

        return $count ? $total / $count : 0;
}

sub std_dev {
        my (@values) = @_;
        my $average = average(@values);
        my $count = scalar @values;
        my $std_dev_sum = 0;
        $std_dev_sum += ($_ - $average) ** 2 for @values;

        return $count ? sqrt($std_dev_sum / $count) : 0;
}