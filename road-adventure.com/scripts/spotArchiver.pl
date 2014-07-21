#!/usr/bin/perl
use strict;
use Date::Manip;

my $today = ParseDate('now');
my ($year, $month, $day, $t) = UnixDate($today, "%Y", "%m", "%d", "%T");
my $date = sprintf "%4d%02d%02d:$t",$year,$month,$day,$t;

my $feedId = "07cbz5mHmDUMFaUkEXOeW2edksWZiuS7m";
my $jsonStream = "https://api.findmespot.com/spot-main-web/consumer/rest-api/2.0/public/feed/".$feedId."/message";

my $targetFile = "/home/gionkov/road-adventure.com/public/spot_archive/data/data_new/$date.json";
my $exitCode = `curl -s  $jsonStream > $targetFile`;

if ($exitCode) {
    print STDERR "[$date] Archiving feed $feedId.\n$jsonStream\n";
    print STDERR "\nError while retrieving SPOT data!  Exit Code: \"$exitCode\"\n\n";
} else {
    print "[$date] Archiving feed $feedId.\n";
}



