package WWW::Nike::NikePlus;

use 5.008008;
use strict;
use warnings;

require Exporter;

use LWP::Simple;
use LWP::Simple::Cookies ( autosave => 1, file => "$ENV{'TEMP'}/lwp_cookies.dat" );
use XML::Simple;
use Time::Duration;

our @ISA = qw(Exporter);

# Items to export into callers namespace by default. Note: do not export
# names by default without a very good reason. Use EXPORT_OK instead.
# Do not simply export all your public functions/methods/constants.

# This allows declaration	use WebService::NikePlus ':all';
# If you do not need this, moving things directly into @EXPORT or @EXPORT_OK
# will save memory.
our %EXPORT_TAGS = ( 'all' => [ qw(
	
) ] );

our @EXPORT_OK = ( @{ $EXPORT_TAGS{'all'} } );

our @EXPORT = qw( 	nike_last_run nike_run_totals nike_run_averages nike_runs_list
			nike_run_detail nike_user_goals nike_user_challenges nike_chal_detail
			nike_authenticate nike_web_links
		);

our $VERSION = '0.02';


# Preloaded methods go here.

#These are some known URLs for Nike+ - they could change...
my $nike_front_page = "https://www.nike.com/nikeplus";

my $nike_auth_url = "https://www.nike.com/nikeplus/v1/services/app/generate_pin.jhtml";
my $user_data_url = "https://www.nike.com/nikeplus/v1/services/app/get_user_data.jhtml";
my $user_goal_url = "https://www.nike.com/nikeplus/v1/services/app/goal_list.jhtml";
my $user_chal_url = "https://www.nike.com/nikeplus/v1/services/widget/get_challenges_for_user.jhtml";
my $chal_detail_url = "https://www.nike.com/nikeplus/v1/services/app/get_challenge_detail.jhtml";
my $user_runs_url = "https://www.nike.com/nikeplus/v1/services/app/run_list.jhtml";
my $run_detail_url = "https://www.nike.com/nikeplus/v1/services/app/get_run.jhtml";




#We always have to authenticate before calling any of the other methods, even if we don't care about the pin/token
sub nike_authenticate {
	
	my ( $username, $password, $locale ) = @_;
	
	#Pass the username, password and user's locale (default is en_us) to the API. This is done over SSL.
	my $content = get( "$nike_auth_url?login=$username&password=$password&locale=$locale" ) or die "Unable to connect to Nike+\n";
	#We get some XML back so parse it with XML::Simple
	my $parse_content = XMLin( $content );
	my $auth_status = $parse_content->{status};
	#We should get back a success status if authentication was successful, if not return undef now.
	unless ( $auth_status =~ /success/i ) {
		return(undef);
	}
	#Assuming that authentication was successful we should now have a cookie and a pin (or token)
	#The cookie should be automagically stored and passed back with LWP::Simple::Cookie
	#The pin is used to directly access web content (i.e. bypassing the user having to sign in again through their browser)
	return( $parse_content->{pin} );
	
}

#Once we have the pin from nike_authenticate we can provide some URLs that directly login to the various pages
#DO NOT expose this to the public! This provides a way into your account without your password!!
sub nike_web_links {
	
	my ( $pin ) = @_;
	
	my $front_page = "$nike_front_page?token=$pin";
	my $chals_page = "$nike_front_page?l=challenges&token=$pin";
	my $goals_page = "$nike_front_page?l=goals&token=$pin";
	my $runs_page = "$nike_front_page?l=runs&token=$pin";
	
	return ( $front_page, $chals_page, $goals_page, $runs_page );
	
}
	
	
#Retrieve data for the last run that the user did
#Returns:
#$unit (km or mi)
#$last_run_dist (in miles or km depending on user's preference as set through the web interface)
#$last_run_duration_millisecs (run time in ms)
#$last_run_duration_friendly (run time in friendly format from Time::Duration)
#$last_run_pace_friendly (average pace for the run in mins/secs per km/mi)
sub nike_last_run {

	#Call the web API (cookie is used to authenticate) and get some XML back
	my $content = get( $user_data_url );
	my $parse_content = XMLin( $content );
	
	my $unit = $parse_content->{userOptions}->{distanceUnit};
	my $last_run_dist = $parse_content->{mostRecentRun}->{distance};
	my $last_run_duration_millisecs = $parse_content->{mostRecentRun}->{duration}; # Duration is in milliseconds
	my $last_run_duration_friendly = duration( ($last_run_duration_millisecs / 1000 ) );  # Time::Duration converts number of seconds into human friendly format
	my $last_run_pace = $last_run_duration_millisecs / $last_run_dist;
	my $last_run_pace_friendly = duration( ($last_run_pace / 1000) );
	
	return( $unit, $last_run_dist, $last_run_duration_millisecs, $last_run_duration_friendly, $last_run_pace_friendly );
	
}

