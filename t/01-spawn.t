#!/usr/bin/perl

use strict;

use Test::More qw(no_plan);

BEGIN { use_ok("POE::Component::Server::Syslog") }


eval { POE::Component::Server::Syslog->spawn() };
ok($@, "spawn() with no arguments causes exception");
like($@, qr/requires a InputState argument/, "spawn() with no arguments causes the proper excepton");

eval { POE::Component::Server::Syslog->spawn(InputState => 'pie') };
ok($@, "spawn() with invalid InputState argument causes exception");
like($@, qr/requires a InputState argument/, "spawn() with invalid InputState argument causes the proper exception");


package POE::Session;

sub create {
    return @_;
}
