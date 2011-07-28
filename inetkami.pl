#!/usr/bin/perl

use 5.010;
use warnings;
use strict;

use Net::Twitter;
use Config::Std;

read_config 'inetkami.cfg' => my %config;

