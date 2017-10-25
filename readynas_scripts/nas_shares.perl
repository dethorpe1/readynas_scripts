#! /usr/bin/perl -w

use strict;
use XML::Simple;
use Data::Dumper;

#############################################################################

=head1 Script to set up a users configured shares and mount them at login

Reads config file nas_shares.xml to get list for each user

=cut

#############################################################################


#############################################################################

=head1 usage()

Display uasge and exit

IN: Optional Error message to print

=cut

#############################################################################

sub usage {
	print "ERROR: " . $_[0] . "\n" if defined $_[0];
	print <<END;
	Script to setup users NAS shares
	Run at login, tests if NAS1 is available and sets up users configured shares
	
	USAGE: print "$0"" 
END
	exit 1;	
}

my $configFile = "/etc/profile.d/nas_shares.xml";
#my $configFile = "/home/craign/git/testgit/scripts/nas_shares.xml";
my $user=$ENV{'USER'};
my $config;
my $debug=0;

# see if nas is up
#while (system("ping -c 1 -w 20 192.168.1.211") > 0 ) {
while (system("ping -c 1 -w 20 nas1") > 0 ) {
	print ("\nWARN: NAS1 not available, waiting 1s ...\n");
	sleep 1;
}

# NAS is up
print ("NAS1 is up\n");
# create link to the common share
if (! -e "/home/$user/nas1_shared") {
	system ("ln -s /mnt/nas1_shared /home/$user/nas1_shared");
}
my $count = 0;
while (! -e $configFile && $count < 20 ) {
    $count++;
	print ("\nWARN: config file dosn't exist, waiting 1s for mount\n");
	sleep 1;
}
if ($count >= 20) {
	print ("\nERROR: config file dosn't exist\n");
	exit;
}

print ("Config file found continuing with mounts\n");
# get config file from common share
if (-e $configFile) {
	eval {$config = XMLin($configFile, ForceArray =>['share'],
									   #KeyAttr => {sync => "type"},
									   SuppressEmpty => 1 )
	};
	if ($@) {
		$@ =~ s/^[\n\r]+//; # returned error has leading new line
		usage ("ERROR: Error Reading Config file $configFile: $@\n");
	}
	
	print ("\nDEBUG: Full config hash: " . Dumper ($config)) if $debug;
	
	my $shareArray = $config->{user}{$user}{share};
	foreach my $share (@$shareArray) {
		print("\nDEBUG: Share entry:" . Dumper($share)) if $debug;
		print ("\n Setting up share: " . $share->{nas_name} . "... \n");
		my $mountPoint="/mnt/nas1_" . $share->{nas_name};
		# check mount point exists
		if (-e $mountPoint) {
			my $options="";
			if (exists $share->{options}) {
				$options = " -o " . $share->{options};
			}
			# mount the filesystem
			system ("mount $options $mountPoint");
			if (! $?) {
				print "\nMounted $mountPoint";
			}
			else {
				print "\nERROR: failed to mount $mountPoint. May already be mounted\n";
			}
			# create link
			if (! -e "/home/$user/nas1_" . $share->{nas_name}) {
				system ("ln -s $mountPoint /home/$user/nas1_" . $share->{nas_name});
			}
		}
		else {
			print("\nERROR: mount point for share dosn't exist: $mountPoint\n");
		}
	}

}
else {
	print("ERROR: Config file dosn't exist: $configFile");
}
