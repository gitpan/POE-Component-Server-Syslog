# $Id: UDP.pm 449 2004-12-27 01:37:33Z sungo $
package POE::Component::Server::Syslog::UDP;

use warnings;
use strict;

our $VERSION = '1.'.sprintf "%04d", (qw($Rev: 449 $))[1];

sub BINDADDR        () { '0.0.0.0' }
sub BINDPORT        () { 514 }
sub DATAGRAM_MAXLEN () { 1024 }  # syslogd defaults to this. as do most 
                                 # libc implementations of syslog

use Params::Validate qw(validate_with);
use Carp qw(carp croak);

use POE;
use POE::Filter::Syslog;

use Socket;
use IO::Socket::INET;

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

	$args{type} = 'udp';
	$args{filter} = POE::Filter::Syslog->new();

	my $sess = POE::Session->create(
		inline_states => {
			_start         => \&socket_start,
			_stop          => \&shutdown,

			select_read    => \&select_read,
			shutdown       => \&shutdown,

			client_input => $args{InputState},
			client_error => $args{ErrorState},

		},
		heap => \%args,
	);

	return $sess;
}


# This is a really good spot to discuss why this is using IO::Socket
# instead of a POE wheel of some variety for this. The answer, for once
# in my life, is pretty simple. POE::Wheel::SocketFactory doesn't support
# connectionless sockets as of the time of writing. In this scenario,
# there is no chance of IO::Socket blocking, unless IO::Socket decides
# to lose its mind. If it does THAT, there's not a whole hell of a lot
# left that's right in the world. :) except maybe pizza. well, good
# pizza like you find at Generous George's in Alexandria, VA. and rum.
# pretty much any rum. Um, but anyway...

sub socket_start {
	$_[HEAP]->{handle} = IO::Socket::INET->new(
		Blocking   => 0,
		LocalAddr  => $_[HEAP]->{BindAddress},
		LocalPort  => $_[HEAP]->{BindPort},
		Proto      => 'udp',
		ReuseAddr  => 1,
		SocketType => SOCK_DGRAM,
	);

	if (defined $_[HEAP]->{handle}) {
		$_[KERNEL]->select_read( $_[HEAP]->{handle}, 'select_read' );
	} else {
		croak "Unable to create UDP Listener: $!";
	}
}

sub select_read {
	my $message;
	my $remote_socket = $_[HEAP]->{handle}->recv($message, $_[HEAP]->{MaxLen}, 0 );
	if (defined $message) {
		$_[HEAP]->{filter}->get_one_start([ $message ]);
		my $records = [];
		while( ($records = $_[HEAP]->{filter}->get_one()) and (@$records > 0)) {
			if(defined $records and ref $records eq 'ARRAY') {
				foreach my $record (@$records) {
					if( ( sockaddr_in( $remote_socket ) )[1]) {
						$record->{host} = gethostbyaddr(
							( sockaddr_in( $remote_socket ) )[1],
							AF_INET,
						);
					} else {
						$record->{host} = '[unknown]';
					}

					$_[KERNEL]->yield( 'client_input', $record );
				}
			} else {
				$_[KERNEL]->yield( 'client_error', $message );
			}
		}
	}
}

sub shutdown {
	if($_[HEAP]->{handle}) {
		$_[KERNEL]->select_read($_[HEAP]->{handle});
		$_[HEAP]->{handle}->close();
	}
	delete $_[HEAP]->{handle};
}


1;
__END__

=pod

=head1 NAME

POE::Component::Server::Syslog::UDP

=head1 SYNOPSIS

    POE::Component::Server::Syslog::UDP->spawn(
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

$Date: 2004-12-26 20:37:33 -0500 (Sun, 26 Dec 2004) $

=head1 REVISION

$Rev: 449 $

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
