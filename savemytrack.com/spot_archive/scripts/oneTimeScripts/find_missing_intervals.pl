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
use File::Basename;                      # Parse file name from full path.
use POSIX qw/strftime/;
use strict;                    
use warnings;

my $BASE_DATA_AP = "/Users/georgeionkov/Coding/SpotArchiver/";
my $MASTER_DATABASE_AF = $BASE_DATA_AP . "master_gps_database.json";
my $BACKUP_DATA_AP = $BASE_DATA_AP;

sub main () {


    my $allRF = "all.csv";

    open(ALL_DATA, "<all.csv");

    # Load the latest database.
    my $database = loadJsonFile($MASTER_DATABASE_AF);
    my $reverseDatabase = {};
    foreach my $typeKey (keys %$database) {
	my $typeHash = $database->{$typeKey};
	foreach my $unixtime (keys %$typeHash) {
	    my $datapoint = $typeHash->{$unixtime};
	    my $coordinates = $datapoint->{'latitude'} . "," . $datapoint->{'longitude'};
		
	    # Insert the datapoint in the reverseDatabase where he coordinates string is the key.
	    $reverseDatabase->{$coordinates} = $datapoint;
	}
    }

    my $coordinatesArr = [];
    my $lastPoint = {};

    while (my $coordinates = <ALL_DATA>) {
	chomp($coordinates);

      	if (exists $reverseDatabase->{$coordinates}) {
	    my $datapoint = $reverseDatabase->{$coordinates};
	    
	    # Check for data to insert.
	    if (@$coordinatesArr > 0) {
		my $firstPoint = $datapoint;

		# Insert the data
		insertPoints($database, $coordinatesArr, $lastPoint, $firstPoint);
	    }

	    # reset all the counters
	    $lastPoint = $datapoint;
	    $coordinatesArr = [];
	} else {
	    push(@$coordinatesArr, $coordinates);
	}

    }
    close(ALL_DATA);

    # FInally print the difference between the two databases for testing purposes.
    my $unchangedDB = loadJsonFile($MASTER_DATABASE_AF);

    print STDERR "Read from $MASTER_DATABASE_AF\n";
    test_printStats($unchangedDB);
    print STDERR "After updated:\n==========================\n";
    test_printStats($database);
    print STDERR "Difference detector:\n\n";
    test_diff2Databases($unchangedDB, $database);

    # Do not write the changes in for now. 
    exportJsonDatabase($database, $MASTER_DATABASE_AF);
}

sub insertPoints() {
    my $database = shift;          # DB to insert the data to.
    my $coordinatesArr = shift;    # the lat,long coordinate pairs to insert
    my $lastPoint = shift;         # the last point in the DB  before the missing interval
    my $firstPoint = shift;        # the first point after the missing interval

    my $trackDatabase = $database->{'TRACK'};

    my $timeDiff = $firstPoint->{'unixTime'} - $lastPoint->{'unixTime'};
    my $numberPoints = @$coordinatesArr;   

    # Add 1 extra unit to make sure we do not have even devision to avoid identical times at the end ranges.
    my $timeStep = $timeDiff / ($numberPoints + 1);
    $timeStep = sprintf("%.0f", $timeStep);  # Unix Time cannot be a float.
    my $unixTime = $lastPoint->{'unixTime'} + 0;

    foreach my $coordinates (@$coordinatesArr) {
	$unixTime = $unixTime + $timeStep;
	
	# Add critical data unixTime check.  If we have a violation kill the script!
	if ($unixTime <= $lastPoint->{'unixTime'} || 
	    $unixTime >= $firstPoint->{'unixTime'}) {
	    die("UnixTime violation!!! : $unixTime <= " . $lastPoint->{'unixTime'} . " || $unixTime >= " . $firstPoint->{'unixTime'} . "\n");
	}

	my ($lat,$long) = split(",", $coordinates);
	my $entryHash = {
	    'messengerName' => 'The Walkabout',
	    'showCustomMsg' => 'Y',
	    'hidden' => 0,
	    'selected' => "bless( do{\(my \$o = 0)}, \'JSON::XS::Boolean\' )",
	    '@clientUnixTime' => '0',
	    'altitude' => 0,
	    'id' => 0,
	    'messageType' => 'TRACK',
	    'dateTime' => strftime('%D %T', localtime($unixTime)),
	    'longitude' => $long,
	    'latitude' => $lat,
	    'unixTime' => $unixTime,
	    'messengerId' => $unixTime  # We need a unique messageId so just use $unixTime.
	};

	# Another time check:  we can never have unixTime collisions or entry collisions!
	if (exists $trackDatabase->{$unixTime}) {
	    die ("We have a data point collision!\nnew: " . Dumper($entryHash) . "\nold: " . Dumper($trackDatabase->{$unixTime}));
	}

	# No collisions found so simply insert the new datapoint. 
	$trackDatabase->{$unixTime} = $entryHash;
	
	print("Inserted: $coordinates\n");
    }

    # Save the Track database.
    $database->{'TRACK'} = $trackDatabase;
}


