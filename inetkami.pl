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

$twitter->update("The Internet Kami have gained self-awareness. Hello, sentient beings everywhere! ^_^");
