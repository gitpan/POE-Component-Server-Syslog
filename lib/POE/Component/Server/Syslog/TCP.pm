# $Id: TCP.pm 446 2004-12-27 00:57:57Z sungo $
package POE::Component::Server::Syslog::TCP;

use warnings;
use strict;

our $VERSION = '1.04';

sub BINDADDR        () { '0.0.0.0' }
sub BINDPORT        () { 514 }
sub DATAGRAM_MAXLEN () { 1024 }  # syslogd defaults to this. as do most 
                                 # libc implementations of syslog

use Params::Validate qw(validate_with);
use Carp qw(carp croak);
use Socket;

use POE qw(
	Driver::SysRW
	Wheel::SocketFactory
	Wheel::ReadWrite
	Filter::Syslog
);


sub spawn {
	my $class = shift;

	my %args = validate_with(
		params => \@_,
		spec => {
			InputState   => {
				type     => &Params::Validate::CODEREF,
			},
			ErrorState   => {
				type     => &Params::Validate::CODEREF,
				optional => 1,
				default  => sub {},
			},
			BindAddress  => {
				type     => &Params::Validate::SCALAR,
				optional => 1,
				default  => BINDADDR,
			},
			BindPort     => {
				type     => &Params::Validate::SCALAR,
				optional => 1,
				default  => BINDPORT,
			},
			MaxLen       => {
				type     => &Params::Validate::SCALAR,
				optional => 1,
				default  => DATAGRAM_MAXLEN,
			},
		},
	);

	$args{type} = 'tcp';
	$args{filter} = POE::Filter::Syslog->new();

	my $sess = POE::Session->create(
		inline_states => {
			_start         => \&start,
			_stop          => \&shutdown,

			socket_connect => \&socket_connect,
			socket_error   => \&socket_error,
			socket_input   => \&socket_input,
			shutdown       => \&shutdown,

			client_input => $args{InputState},
			client_error => $args{ErrorState},

		},
		heap => \%args,
	);


	return $sess;
}

sub start {
	$_[HEAP]->{socketfactory} = POE::Wheel::SocketFactory->new(
		BindAddress  => $_[HEAP]->{BindAddress},
		BindPort     => $_[HEAP]->{BindPort},
		SuccessEvent => 'socket_connect',
		FailureEvent => 'client_error',
		ListenQueue  => $_[HEAP]->{MaxLen},
		Reuse        => 'yes',
	);

	unless($_[HEAP]->{socketfactory}) {
		croak("Unable to setup socketfactory");
	}
}

sub socket_connect {
	my $handle = $_[ARG0];
	my $host;

	if( ( sockaddr_in( getpeername($handle) ) )[1]) {
		$host = gethostbyaddr( ( sockaddr_in( getpeername($handle) ) )[1], AF_INET );
	} else {
		$host = '[unknown]';
	}

	my $wheel = POE::Wheel::ReadWrite->new(
		Handle     => $handle,
		Driver     => POE::Driver::SysRW->new(),
		Filter     => POE::Filter::Syslog->new(),
		InputEvent => 'socket_input',
		ErrorEvent => 'socket_error',
	);

	$_[HEAP]->{wheels}->{ $wheel->ID } = {
		wheel => $wheel,
		host  => $host,
	};
}

sub socket_error {
	my ($errop, $errnum, $errstr, $wid) = @_[ARG0 .. ARG3];
	unless( ($errnum == 0) && ($errop eq 'read') ) {
		$_[KERNEL]->yield( 'client_error', $errop, $errnum, $errstr );
	}
	delete $_[HEAP]->{wheels}->{ $wid };
}

sub socket_input {
	my ($input, $wid) = @_[ARG0, ARG1];
	my $info = $_[HEAP]->{wheels}->{ $wid };

	if(ref $input && ref $input eq 'ARRAY') {
		foreach my $record (@{ $input }) {
			$input->{host} = $info->{host};
			$_[KERNEL]->yield( 'client_input', $record );
		}
	} elsif(ref $input && ref $input eq 'HASH') {
		$input->{host} = $info->{host};
		$_[KERNEL]->yield( 'client_input', $input );
	} else {
		$_[KERNEL]->yield( 'client_error', $input );
	}
}

sub shutdown {
	if($_[HEAP]->{socketfactory}) {
		$_[HEAP]->{socketfactory}->pause_accept();
		delete $_[HEAP]->{socketfactory};
	}
}


1;
__END__

=pod

=head1 NAME

POE::Component::Server::Syslog::TCP

=head1 SYNOPSIS

    POE::Component::Server::Syslog::TCP->spawn(
        BindAddress => '127.0.0.1',
        BindPort    => '514',
        InputState  => \&input,
    );

    sub input {
        my $message = $_[ARG0];
        # .. do stuff ..
    }

=head1 DESCRIPTION

This component provides very simple syslog services for POE.

=head1 METHODS

=head2 spawn()

Spawns a new listener. Requires one argument, C<InputState>, which must
be a reference to a subroutine. This argument will become a POE state
that will be called when input from a syslog client has been recieved.
Returns the POE::Session object it creates.

C<spawn()> also accepts the following options:

=over 4

=item * BindAddress

The address to bind the listener to. Defaults to 0.0.0.0

=item * BindPort

The port number to bind the listener to. Defaults to 514

=item * MaxLen

The maximum length of a datagram. Defaults to 1024, which is the usual
default of most syslog and syslogd implementations.

=item * ErrorState

An optional code reference. This becomes a POE state that will get
called when the component recieves a message it cannot parse. The
erroneous message is passed in as ARG0.

=back

=head2 InputState

The ClientInput routine obtained by C<spawn()> will be passed a hash
reference as ARG0 containing the following information:

=over 4

=item * time

The time of the datagram (as specified by the datagram itself)

=item * pri

The priority of message.

=item * facility

The "facility" number decoded from the pri.

=item * severity

The "severity" number decoded from the pri.

=item * host

The host that sent the message.

=item * msg

The message itself. This often includes a process name, pid number, and
user name.

=back

=head1 DATE

$Date: 2004-12-26 19:57:57 -0500 (Sun, 26 Dec 2004) $

=head1 REVISION

$Rev: 446 $

Note: This does not necessarily correspond to the distribution version number.


=head1 AUTHOR

Matt Cashner (sungo@cpan.org)

=head1 LICENSE

Copyright (c) 2003-2004, Matt Cashner. All rights reserved.

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are
met:

=over 4

=item * Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.

=item * Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.

=item * Neither the name of the Matt Cashner nor the names of its contributors may be used to endorse or promote products derived from this software without specific prior written permission.

=back

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
"AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
(INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

=cut

1;
__END__

# sungo // vim: ts=4 sw=4 noexpandtab