#Retrieve lifetime totals
#Returns:
#$unit (km or mi)
#$total_run_num (total number of runs completed ever)
#$total_run_dist (total lifetime distance)
#$total_run_duration_millisecs (total time spent running over the lifetime, in ms)
#$total_run_duration_friendly (total time spent running over the lifetime, in friendy format (years/months/days/hours/minutes/seconds etc) )
sub nike_run_totals {
	
	my $content = get( $user_data_url );
	my $parse_content = XMLin( $content );
	
	my $unit = $parse_content->{userOptions}->{distanceUnit};
	
	my $total_run_num = $parse_content->{userTotals}->{totalRuns};
	my $total_run_dist = $parse_content->{userTotals}->{totalDistance};
	my $total_run_duration_millisecs = $parse_content->{userTotals}->{totalDuration};
	my $total_run_duration_friendly = duration( ($total_run_duration_millisecs / 1000 ) );
	
	return( $total_run_num, $total_run_dist, $total_run_duration_millisecs, $total_run_duration_friendly );	
	
}
	
#Calculate lifetime averages
#Rreturns:
#$unit (km or mi)
#$average_dist (thh average run length)
#$average_time_millisecs (average run time, in ms)
#$average_time_friendly (average run time, in friendy format (years/months/days/hours/minutes/seconds etc) )
#$average_run_pace_friendly (average pace across all runs in mins/secs per km/mi)
sub nike_run_averages {
	
	my $content = get( $user_data_url );
	my $parse_content = XMLin( $content );
	
	my $unit = $parse_content->{userOptions}->{distanceUnit};
	
	my $total_run_num = $parse_content->{userTotals}->{totalRuns};
	my $total_run_dist = $parse_content->{userTotals}->{totalDistance};
	my $total_run_duration_millisecs = $parse_content->{userTotals}->{totalDuration};
	my $total_run_duration_friendly = duration( ($total_run_duration_millisecs / 1000 ) );
	
	my $average_dist = $total_run_dist / $total_run_num;
	my $average_time_millisecs = $total_run_duration_millisecs / $total_run_num;
	my $average_time_friendly = duration( ($average_time_millisecs / 1000 ) );
	my $average_run_pace = $average_time_millisecs / $average_dist;
	my $average_run_pace_friendly = duration( ($average_run_pace / 1000) );
	
	return( $unit, $average_dist, $average_time_millisecs, $average_time_friendly, $average_run_pace_friendly );
	
}

#Retrieve a list of all stored runs, with basic detail
#Returns:
#Hash ref of run data:
#	$data = { 
#			run_number (starts at 0) => {
#							synctime => datetime,
#							distance => number (use $unit from nike_last_run() ),
#							name => text (user specified name),
#							calories => number (cals calculated to be burnt, requires weight to be specified),
#							duration => number (run length in ms),
#							starttime => datetime,
#							nike_id => number (unique ID for each run, use with nike_run_detail() ),
#							description => text,
#							},
#		};
#
#$total_run_num (total number of runs over lifetime)
sub nike_runs_list {
	
	#We need the total number of runs stored for the basic data first
	my $content = get( $user_data_url );
	my $parse_content = XMLin( $content );
	my $total_run_num = $parse_content->{userTotals}->{totalRuns};
	
	#Now we can pull out all the runs
	$content = get( $user_runs_url );
	$parse_content = XMLin( $content );
	
	my $array_number = 0;
	my %data;
	
	while ( $array_number < $total_run_num ) {
		
		$data{$array_number}{synctime} = $parse_content->{runList}->{run}->[$array_number]->{syncTime};
		$data{$array_number}{distance} = $parse_content->{runList}->{run}->[$array_number]->{distance};
		$data{$array_number}{name} = $parse_content->{runList}->{run}->[$array_number]->{name};
		$data{$array_number}{calories} = $parse_content->{runList}->{run}->[$array_number]->{calories};
		$data{$array_number}{duration} = $parse_content->{runList}->{run}->[$array_number]->{duration};
		$data{$array_number}{starttime} = $parse_content->{runList}->{run}->[$array_number]->{startTime};
		$data{$array_number}{nike_id} = $parse_content->{runList}->{run}->[$array_number]->{id};
		$data{$array_number}{description} = $parse_content->{runList}->{run}->[$array_number]->{description};
		
		$array_number++;
		
	}
	
	return(\%data, $total_run_num);
	
}
	

