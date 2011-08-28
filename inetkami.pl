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

my $metar_url = $conf{'metar_url'};
my $taf_url   = $conf{'taf_url'};

# open the database if there is one, create it if not 
my $db = DBM::Deep->new("inetkami.db");
$db->{last_mention} = 0 unless exists $db->{last_mention};
$db->{last_dm}      = 0 unless exists $db->{last_dm};


# determine how long to wait between fetches.
my $rate_limit     = $twitter->rate_limit_status;
my $api_per_hour   = $rate_limit->{hourly_limit};
my $api_hits_left  = $rate_limit->{remaining_hits};
my $fetch_delay = ceil(3600 / $api_per_hour); 

say "API calls per hour: $api_per_hour. One fetch every $fetch_delay sec.";
say "Current API hits remaining: $api_hits_left.";


# main loop 
FETCH:
while(1) {
    my $mentions;

    eval {
        $mentions = $twitter->mentions({
            count => 200, since_id => $db->{last_mention}
        });
    };
    if ($@) {
        handle_error($@);
        next FETCH;
    }

    say sprintf("** last mention proc'd: %s; %s new.", 
        $db->{last_mention}, scalar @$mentions
    );

    MENTION:
    foreach my $mention (@$mentions) {
        say "Examining mention $mention->{id}.";

        if ($mention->{id} <= $db->{last_mention}) {
            warn "%%% Twitter gave us a mention out of order! %%%";
            next MENTION;
        }

        say "Processing mention $mention->{id}.";

        ### METAR / TAF / WX
        if ($mention->{text} =~ /^\@inetkami (metar|taf|wx) ([a-z]{4})/i) {
            my $command = uc($1); 
            my $station = uc($2); 
            say "** $command request for station $station.";

            handle_wx($twitter, $mention, $command, $station)
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


    # check for DMs and process: TODO
    #my $twitter->direct_messages( since_id )

}
continue {
    say '-' x 68;
    sleep $fetch_delay;
} #end of main loop

# handle_wx: handle a req for metar, taf, or wx (both metar & taf)
sub handle_wx {
    my $twitter = shift;
    my $mention = shift;
    my $command = shift;   # one of 'METAR', 'TAF', 'WX'
    my $station = shift;   # 4 letters, uppercase

    my $mech = WWW::Mechanize->new();

    # return METAR for given station 
    unless($command eq 'TAF') {
        $mech->get( $metar_url . $station . '.TXT');
        my $wx = $mech->content();  # FIXME: handle failure

        my $reply = sprintf('@%s %s', $mention->{user}->{screen_name}, $wx);
        send_reply(
            $twitter, $mention->{id}, $mention->{user}->{screen_name}, $reply
        ); 
    }  

    # return TAF for given station 
    unless($command eq 'METAR') {
        $mech->get( $taf_url . $station . '.TXT');
        my $wx = $mech->content();  # FIXME: handle failure

        my $reply = sprintf('@%s %s', $mention->{user}->{screen_name}, $wx);
        send_reply(
            $twitter, $mention->{id}, $mention->{user}->{screen_name}, $reply
        ); 
    }  
}

sub send_reply {
    my $twitter = shift;
    my $in_reply_to = shift;
    my $reply_to_user = shift;
    my $msg = shift;


    my $reply_string = sprintf('@%s %s', $reply_to_user, $msg);
    if (length($reply_string) > 140) {  # FIXME: Unicode / char semantics
        $reply_string = substr($reply_string, 0, 139) . '>';
    }

    say '** Sending reply: ' . $reply_string;

    $twitter->update({
        in_reply_to_status_id => $in_reply_to,
        status                => $reply_string
    });
}


# ref: https://dev.twitter.com/docs/error-codes-responses
sub handle_error {
    my $error = shift;

    warn "%% ERROR: $error";

    given ($error->code) {
        when ([304, 406]) {        # we should never see these; ignore
            say "Ignoring...";
        }
        when (401) {               # login fail; bail out entirely
            die "Login failure -- please correct my credentials";
        }
        when ([400, 420]) {        # we hit the request ratelimit >_<
            sleep 3600;   # TODO more intelligent strategy =)
        }
        when (403) {               # we hit the update ratelimit >_<
            sleep 3600;   # TODO more intelligent strategy =)
        }
        when ([500, 502, 503]) {   # twitter is having issues
            sleep 3 * $fetch_delay;   # cut them a break =)
        }
        default {                  # something else bad happened
            die "Some error happened that I can't deal with =(";
        }
    } 
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

