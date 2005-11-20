# $Id: Makefile.PL 578 2005-11-20 22:52:08Z sungo $

use 5.006001;
use inc::Module::Install;

name            ('POE-Component-Server-Syslog');
author          ('Matt Cashner (sungo@pobox.com)');
version_from    ('VERSION');
license         ('bsd');

requires        ('POE' => 0.24);
requires        ('Params::Validate');
requires        ('IO::Socket');
requires        ('Time::ParseDate');
requires        ('Test::More');
requires        ('Carp');

sign            (1);

WriteAll();
