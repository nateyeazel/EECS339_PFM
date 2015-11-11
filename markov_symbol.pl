#!/usr/bin/perl -w

use Getopt::Long;

&GetOptions("simple"=>\$simple);

$#ARGV==2 or die "usage: markov_symbol.pl [--simple] symbol levels order \n";

($symbol,$levels,$order)=@ARGV;

@output=`./get_data.pl --notime --close $symbol | ./stepify.pl $levels | ./markov_online.pl $order | ./eval_pred.pl`;

if ($simple) {
  $output[3]=~/(\d+)/;
  $numsyms=$1;
  $output[4]=~/\((\S+)/;
  $percenttried=$1;
  $output[5]=~/\((\S+)\s+\%\s+of\s+attempts,\s+(\S+)/;
  $percentcorrectofattempts=$1;
  $percentcorrectofall=$2;
  print join("\t",$symbol,$levels,$order,$numsyms,$percenttried,$percentcorrectofattempts,$percentcorrectofall),"\n";
} else {
  print @output;
}