# Read a Json file based on a given file name and return hash.  Return empty hash if problem.
sub loadJsonFile() {
    my $jsonAF = shift;
    
    # Note: consider reading the file as a stream for efficiency.
    my $jsonString = `cat $jsonAF`;
    my $decodedJson = decode_json($jsonString);
    return $decodedJson;
}

sub exportJsonDatabase() {
    my $database = shift;
    my $targetAF = shift;

    backupFile($targetAF);

    open(DBFILE, ">$targetAF");
    my $jsonString = encode_json($database);
    print(DBFILE $jsonString);
    close(DBFILE);
}

sub backupFile() {
    my $sourceAF = shift;

    my $unixTimestamp = time;
    my $destinationRF = fileparse($sourceAF);
    my $destinationAF = $BACKUP_DATA_AP . "/" . $unixTimestamp . "." . $destinationRF . ".backup";

    my $rVal = `cp $sourceAF $destinationAF; gzip -f $destinationAF`;
    if ($rVal) {
        print STDERR "Problem making backup for $sourceAF. Returned: $rVal\n";
        return 0;
    }
    return 1;
}


sub test_diff2Databases() {
    my $db1 = shift;
    my $db2 = shift;

    foreach my $k1 (keys %$db1) {
        my $db1_l2 = $db1->{$k1};
        my $db2_l2 = $db2->{$k1};

        print STDERR "key: " . $k1 . " DB1: " . keys(%$db1_l2) . " DB2: " . keys(%$db2_l2) . "\n";

        my $diff = test_printDiff($db1_l2, $db2_l2) && test_printDiff($db2_l2, $db1_l2);
        if ($diff) {
            print STDERR "No differences found!\n";
        }
    }
}

sub test_printDiff() {
    my $db1 = shift;
    my $db2 = shift;
    my $differ = 1;

    foreach my $k (keys(%$db1)) {
        my $h1 = $db1->{$k};
        my $h2 = $db2->{$k};

        if (!defined($h2)) {
            print STDERR Dumper( $h1 );
            $differ = 0;
        }

        # This loops checks if it is possible for the same coordinaes to be presnet but
        # to have different methadata associated with them.
        foreach my $k2 (keys(%$h1)) {
            my $value1 = $h1->{$k2};
            my $value2 = $h2->{$k2};

            if (!defined($value2) || $value1 ne $value2) {
                print STDERR Dumper( $h1 );
                $differ = 0;
                last;
            }
        }
    }
    return $differ;
}

# Testing:: Print stats about a master DB.
sub test_printStats() {
    my $database = shift;
    foreach my $k (keys %$database) {
        my $l2 = $database->{$k};
        print STDERR "key: " . $k . " size: " . keys(%$l2) . "\n";
    }
}

main();
