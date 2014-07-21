#!/usr/bin/perl
########################################################################
# 
# File   :  map_last_n_messagess.pl
# History:  21-jul-2013 (gionkov) draw a path based on the last N received
#                       TRACK messages. 
#
########################################################################
#
# This file reads a json file containing gps coordinates organized by 
# type but not sorted. The script will create a KMZ file with a path
# based on he last N Track messages.  N is set to 500 currently.
# 
########################################################################

use JSON qw( decode_json ); # From CPAN
use Data::Dumper;           # Perl core module
use Getopt::Std;            # Used to read debug params.
use strict;                    
use warnings;

my $DEBUG = 0;
my $N = 1000;
my $PROJECT_FOLDER = "/home/gionkov/road-adventure.com/public/spot_archive/";
my $MASTER_DATABASE_FILE = $PROJECT_FOLDER . "data/master_gps_database.json";
my $KMZ_FILE_NAME = $PROJECT_FOLDER . "maps/map_current_locationd.kmz";

sub main () {
    my $database = loadJsonFile($MASTER_DATABASE_FILE);
    my $coordinates = extractSortedCoordinates($database);
    my $kml = buildKML($coordinates);	
    exportKMZFile($kml, $KMZ_FILE_NAME);
}

#
# Return the last N most recent points as "long,lat" string.
# 
sub extractSortedCoordinates() {
    my $database = shift;

    my @points = ();

    my $unixTimeToMetadataHash = $database->{'TRACK'};
    if (!defined($unixTimeToMetadataHash)) {
	return \@points;
    }

    my $size = keys %$unixTimeToMetadataHash;
    my $i = 0;
    for my $unixtime (sort {$a<=>$b} keys %$unixTimeToMetadataHash) {
	$i++;

	if ($size - $i <= $N) {
	    my $metadataHash = $unixTimeToMetadataHash->{$unixtime};
	    my $str = $metadataHash->{'longitude'} . "," . $metadataHash->{'latitude'};
	    push(@points, $str);
	}
    }
    return \@points;
}

sub buildKML() {
    my $points = shift;
    my $trackKML = buildTrackKML($points);
    my $currentLocationKML = buildCurrentLocationKML($points);

    my $kmlMap = 
	"<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n" .
	"<kml xmlns=\"http://www.opengis.net/kml/2.2\">\n" .
	"<Document>\n" . 
	"  <name>Live map (updates outomagically on the hour) of our travels in the last $N track locations</name>\n" . 
	"  <description><![CDATA[]]></description>\n" .
        "\n" .
        "  <Style id=\"style_Current_Location\">\n" .
        "    <IconStyle>\n" .
        "      <Icon>\n" .
	"        <refreshMode>onExpire</refreshMode>\n" . 
        "        <href>http://maps.gstatic.com/mapfiles/ms2/micons/campground.png</href>\n" .
        "      </Icon>\n" .
        "    </IconStyle>\n" .
        "  </Style>\n" .
        "\n" .
        "  <Style id=\"style_Toyota_Track\">\n" .
        "    <LineStyle>\n" .
        "      <color>73FF0000</color>\n" .
        "      <width>5</width>\n" .
        "    </LineStyle>\n" .
        "  </Style>\n" .
	"\n" .
	$trackKML . "\n" .
	$currentLocationKML . "\n" .
	"\n" .
	"</Document>\n" . 
	"</kml>\n";
    
    return $kmlMap;
}

sub buildTrackKML() {
    my $points = shift;

    # Start a line object and set name, style etc.
    my $kml = "\n" .
	"  <Placemark id=\"toyota_track\">\n" .
	"    <name>George and Teresa, most recent 500 track points.</name>\n" .
	"    <description><![CDATA[]]></description>\n" .
	"    <refreshMode>onExpire</refreshMode>\n" . 
	"    <styleUrl>#style_Toyota_Track</styleUrl>\n" .
	"    <LineString>\n" .
	"      <tessellate>1</tessellate>\n" .
	"      <coordinates>\n";
    
    # Add all applicable points from the $pointsMatrix.
    foreach my $point (@$points) {
	$kml = $kml . $point . ",0.000000\n";
    }

    # Edding closing tags for the linne object.
    $kml = $kml .
	"\n" .
	"      </coordinates>\n" .
	"    </LineString>\n" .
	"  </Placemark>\n";

    return $kml;
}

sub removeparseCoordinates() {
    my$timePointStr =shift;
    my $coordinates = "";

    return $coordinates;
}

sub parseTime() {
    my $timePointStr = shift;
    my $time = "";
    
    return $time;
}

sub buildCurrentLocationKML() {
    my $arrRef = shift;
    my @points = @$arrRef;
    if (@points < 1) {
	return "";
    }
    
    my $currentLocation = $points[@points - 1];
    my $currentLocationKML = 
	"  <Placemark id=\"current_location\">\n" .
        "    <name>George's and Teresa's Current Location</name>\n" .
        "    <description><![CDATA[<div dir=\"ltr\">We are currently here. Coordinates: $currentLocation</div>]]></description>\n" .
        "    <styleUrl>#style_Current_Location</styleUrl>\n" .
	"    <refreshMode>onExpire</refreshMode>\n" . 
        "    <Point>\n" .
        "      <coordinates>" . $currentLocation . "</coordinates>\n" .
        "    </Point>\n" .
        "  </Placemark>\n";

    return $currentLocationKML;
}

#
# This method produces a kmz file based on a given $kml string and a file name.
#
sub exportKMZFile() {
    my $kml = shift;
    my $kmzFileName = shift;
    my $tmpFileName = $kmzFileName . "\.kml" ;

    # Write the content to a temporary file.
    open(OUTFILE, ">$tmpFileName") or die "Error opening $tmpFileName: $!";
    print(OUTFILE $kml);
    close(OUTFILE);
    
    # Archive the temp zip file to make the final .kmz file.
    `zip $kmzFileName $tmpFileName`;

    # Cleanup the tmp file.
    `rm $tmpFileName`;
}

sub initialize() {
    # Read debug command line parameter.
    my %argsD;
    getopt('d', \%argsD);
    $DEBUG = $argsD{'d'};
}

#
# Read a Json file based on a given file name and return hash.  Return empty hash if problem.
#
sub loadJsonFile() {
    my $inputJsonFileName = shift;
    
    # Note: consider reading the file as a stream for efficiency.
    my $jsonString = `cat $inputJsonFileName`;
    my $decodedJson = decode_json($jsonString);
    return $decodedJson;
}

#
# Run the script.
#
initialize();
main();
