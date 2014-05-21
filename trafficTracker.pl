#!/usr/bin/perl

use strict;
use 5.18.0;

use Data::Dumper;
require LWP::UserAgent;
use JSON;
use Getopt::Long;
use DateTime;

#defaults
my $SLEEP_TIME = 60;
my $ITERATIONS = 10;

my %args;
GetOptions(
	\%args,
	"help|h|?",
	"dest|d=s",
	"origin|o=s",
	"sleep|s=i",
	"iterations|i=i",
	"key|k=s",
	"file|f=s",
);

usage() if $args{'help'};

# Main
{
	my $destination = $args{'dest'} // die "No destination specified.";
	my $origin      = $args{'origin'} // die "No origin specified.";
	my $sleep_time  = $args{'sleep'} // $SLEEP_TIME;
	my $iterations  = $args{'iterations'} // $ITERATIONS;
	my $api_key     = $args{'key'} // die "No API Key provided.";
	my $out_file    = $args{'file'} // die "No output file specified.";

	#print "dest $destination; orig $origin\n";
	$destination = clean_arg( $destination );
	$origin      = clean_arg( $origin );
	#print "dest $destination; orig $origin\n";

	my $run_count = 0;


	my $trip = get_trip( $destination, $origin, $api_key );
	my $dt = DateTime->now;
	$trip->{'date'} = $dt->ymd('/');
	$trip->{'time'} = $dt->hour . ':' . $dt->minute;

	print <<END;
Going from:
	$trip->{'origin'}
To:
	$trip->{'destination'}
Distance:
	$trip->{'distance'}

Got Duration: $trip->{'duration'}\t Minutes: $trip->{'minutes'}
END

	$run_count++;
	
	write_output( $trip, $out_file );


	while ( $run_count < $iterations )
	{
		sleep $sleep_time;

		$trip = get_trip( $destination, $origin, $api_key );
		my $dt = DateTime->now;
		$trip->{'date'} = $dt->ymd('/');
		$trip->{'time'} = $dt->hour . ':' . $dt->minute;

		say "Got Duration: " . $trip->{'duration'} . "\t Minutes: " . $trip->{'minutes'};
		write_output( $trip, $out_file );

		$run_count++;

	}
	
}

exit 0;

sub get_trip
{
	my ( $dest, $orig, $api_key ) = @_;

	my $ua = LWP::UserAgent->new;
	$ua->timeout(10);
	$ua->env_proxy;

	my $get_line = "https://maps.googleapis.com/maps/api/directions/json?origin=" . $orig . "&destination=" . $dest . "&sensor=false&key=" . $api_key;
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
		$trip->{'origin'} = $route->{'legs'}->[0]->{'start_address'}; 
		$trip->{'destination'} = $route->{'legs'}->[0]->{'end_address'};
		$trip->{'distance'} = $route->{'legs'}->[0]->{'distance'}->{'text'};
		$trip->{'duration'} = $route->{'legs'}->[0]->{'duration'}->{'text'};
		my $tmp = $route->{'legs'}->[0]->{'duration'}->{'value'} / 60;
		$trip->{'minutes'} = sprintf( "%.1f", $tmp );

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

sub write_output
{
	my ( $trip, $out_file ) = @_;

	my $fh;

	my $line = $trip->{'date'} . "\t" . $trip->{'time'} . "\t" . $trip->{'origin'} . "\t" . $trip->{'destination'} . "\t" .  $trip->{'distance'} . "\t" .  $trip->{'duration'} . "\t" . $trip->{'minutes'} . "\n";
	
	open( $fh, ">>",  "$out_file" );

	if ( -z $out_file )
	{
		print $fh "Date\tTime\tFrom\tTo\tDistance\tDuration\tMinutes\n";
	}

	print $fh "$line";

}

sub usage
{
	print <<EOD;
trafficTracker.pl - Check google trip duration x times.

Required Parameters:
	--destination, -d : where you're headed. must be space or + separated words.
	--origin, -o      : where you are starting. must be space or + separated words.
	--key, -k         : Your google Directions API key. Server Key is the one you want here.
	--file, -f        : Where we save the output.

Optional Parameters:
	--iterations, -i  : How many times should I run? Defaults to 10.
	--sleep, -s       : How long should I sleep between runs, in seconds? Defaults to 60.
	--help, -h, -?    : Displays this message and exits.

Things to be aware of:
	Directions API has a daily limit. Make sure you're iterations & sleep are reasonable for your limits.
EOD

exit;
}
