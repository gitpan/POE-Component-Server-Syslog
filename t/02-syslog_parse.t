#!/usr/bin/perl

use warnings;
use strict;

use Test::More qw(no_plan);
use POE::Component::Server::Syslog;
use POSIX 'strftime';

#
# Syslog uses an ambiguous datetime format.  No year and no timezone.
#

#
# correct this test for timezone issues
#
my $now = time();
my $ts = strftime("%b %d %H:%M:%S", localtime($now));

my $complex = "<1>$ts /USR/SBIN/CRON[16273]: (root) CMD (test -x /usr/lib/sysstat/sa1 && /usr/lib/sysstat/sa1)";
my $simple = "<1>$ts sungo: pie";
my $nodate = '<78>CROND[19679]: (root) CMD (/usr/bin/mrtg /etc/mrtg/mrtg.cfg)';

my $msg;

#
# simple
#
eval { $msg = POE::Component::Server::Syslog::_parse_syslog_message($simple); };

ok(!$@, '_parse_syslog_message() does not throw an exception');
ok(defined $msg, "_parse_syslog_message() returns data when fed valid string");

is_deeply($msg, {
    'msg' => 'sungo: pie',
    'time' => $now,
    'pri' => '1',
    'facility' => 0,
    'severity' => 1,
    },
    '_parse_syslog_message() returns proper data when fed valid simple string'
);

#
# Complex
#
$msg = undef;
eval { $msg = POE::Component::Server::Syslog::_parse_syslog_message($complex); };
ok(!$@, '_parse_syslog_message() does not throw an exception');
ok(defined $msg, "_parse_syslog_message() returns data when fed valid string");

is_deeply($msg, {
    'msg' => '/USR/SBIN/CRON[16273]: (root) CMD (test -x /usr/lib/sysstat/sa1 && /usr/lib/sysstat/sa1)',
    'time' => $now,
    'pri' => '1',
    'facility' => 0,
    'severity' => 1,
    },
    '_parse_syslog_message() returns proper data when fed valid complex string');

#
# nodate
#
$msg = undef;
eval { $msg = POE::Component::Server::Syslog::_parse_syslog_message($nodate); };
ok(!$@, '_parse_syslog_message() does not throw an exception');
ok(defined $msg, "_parse_syslog_message() returns data when fed valid string");

is_deeply($msg, {
    'msg' => 'CROND[19679]: (root) CMD (/usr/bin/mrtg /etc/mrtg/mrtg.cfg)',
    'time' => undef,
    'pri' => '78', 
    'facility' => 9,
    'severity' => 6,
    },
    '_parse_syslog_message() returns proper data when given string with no date');

#
# bogus data
#
$msg = undef;
eval { $msg = POE::Component::Server::Syslog::_parse_syslog_message("I am not a syslog  message"); };
ok(!$@, '_parse_syslog_message() does not throw an exception');
ok(!defined $msg, "_parse_syslog_message() does not return data when fed invalid string");
