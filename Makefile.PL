#!/usr/bin/perl
# $Id: Makefile.PL,v 1.3 2003/06/26 05:43:55 sungo Exp $

use ExtUtils::MakeMaker;
use File::Find;

my @tests;
sub wanted { /\.t$/ && push @tests, $_ }
find( { wanted => \&wanted, no_chdir => 1 }, 't/' );
@tests = sort @tests;
WriteMakefile(
    NAME => 'POE::Component::Server::Syslog',

    ( ( $^O eq 'MacOS' ) ? () : (
          AUTHOR   => 'Matt Cashner (eek+cpan@eekeek.org)',
          ABSTRACT => 'Provides syslog server ability for POE',
    ) ),

    VERSION_FROM => 'VERSION',
    dist         => {
        'COMPRESS' => 'gzip -9f',
        'SUFFIX'   => 'gz',
    },
    test => {
        TESTS => join " ",
        @tests
    },
    PREREQ_PM => {
        'POE'             => '0.24',
        'IO::Socket'      => 0,
        'Time::ParseDate' => 0,
        'Test::More'      => 0,
        'Carp'            => 0,
    },
);

