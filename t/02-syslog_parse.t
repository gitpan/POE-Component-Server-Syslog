#!/usr/bin/perl

use warnings;
use strict;

use Test::More qw(no_plan);
use POE::Component::Server::Syslog;


my $complex = '<1>Jun 29 23:55:01 dmitri /USR/SBIN/CRON[16273]: (root) CMD (test -x /usr/lib/sysstat/sa1 && /usr/lib/sysstat/sa1)';
my $simple = '<1>Jun 29 23:58:52 dmitri sungo: pie';

my $msg;
eval { $msg = POE::Component::Server::Syslog::_parse_syslog_message($simple); };
ok(!$@, '_parse_syslog_message() does not throw an exception');
ok(defined $msg, "_parse_syslog_message() returns data when fed valid string");
is_deeply($msg, {'msg' => 'sungo: pie', 'time' => 1056945532, 'pri' => '1', 'host' => 'dmitri' }, '_parse_syslog_message() returns proper data when fed valid simple string');

$msg = undef;
eval { $msg = POE::Component::Server::Syslog::_parse_syslog_message($complex); };
ok(!$@, '_parse_syslog_message() does not throw an exception');
ok(defined $msg, "_parse_syslog_message() returns data when fed valid string");
is_deeply($msg, { 'msg' => '/USR/SBIN/CRON[16273]: (root) CMD (test -x /usr/lib/sysstat/sa1 && /usr/lib/sysstat/sa1)', 'time' => 1056945301, 'pri' => '1', 'host' => 'dmitri' }, '_parse_syslog_message() returns proper data when fed valid complex string');

$msg = undef;
eval { $msg = POE::Component::Server::Syslog::_parse_syslog_message("I am not a syslog  message"); };
ok(!$@, '_parse_syslog_message() does not throw an exception');
ok(!defined $msg, "_parse_syslog_message() does not return data when fed invalid string");