#Not yet implemented
sub nike_run_detail {

	my ( $run_id ) = @_;
	my $content = get( "$run_detail_url?id=$run_id" );
	my $parse_content = XMLin( $content );
	
}

#Retrieve a list of all the user's goals
#Returns:
#Hash ref of goals
#	$data = { 
#			goal_number (starts at 0) => {
#							level => number,
#							endtime => datetime,
#							starttime => datetime,
#							complete => boolean,
#							type => text,
#							progress => text,
#							},
#		};
#
#$number_of_goals (total number of goals)
#$number_complete (number of goals that are complete)
sub nike_user_goals {
	
	my $content = get( $user_goal_url );
	my $parse_content = XMLin( $content );	
	my $goals_ref = $parse_content->{goalList}->{goal};
	my $number_of_goals = keys %$goals_ref;
	unless ( $number_of_goals > 0 ) { return(undef,0,0); }
	my @goal_ids = keys %$goals_ref;
	
	my %data;
	my $number_complete = 0;
	
	foreach my $goal ( @goal_ids ) {
		
		$data{$goal}{level} = $parse_content->{goalList}->{goal}->{$goal}->{level};
		$data{$goal}{endtime} = $parse_content->{goalList}->{goal}->{$goal}->{endTime};
		$data{$goal}{starttime} = $parse_content->{goalList}->{goal}->{$goal}->{startTime};
		$data{$goal}{complete} = $parse_content->{goalList}->{goal}->{$goal}->{complete};
		$data{$goal}{type} = $parse_content->{goalList}->{goal}->{$goal}->{definition}->{type};
		$data{$goal}{progress} = $parse_content->{goalList}->{goal}->{$goal}->{definition}->{totalProgress};
		#There are some other definition structures here, but I haven't worked them out yet
	
		if ( $data{$goal}{complete} =~ /true/i ) { $number_complete++; }
		
	}
	
	return(\%data, $number_of_goals, $number_complete);
	
	
}

#Retrieve a list of all the user's challenges
#Returns:
#Hash ref of challenges
#	$data = { 
#			challenge_name  => {
#							owner => text,
#							greeting => text,
#							status => boolean,
#							active => boolean,
#							level => number,
#							starttime => datetime,
#							status => boolean,
#							id => number (unique ID for each challenge, use with nike_chal_detail() ),
#							comparator => number,
#							unit => text (km or mi),
#							type => text,
#							quickchallenge => boolean,
#							},
#		};
#
#$number_of_challenges (total number of challenges)
sub nike_user_challenges {
	
	my $content = get( $user_chal_url );
	my $parse_content = XMLin( $content );	
	my $chals_ref = $parse_content->{challengeList}->{challenge};
	my $number_of_challenges = keys %$chals_ref;
	unless ( $number_of_challenges > 0 ) { return(undef,0); }
	my @chal_names = keys %$chals_ref;
	
	my %data;
	
	foreach my $challenge ( @chal_names ) {
		
		$data{$challenge}{owner} = $parse_content->{challengeList}->{challenge}->{$challenge}->{owner};
		$data{$challenge}{greeting} = $parse_content->{challengeList}->{challenge}->{$challenge}->{greeting};
		$data{$challenge}{status} = $parse_content->{challengeList}->{challenge}->{$challenge}->{status};
		$data{$challenge}{active} = $parse_content->{challengeList}->{challenge}->{$challenge}->{active};
		$data{$challenge}{level} = $parse_content->{challengeList}->{challenge}->{$challenge}->{level};
		$data{$challenge}{starttime} = $parse_content->{challengeList}->{challenge}->{$challenge}->{startTime};
		$data{$challenge}{id} = $parse_content->{challengeList}->{challenge}->{$challenge}->{id};
		
		$data{$challenge}{comparator} = $parse_content->{challengeList}->{challenge}->{$challenge}->{definition}->{comparatorValue};
		$data{$challenge}{unit} = $parse_content->{challengeList}->{challenge}->{$challenge}->{definition}->{displayUnit};
		$data{$challenge}{quickchallenge} = $parse_content->{challengeList}->{challenge}->{$challenge}->{definition}->{quickChallenge};
		$data{$challenge}{type} = $parse_content->{challengeList}->{challenge}->{$challenge}->{definition}->{type};
		
	}
	
	return(\%data, $number_of_challenges);
		
}

