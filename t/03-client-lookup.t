#!/usr/bin/perl
#
# test POE::Component::Server::Syslog::host
#

use strict;
use warnings;

use Test::More qw(no_plan);
use POE::Component::Server::Syslog;
use POE;

use IO::Socket::INET;

sub send_udp {
    my $sock = IO::Socket::INET->new(
	PeerPort  => 9999,
	PeerAddr  => 'localhost',
	Proto     => 'udp',
    ) or die "Can't bind : $@\n";

    $sock->send("<1> sungo: pie");
}

POE::Component::Server::Syslog->spawn(
    BindAddress => '127.0.0.1',
    BindPort    => 9999,
    InputState  => \&input,
);

sub input {
    my $msg = $_[ARG0];

    is($msg->{'facility'}, 0, "facility is not what we expected");
    is($msg->{'severity'}, 1, "severity is not what we expected");
    is($msg->{'msg'}, "sungo: pie", "severity is not what we expected");
    ok(defined $msg->{'host'}, "host is not defined");
    is($msg->{'host'}, 'localhost', "host is not what we expected");

} 

POE::Session->new(
    _start => sub {
	$_[KERNEL]->delay(send => 0.1);
    },
    send   => sub {
	send_udp();
	$_[KERNEL]->delay(cleanup => 0.1);
    } ,
    cleanup => sub { exit 0 },
) or die "$0: session could not be started";

$poe_kernel->run();
