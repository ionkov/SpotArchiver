#!/usr/bin/perl
###
# @date: 07/25/2013
# @author: Georgi Ionkov
# 
# This script reads all temporary json files extracted from the SPOT server,
# strips all the unnecessary encoding returned from SPOT and imports them into 
# master database containing historical data. The script will dedup events based 
# on unixtimestamp in each event.  All read files and database changes are 
# backed up in a separate folder. 
#
# Script naming conventions worth mentioning:
# 'AF' stands for Absolute File name.
# 'RF' stands for Relative File name.
# 'AP' stands for Absolute Path.
# 'RP' stands for Relative Path.
#
# Command Line arguments:
# '-d' set this flag to print debug information relativive to any changes made. 
#
###

use JSON qw( decode_json encode_json );  # From CPAN
use Data::Dumper;                        # Perl core module
use File::Basename;                      # Parse file name from full path.
use Getopt::Std;                         # Used to read debug params.
use strict;                    
use warnings;

my $BASE_DATA_AP = "/home/gionkov/road-adventure.com/public/spot_archive/data/";
my $MASTER_DATABASE_AF = $BASE_DATA_AP . "master_gps_database.json";
my $BACKUP_DATA_AP = $BASE_DATA_AP . "data_backup/";
my $BAD_DATA_AP = $BASE_DATA_AP . "data_bad/";
my $NEW_DATA_AP = $BASE_DATA_AP . "data_new/";
my $DEBUG = 0;

sub main () {
    my $database = loadJsonFile($MASTER_DATABASE_AF);
    
    my @jsonAFList = glob("$NEW_DATA_AP/*.json");
    foreach my $jsonAF  (@jsonAFList) {

	if (processJsonFile($database, $jsonAF)) {
	    moveAndCompressFile($jsonAF, $BACKUP_DATA_AP);
	} else {
	    moveAndCompressFile($jsonAF, $BAD_DATA_AP);
	}
    }

    # Print quick stats for the updated DB.
    if ($DEBUG) {
	my $unchangedDB = loadJsonFile($MASTER_DATABASE_AF);

        print STDERR "Read from $MASTER_DATABASE_AF\n";
        test_printStats($unchangedDB);
	print STDERR "After updated:\n==========================\n";
	test_printStats($database);
	print STDERR "Difference detector:\n\n";
	test_diff2Databases($unchangedDB, $database);
    }
    
    exportJsonDatabase($database, $MASTER_DATABASE_AF);
}

sub initialize() {
    # Read debug command line parameter. 
    my %args;
    getopt('d', \%args);
    
    # Set global Debug flag.                                                                                                                                                                                                                 
    $DEBUG = $args{'d'};
}

sub moveAndCompressFile() {
    my $sourceAF = shift;
    my $destinationAP = shift;

    my $destinationRF = fileparse($sourceAF);
    my $destinationAF = $destinationAP . "/" . $destinationRF;

    my $rVal = `mv $sourceAF $destinationAF ; gzip -f $destinationAF`;
    return $rVal;
}

sub processJsonFile() {
    my $database = shift;
    my $jsonAF = shift;

    my $decodedJson = loadJsonFile($jsonAF);
    
    my $arr = $decodedJson->{"response"}->{"feedMessageResponse"}->{"messages"}->{"message"};
    if (!defined $arr || @$arr <= 0) {
	return 0;
    }
    
    foreach my $h (@$arr) {
	my $messageType = $h->{messageType};
	my $key = $h->{unixTime};
	
	if (!defined($database->{$messageType})) {
	    $database->{$messageType} = {};
	}
	
	if (!defined($database->{$messageType}->{$key})) {
	    $database->{$messageType}->{$key} = $h;
	}
    } 
    return 1;
}

# Read a Json file based on a given file name and return hash.  Return empty hash if problem.
sub loadJsonFile() {
    my $jsonAF = shift;
    
    # Note: consider reading the file as a stream for efficiency.
    my $jsonString = `cat $jsonAF`;
    my $decodedJson = decode_json($jsonString);
    return $decodedJson;
}

# Export the database hash to a given file.  This method assumes that the
# given $database is JSON format.  It also makes a backup of the file given if possible.
sub exportJsonDatabase() {
    my $database = shift;
    my $targetAF = shift;

    # Backup previous versions of the target file.
    backupFile($targetAF);

    open(DBFILE, ">$targetAF");
    my $jsonString = encode_json($database);
    print(DBFILE $jsonString);
    close(DBFILE); 
}

# Backup a given file by making a copy of it marked with the current timestamp in the 
# $BACKUP_DATA_AP folder.  Print a warning on STDERR if a problem.
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

# Testing:: Print stats about a master DB.
sub test_printStats() {
    my $database = shift;
    foreach my $k (keys %$database) {
        my $l2 = $database->{$k};
        print STDERR "key: " . $k . " size: " . keys(%$l2) . "\n";
    }
}

# Testing:: Verifies if two master DB hashes are the same and prints diffs.
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

# Testing::  Return 1 if the hashes are identical and 0 otherwise.
# print all items in the 1st db that are not in the 2nd db.
sub test_printDiff() {
    my $db1 = shift;
    my $db2 = shift;
    my $differ = 1;

    foreach my $k (keys(%$db1)) {
	my $h1 = $db1->{$k};
	my $h2 = $db2->{$k};

	# There is no hash for key $k so print $h1.  This is the most common case
	# when a coordinate is in $db1 but not in $db2. 
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

# Run the script.
initialize();
main();
