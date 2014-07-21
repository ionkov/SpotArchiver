#!/usr/bin/perl
###
# @date: 08/07/2013
# @author: Georgi Ionkov
# 
# Dump all information for a point based on a given coordinates. 
#
###

use JSON qw( decode_json encode_json );  # From CPAN
use Data::Dumper;                        # Perl core module
use Getopt::Long;                         # Used to read debug params.
use strict;                    
use warnings;

my $BASE_DATA_AP = "/home/gionkov/road-adventure.com/public/spot_archive/data/";
my $MASTER_DATABASE_AF = $BASE_DATA_AP . "master_gps_database.json";

sub main () {
    my $lat = '';
    my $long = '';
    GetOptions("long=s" => \$long,
	       "lat=s" => \$lat);

    # We need coordinate values.
    if ($lat eq '' || $long eq '') {
	die ("\nUsage: $0 -lat=\"43.58411\" -long=\"-110.73090\"\n\n");
    } else {
	print("Serching latitude: $lat and longitude: $long\n");
    }

    # Load the latest database.
    my $database = loadJsonFile($MASTER_DATABASE_AF);

    # OK, this is not going to be efficient since it is O(n), but
    # 'n' is going to be less than 20,000 so I don't care that much to flip
    # the data sideways and do a O(1) lookup.  At the end of the day I will 
    # have to do O(n) operations to do that so in aggregate time it will 
    # probably be the same time.  It could actually be worse since I have to
    # copy which is more expensive.  Just my 5 cents why I am brute forcing it. 
    foreach my $typeKey (keys %$database) {
	my $typeHash = $database->{$typeKey};
	foreach my $unixtime (keys %$typeHash) {
	    my $datapoint = $typeHash->{$unixtime};

	    if ($long eq $datapoint->{'longitude'} &&
		$lat eq $datapoint->{'latitude'}) {
		print("=================================\n");
		print Dumper($datapoint);
		print("=================================\n");
	    }

	    # Only for testing
	    # print Dumper($datapoint);

	}
    }
}

# Read a Json file based on a given file name and return hash.  Return empty hash if problem.
sub loadJsonFile() {
    my $jsonAF = shift;
    
    # Note: consider reading the file as a stream for efficiency.
    my $jsonString = `cat $jsonAF`;
    my $decodedJson = decode_json($jsonString);
    return $decodedJson;
}

main();
