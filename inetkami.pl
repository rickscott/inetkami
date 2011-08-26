#!/usr/bin/perl

use 5.010;
use warnings;
use strict;

use Net::Twitter;
use Config::General;
use DBM::Deep;
use WWW::Mechanize;
use POSIX qw/ceil/;

use Data::Dumper; # XXX DEBUG

my $config = new Config::General("inetkami.cfg");
my %conf = $config->getall;

my $twitter = Net::Twitter->new(
    traits              => [qw/API::REST OAuth/],
    consumer_key        => $conf{'consumer_key'},
    consumer_secret     => $conf{'consumer_secret'},
    access_token        => $conf{'access_token'},
    access_token_secret => $conf{'access_token_secret'},
);


# open the database if there is one, create it if not 
my $db = DBM::Deep->new("inetkami.db");
$db->{last_mention} = 0 unless exists $db->{last_mention};
$db->{last_dm}      = 0 unless exists $db->{last_dm};


# determine how long to wait between fetches.
my $rate_limit     = $twitter->rate_limit_status;
my $api_per_hour   = $rate_limit->{hourly_limit};
my $api_hits_left  = $rate_limit->{remaining_hits};
# my $fetch_delay = ceil(3600 / $api_per_hour); 

# XXX just in case I have got things wrong
my $fetch_delay = ceil(3600 / ($api_per_hour * 0.7)); 

say "API calls per hour: $api_per_hour. One fetch every $fetch_delay sec.";
say "Current API hits remaining: $api_hits_left.";


# main loop 
for(;;) {

    say "** last mention processed was: " . $db->{last_mention};

    my $mentions = $twitter->mentions({
        count => 200, since_id => $db->{last_mention}
    });

    # say "All mentions from fetch: ";
    # say Dumper $mentions;
    # say "-----------------------";

    MENTION:
    foreach my $mention (@$mentions) {
        say "Examining mention $mention->{id}.";

        next MENTION if ($mention->{id} <= $db->{last_mention});

        say "Processing mention $mention->{id}.";

        ### METAR 
        if ($mention->{text} =~ /^\@inetkami metar (\w\w\w\w)/i) {
            my $station = $1; 
            say "** METAR request for station $1.";
            my $metar = `/usr/bin/metar $station`;
            my $reply = sprintf('@%s %s', $mention->{user}->{screen_name}, $metar);

            say "** Sending reply: $reply";
            $twitter->update({
                in_reply_to_status_id => $mention->{id},
                status => $reply,
            });
        }
        ### BWT 
        elsif ($mention->{text} =~ /^\@inetkami bwt/i) {
            say "** Border wait time request.";
            my $mech = WWW::Mechanize->new();
            $mech->get('http://apps.cbp.gov/bwt/display_rss_port.asp?port=380301');

            if ($mech->content() =~ m{<td headers="pv stdpv" [^>]*>([^/]+)</td>}) {
                my $bwt = $1;
                $bwt =~ s/<br>/, /g;
                my $reply = sprintf('@%s %s', $mention->{user}->{screen_name}, $bwt);

                say "** Sending reply: $reply";
                $twitter->update({
                    in_reply_to_status_id => $mention->{id},
                    status => $reply,
                });
            }

        }

        # done; update db to show we processed this mention
        $db->{last_mention} = $mention->{id};
    }

    say '-' x 68;
    sleep $fetch_delay;


 

    # check for DMs and process: TODO
    #my $twitter->direct_messages( since_id )
  
}

## how to distribute this, @replies vs DMs?
## if we get to the point of more than 200 replies/DMs for each poll,
## we will have to paginate, which will cut into our API call limit
## even more...I think that is far off though.
## at that point, time to look at the Streaming API ^_^;


# main loop (singlethread this for now for simplicity...?)
# check for @replies - allowed 200 at a time 
## https://dev.twitter.com/docs/api/1/get/statuses/mentions
##  process each @reply
## $twitter->update("@person foo");

# check for @DMs - again, max 200 at a time 
##  process each @DM
# what time is it?
# sleep until next interval...


# other modules that might be of interest
# public transit timetables
# hours of establishments
# traffic info, road closures
## take a look at my links page, see what I like =)
# google news search?

