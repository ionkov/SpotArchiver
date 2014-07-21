#!/usr/bin/perl
########################################################################
# 
# File   :  database_publisher.pl
# History:  21-jul-2013 (gionkov) draw a path based on the last N received
#                       TRACK messages. 
#           9-Aug-2013  (gionkov) Changes as follow:
#                       * Renamed the file to database_publisher.pl.
#                       * Publish KMZ file limited by N most recent points.
#                       * Publish currently_in_coordinates.csv file.
#                       * Publish currently_in_country.txt: reverse lookup by coordinates.
#                       * Publish full_trip_coordinates.csv.
#
########################################################################
#
# This file reads a json file containing gps coordinates organized by 
# type but not sorted. The script will extract data from the json file
# and publish it for on-site consumption.
# 
########################################################################

use JSON qw( decode_json ); # From CPAN
use Data::Dumper;           # Perl core module
use Getopt::Std;            # Used to read debug params.
use POSIX qw/strftime/;
use strict;                    
use warnings;

my $N = 500;
my $PROJECT_FOLDER = "/home/gionkov/savemytrack.com/public/spot_archive/";
my $MASTER_DATABASE_FILE = $PROJECT_FOLDER . "data/master_gps_database.json";
my $LAST_N_POINTS_AF = $PROJECT_FOLDER . "maps/last_n_points.csv";
my $ALL_POINTS_AF = $PROJECT_FOLDER . "maps/full_trip_coordinates.csv";
my $CURRENT_LOCATION_AF = $PROJECT_FOLDER . "maps/current_location.csv";

sub main () {
    my $database = loadJsonFile($MASTER_DATABASE_FILE);
    my $allPoints = extractSortedPoints($database);

    # Exit the script early if there are no points.
    if (@$allPoints == 0) {
	die("There are no points to be processed!\n");
    }

    my $lastNPoints = extractLastNPoints($allPoints, $N);

    exportCSVFile($allPoints, $ALL_POINTS_AF);
    exportCSVFile($lastNPoints, $LAST_N_POINTS_AF);

    my @arr = @$allPoints;
    exportCurrentLocation($arr[@$allPoints - 1], $CURRENT_LOCATION_AF);
}

#
# Retur sorted by epoch time triplets "epochtime,long,lat" using only the TRACK data.
# 
sub extractSortedPoints($) {
    my $database = shift;
    my @points = ();

    my $unixTimeToMetadataHash = $database->{'TRACK'};
    if (!defined($unixTimeToMetadataHash)) {
	return \@points;
    }

    for my $unixtime (sort {$a<=>$b} keys %$unixTimeToMetadataHash) {
	my $metadataHash = $unixTimeToMetadataHash->{$unixtime};
	my $str = $unixtime . "," . $metadataHash->{'longitude'} . "," . $metadataHash->{'latitude'};
	push(@points, $str);
    }
    return \@points;
}

sub extractLastNPoints($) {
    my $arrRef = shift;
    my @allPoints = @$arrRef;
    my $lastN = shift;

    my $lastNPoints = ();
    my $size = @allPoints;

    # For sanity make sure $lastN is not > $size.
    if ($lastN > $size) {
	$lastN = $size;
    }

    for (my $i = $size - $lastN; $i < $size; $i++) {
	push(@$lastNPoints, $allPoints[$i]);
    }

    return $lastNPoints;
}

sub parseCoordinates($) {
    my$timeCoordinate = shift;
    # Time is always of the form:  1353773840,$lat,$log
    my $coordinates = substr($timeCoordinate, 11);
    return $coordinates;
}

sub parseTime($) {
    my $timeCoordinate = shift;
    # Time is always of the form:  1353773840,$lat,$log
    my $time = substr($timeCoordinate, 0, 10);
    return $time;
}

sub exportCSVFile($) {
    my $timeCoordinates = shift;
    my $outputAF = shift;

    # Write data to a csv file. 
    open(OUTFILE, ">$outputAF") or die "Error opening $outputAF: $!";
    foreach my $timeCoordinate (@$timeCoordinates) {
	if ($timeCoordinate =~ /(\d+),(.+),(.+)/) {
	    print(OUTFILE $3 . "," . $2 . "," . $1 . "\n");
	}
    }
    close(OUTFILE);
}

#
# This method will produce a file with the following format:
# "$lat,$long,epochtime, readable time format, country"
#
# The country location will be generated by calling Google Maps and
# doing reverse geo mapping.
#
sub exportCurrentLocation($) {
    my $currentLocation = shift;
    my $outputAF = shift;
    my $epochtime = parseTime($currentLocation);
    my ($long, $lat) = split(",", parseCoordinates($currentLocation));
    my $date = strftime('%D %T', localtime($epochtime));
    my $country = geoMapCountry($lat,$long);
   
    # Write all the data to the final file.
    # Write data to a csv file.
    open(OUTFILE, ">$outputAF") or die "Error opening $outputAF: $!";
    print(OUTFILE "#latitude,longitude,epochtime,date,country\n");
    print(OUTFILE "$lat,$long,$epochtime,$date,$country\n");
    close(OUTFILE);
}

#
# Get a country by given GPS coordinates using google maps.
#
sub geoMapCountry() {
    my $lat = shift;
    my $long = shift;
    my $country = "N/A";
    
    # The data comes back as json.
    my $googleRequest = "http://maps.googleapis.com/maps/api/geocode/json?latlng=$lat,$long&sensor=false";

    my $json = `curl -s \"$googleRequest\"`;
    my $decodedJson = decode_json($json);

    # The returned JSON is described by Google here:
    # https://developers.google.com/maps/documentation/geocoding/?csw=1#ReverseGeocoding
    my $resultsArr = $decodedJson->{'results'};
    foreach my $result (@$resultsArr) {
	my $addressComponentsArr = $result->{'address_components'};

	foreach my $addressComponent (@$addressComponentsArr) {
	    my $typesArr = $addressComponent->{'types'};

	    foreach my $type (@$typesArr) {
		if ($type eq "country") {
		    $country = $addressComponent->{'long_name'};
		}
	    }
	}
    }

    return $country;
}

#
# Read a Json file based on a given file name and return hash.  Return empty hash if problem.
#
sub loadJsonFile($) {
    my $inputJsonFileName = shift;
    
    # Note: consider reading the file as a stream for efficiency.
    my $jsonString = `cat $inputJsonFileName`;
    my $decodedJson = decode_json($jsonString);
    return $decodedJson;
}

#
# Run the script.
#
main();