#Retrieve detailed data for a specific challenge
#Returns:
#Hash ref of challenge
#	$data = { 
#			member_name  => {
#							email => text,
#							invcode => text,
#							progress => number,
#							status => boolean,
#							screenname => text,
#							gender => text,
#							isowner => boolean,
#							},
#		};
#
#$number_of_challengers (total number of people in the challenge)
sub nike_chal_detail {
	
	my ( $chal_id ) = @_;
	my $content = get( "$chal_detail_url?id=$chal_id" );
	my $parse_content = XMLin( $content );
	
	my $chal_members_ref = $parse_content->{challenge}->{memberList}->{member};
	my $number_of_challengers = keys %$chal_members_ref;
	my @member_ids = keys %$chal_members_ref;
	my %data;
	
	foreach my $member ( @member_ids ) {
		
		$data{$member}{email} = $parse_content->{challenge}->{memberList}->{member}->{$member}->{email};
		$data{$member}{invcode} = $parse_content->{challenge}->{memberList}->{member}->{$member}->{invitationCode};
		$data{$member}{progress} = $parse_content->{challenge}->{memberList}->{member}->{$member}->{progress};
		$data{$member}{status} = $parse_content->{challenge}->{memberList}->{member}->{$member}->{status};
		$data{$member}{screenname} = $parse_content->{challenge}->{memberList}->{member}->{$member}->{screenname};
		$data{$member}{gender} = $parse_content->{challenge}->{memberList}->{member}->{$member}->{gender};
		$data{$member}{isowner} = $parse_content->{challenge}->{memberList}->{member}->{$member}->{owner};
		
	}
	
	return(\%data, $number_of_challengers);
		
}


1;
__END__
# Below is stub documentation for your module. You'd better edit it!

=head1 NAME

WWW::Nike::NikePlus - Perl extension for retrieving running data from www.nikeplus.com

=head1 SYNOPSIS

Example use that retrieves and prints your last run information

  use WWW::Nike::NikePlus;
  my $username = 'my@email.address';
  my $password = 'MySecretPassword';
  my $locale = "en_us";
  
  my $pin = nike_authenticate( $username, $password, $locale );
  unless( $pin ) { print "Authentication failed\n"; }
  
  #Details of the last run
  my ( $unit, $last_run_dist, $last_run_duration_millisecs, 
  	$last_run_duration_friendly, $last_run_pace_friendly ) = nike_last_run();
  
  print "Last run: $last_run_dist$unit in $last_run_duration_friendly\n";
  print "Last run pace: $last_run_pace_friendly per $unit\n";

=head1 DESCRIPTION

This module provides a Perl interface to the Nike+ running site and allows you to query most of the data
exposed by the Nike+ web API.

You can:
	Authenticate to Nike+ and obtain the login token and cookie
	Retrieve your last run
	Retrieve your personal settings (name, perferred units, avatar etc.)
	Retrieve data on all your runs, ever
	Get specific pace information on a run (not yet implemented, sorry!)
	List all your goals and whether you've completed them or not
	List all your challenges
	See who's taking part in your challenges, and how they're doing
	Display direct URL links to home page/runs/goals/challenges that use the token to bypass login (CAUTION!)

=head1 FUNCTIONS

This module provides all the following functions, which are all exported
by default when you call C<use WebService::NikePlus;>.

=over

=item nike_authenticate( username, password, locale )

Carries out the authentication against Nike+ with the provided username, password and locale.

Returns the pin (token) if successful, or undef if authentication failed

You B<must> call C<nike_authenticate()> before calling any of the other functions.

=item nike_web_links( pin )

Once authenticated and you have $pin, you can call C<nike_web_links( $pin )> to return direct URLs to various www.nikeplus.com
web pages.

E.g. to find out the URLs for the front, challenge, goals and runs pages bypassing authentication:

	( $front_page, $chals_page, $goals_page, $runs_page ) = nike_web_links( $pin )

Exercise caution if using this module with (for example) a public facing CGI script. By obtaining the pin/token and 
following these URLs B<anyone> would be able to access your Nike+ account!

=item nike_last_run()

Retrieve details for the last run.

Returns:
( distance unit, last run distance, last run time (in ms), last run time (in friendly format), last run pace (mins/secs per km/mi) (in friendly format) )

E.g. to find out everything about your last run:

	( $unit, $last_run_dist, $last_run_duration_millisecs, $last_run_duration_friendly, $last_run_pace_friendly ) = nike_last_run()


=item nike_run_totals()

Retrieve lifetime run totals

