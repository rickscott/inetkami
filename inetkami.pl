#!/usr/bin/perl

use 5.010;
use warnings;
use strict;

use Net::Twitter;
use Config::General;
use Data::Dumper; # XXX DEBUG

use Config::General;
my $config = new Config::General("inetkami.cfg");
my %conf = $config->getall;

my $twitter = Net::Twitter->new(
    traits              => [qw/API::REST OAuth/],
    consumer_key        => $conf{'consumer_key'},
    consumer_secret     => $conf{'consumer_secret'},
    access_token        => $conf{'access_token'},
    access_token_secret => $conf{'access_token_secret'},
);

# $twitter->update("The Internet Kami have gained self-awareness. Hello, sentient beings everywhere! ^_^");

# startup. get the API limit

say "API calls left for this hour: " . Dumper($twitter->rate_limit_status);

# pull the database if there is one, create it if not 

# main loop 
# for(;;) {
    # check for mentions & process
    my $mentions = $twitter->mentions();
    say Dumper($mentions);

    # check for DMs and process
#my $twitter->direct_messages( since_id )
  
# }

# start by getting API req per hour
# and use that to yield how frequently to check for DMs and replies
## 350req/hr = one req every 10s or so
## how to distribute this, @replies vs DMs?
## if we get to the point of more than 20 replies/DMs for each poll,
## we will have to paginate, which will cut into our API call limit
## even more...

## streaming API may be the answer to this? Check.
## and does Net::Twitter support it?


# main loop (singlethread this for now for simplicity...?)
# check for @replies - allowed 200 at a time 
## https://dev.twitter.com/docs/api/1/get/statuses/mentions
##  process each @reply
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

