# $Id: Makefile.PL 438 2004-11-28 23:50:30Z sungo $

use 5.006001;
use ExtUtils::MakeMaker;
use File::Find;

my @tests;
sub wanted { /\.t$/ && push @tests, $_ }
find( { wanted => \&wanted, no_chdir => 1 }, 't/' );
@tests = sort @tests;

WriteMakefile(
	NAME => 'POE::Component::Server::Syslog',

	AUTHOR   => 'Matt Cashner (sungo@pobox.com)',
	ABSTRACT => 'Provides syslog server ability for POE',

	VERSION_FROM => 'VERSION',
	dist         => {
		'COMPRESS' => 'gzip -9f',
		'SUFFIX'   => 'gz',
	},
	test => {
		TESTS => join " ", @tests
	},
	PREREQ_PM => {
		'POE'              => '0.24',
		'Params::Validate' => 0,
		'IO::Socket'       => 0,
		'Time::ParseDate'  => 0,
		'Test::More'       => 0,
		'Carp'             => 0,
	},
	dist => {
		PREOP => 'svn log --non-interactive -r 0:HEAD > ${DISTVNAME}/Changes; perldoc -t lib/POE/Component/Server/Syslog.pm > ${DISTVNAME}/README',
	},
);