Returns:
( total number of runs, total distance run, total run tims (in ms), total run time (in friendly format)

E.g. to find out how far and how long you've run all time:

	( $total_run_num, $total_run_dist, $total_run_duration_millisecs, $total_run_duration_friendly ) = nike_run_totals()

=item nike_run_averages()

Retrieve lifetime run averages

Returns:
( distance unit, average distance per run, average time per run (ms), average time per run (friendly), average pace (mins/secs / km/mi)

E.g. to find out your overall averages across every run you've ever done:

	( $unit, $average_dist, $average_time_millisecs, $average_time_friendly, $average_run_pace_friendly ) = nike_run_averages()

=item nike_runs_list()

Retrieve list of all runs to date, with basic details

Returns:
( hash ref of data, total number of runs)

Hash ref data structure:

	$data = { 
		run_number (starts at 0) => {
					synctime => datetime,
					distance => number (use $unit from nike_last_run() ),
					name => text (user specified name),
					calories => number (cals calculated to be burnt, requires weight to be specified),
					duration => number (run length in ms),
					starttime => datetime,
					nike_id => number (unique ID for each run, use with nike_run_detail() ),
					description => text,
					},
	};

E.g. to print out the distances of each run you've done:

	my ( $run_data_ref, $run_num ) = nike_runs_list();
	my %run_data = %$run_data_ref;
	my $run = 0;
	while ( $run < $run_num ) {	
		print $run_data{$run}{distance};
		print "\n";
		$run++;	
	}

=item nike_run_detail( run_id )

Not yet impletemented

Will eventually take a run id (see nike_runs_list()) and output data so that you can see how you performed over the course of a run.
This is not implemented for now as the web interface at Nike+ does a much better job at graphing than I can manage!

=item nike_user_goals()

Retrieve a list of all your goals

Returns:
( hash ref of data, total number of goals, number of completed goals)

Hash ref data structure:

	$data = { 
		goal_number (starts at 0) => {
						level => number,
						endtime => datetime,
						starttime => datetime,
						complete => boolean,
						type => text,
						progress => text,
						},
	};

E.g. to list all the types you have:

	my ( $goal_data_ref, $num_of_goals, $goals_complete ) = nike_user_goals();
	print "$goals_complete/$num_of_goals goals completed\n";
	my %goal_data = %$goal_data_ref;
	my @goal_ids = keys %goal_data;
	foreach my $goal ( @goal_ids ) {
		print $goal_data{$goal}{type};
		print "\n";
	}

=item nike_user_challenges()

Retrieve a list of all your challenges

Returns:
( hash ref of data, number of challenges )

Hash ref data structure:

	$data = { 
		challenge_name  => {
					owner => text,
					greeting => text,
					status => boolean,
					active => boolean,
					level => number,
					starttime => datetime,
					status => boolean,
					id => number (unique ID for each challenge, use with nike_chal_detail() ),
					comparator => number,
					unit => text (km or mi),
					type => text,
					quickchallenge => boolean,
					},
	};

E.g. to display all the challenge IDs you're associated with:

	my ( $chal_data_ref, $num_of_chals ) = nike_user_challenges();
	my %chal_data = %$chal_data_ref;
	my @chal_names = keys %chal_data;
	foreach my $challenge ( @chal_names ) {
		print "$chal_data{$challenge}{id}\n";
	}

=item nike_chal_detail( challenge_id );

Retrieve detailed list of participants in a challenge. Required argument of the challenge ID - use nike_user_challenges() 
above to obtain list of all challenges and their IDs.

Returns:
( hash ref of data, number of challengers )

Hash ref data structure:

	$data = { 
		member_name  => {
					email => text,
					invcode => text,
					progress => number,
					status => boolean,
					screenname => text,
					gender => text,
					isowner => boolean,
					},
	};

E.g. to list the (first part) of each challenger's email address and their progress so far for a given challenge ID:

	my ( $chal_detail_ref, $number_of_challengers) = nike_chal_detail( 123456 );
	my %chal_detail = %$chal_detail_ref;
	my @member_names = keys %chal_detail;
	foreach my $member ( @member_names ) {
		print $chal_detail{$member}{email};
		print ": ";
		print $chal_detail{$member}{progress};
		print "\n";
	}


=back


=head1 SEE ALSO

L<http://www.nikeplus.com>


=head1 AUTHOR

Alex LomasE<lt>alexlomas at cpan dot orgE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2007 by Alex Lomas

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.8 or,
at your option, any later version of Perl 5 you may have available.


=cut
