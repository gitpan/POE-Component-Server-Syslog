#!/usr/bin/perl

use warnings;
use strict;

use POE;
use POE::Component::Server::Syslog;
use Data::Dumper;

POE::Component::Server::Syslog->spawn(
    BindPort => 4095,
    ClientInput => \&client_input,
    ClientError => \&client_error,
);

$poe_kernel->run();

######################################

sub client_input {
    my $msg = $_[ARG0];
    print Dumper $msg;
}

sub client_error {
    warn "BAD MESSAGE: $_[ARG0]";
}
