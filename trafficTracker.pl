#!/usr/bin/perl

use strict;
use 5.18.0;

use Data::Dumper;
require LWP::UserAgent;
use JSON;
use Getopt::Long;

#defaults
my $SLEEP_TIME = 60;
my $ITERATIONS = 10;

my %args;
GetOptions(
	\%args,
	"dest|d=s",
	"origin|o=s",
	"sleep|s=i",
	"iterations|i=i",
	"key|k=s",
);

# Main
{
	my $destination = $args{'dest'} // die "No destination specified.";
	my $origin      = $args{'origin'} // die "No origin specified.";
	my $sleep_time  = $args{'sleep'} // $SLEEP_TIME;
	my $iterations  = $args{'iterations'} // $ITERATIONS;
	my $api_key     = $args{'key'} // die "No API Key provided.";

	#print "dest $destination; orig $origin\n";
	$destination = clean_arg( $destination );
	$origin      = clean_arg( $origin );
	#print "dest $destination; orig $origin\n";

	my $run_count = 0;

	my $trip = get_trip( $destination, $origin );

	print <<END;
Going from:
	$trip->{'start'}
To:
	$trip->{'end'}
Distance:
	$trip->{'distance'}

Got Duration: $trip->{'duration'} 
END

	$run_count++;
	
	while ( $run_count < $iterations )
	{
		sleep $sleep_time;

		$trip = get_trip( $destination, $origin );

		say "Got Duration: " . $trip->{'duration'};

		$run_count++;

	}
	
}

exit 0;

sub get_trip
{
	my ( $dest, $orig ) = @_;

	my $ua = LWP::UserAgent->new;
	$ua->timeout(10);
	$ua->env_proxy;

	my $get_line = "https://maps.googleapis.com/maps/api/directions/json?origin=" . $orig . "&destination=" . $dest . "&sensor=false&key=" . $API_KEY;
	#print $get_line;
	my $response = $ua->get($get_line);
	#say Dumper $response;
	 
	my $routes;
	if ($response->is_success) {
	    $routes = $response->decoded_content;  # or whatever
	}
	else {
	    die $response->status_line;
	}


	my $data = decode_json($routes);

	die "Google said no" unless $data->{'status'} eq 'OK';

	my $trip = {};
	for my $route ( @{ $data->{'routes'} } ){
		#say "Duration of route: " . $route->{'legs'}->[0]->{'duration'}->{'text'};
		$trip->{'start'} = $route->{'legs'}->[0]->{'start_address'}; 
		$trip->{'end'} = $route->{'legs'}->[0]->{'end_address'};
		$trip->{'distance'} = $route->{'legs'}->[0]->{'distance'}->{'text'};
		$trip->{'duration'} = $route->{'legs'}->[0]->{'duration'}->{'text'};

		last;
	}

	return $trip;
}

sub clean_arg
{
	my ( $loc ) = @_;

	$loc =~ tr/ /\+/;

	#$loc = ( $loc =~ tr/[^+\w]//r);

	return $loc;
}
