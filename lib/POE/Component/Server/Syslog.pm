# $Id: Syslog.pm,v 1.9 2003/07/04 04:06:55 sungo Exp $
package POE::Component::Server::Syslog;

# Docs at the end.

use 5.006001;
use warnings;
use strict;

use IO::Socket;
use POE;
use Carp;
use Time::ParseDate;

our $VERSION = (qw($Revision: 1.9 $))[1];

sub BINDADDR        () { '127.0.0.1' }
sub BINDPORT        () { 514 }
sub DATAGRAM_MAXLEN () { 1024 }  # syslogd defaults to this. as do most 
                                 # libc implementations of syslog

sub spawn {

    my $class = shift;
    my %args = @_;
    
    croak( __PACKAGE__
        . "->spawn() requires a InputState argument which must be a subroutine reference"
      )
      unless ( ( defined $args{InputState} )
        and ( ref $args{InputState} eq 'CODE' ) );
   
    return POE::Session->create(
        inline_states => {
            _start       => \&_start,
            _stop        => \&_stop,
            select_read  => \&select_read,
            client_input => $args{InputState},
            client_error => $args{ErrorState} || sub { 'i like pie' },
        },
        heap => { 
            BindAddress => $args{BindAddress} || BINDADDR, 
            BindPort    => $args{BindPort}    || BINDPORT, 
            MaxLen      => $args{MaxLen}      || DATAGRAM_MAXLEN,
        },
    );
}

# This is a really good spot to discuss why this is using IO::Socket
# instead of a POE wheel of some variety for this. The answer, for once
# in my life is pretty simple. POE::Wheel::SocketFactory doesn't support
# connectionless sockets as of the time of writing. In this scenario,
# there is no chance of IO::Socket blocking, unless IO::Socket decides
# to lose its mind. If it does THAT, there's not a whole hell of a lot
# left that's right in the world. :) except maybe pizza. well, good
# pizza like you find at Generous George's in Alexandria, VA. and rum.
# pretty much any rum. Um, but anyway...
sub _start {
    if ( defined(
        $_[HEAP]->{socket_handle} = IO::Socket::INET->new(
              Blocking   => 0,
              LocalAddr  => $_[HEAP]->{BindAddress},
              LocalPort  => $_[HEAP]->{BindPort},
              Proto      => 'udp',
              ReuseAddr  => 1,
              SocketType => SOCK_DGRAM,
        ) ) )
    {
        $_[KERNEL]->select_read( $_[HEAP]->{socket_handle}, 'select_read' );
    }
    else {
        warn "server error: $!";
    }
}

sub _stop {
    delete $_[HEAP]->{socket_handle};
}

sub select_read {
    my $message;
    my $remote_socket =
      recv( $_[HEAP]->{socket_handle}, $message, $_[HEAP]->{MaxLen}, 0 );
    if ( defined $message ) {
        if(my $msg = _parse_syslog_message($message)) {
            $_[KERNEL]->yield( 'client_input', $msg );
        } else {
            $_[KERNEL]->yield( 'client_error', $message );
        }
    }
}

sub _parse_syslog_message {
    my $str = shift;

    # The following regexp is derived from Parse::Syslog by David Schweikert 
    # <dws@ee.ethz.ch> which is Copyright (c) 2001 Swiss Federal
    # Institute of Technology, Zurich. 
    if ( $str =~ /^<(\d+)>         # priority -- 1
            (?: 
                (\S{3})\s+(\d+)    # month day -- 2, 3
                \s
                (\d+):(\d+):(\d+)  # time  -- 4, 5, 6
            )?
            \s*
            (.*)                   # text  --  7
            $/x
      )
    {
        my $time = $2 && parsedate("$2 $3 $4:$5:$6");
        my $msg  = {
            time => $time,
            pri  => $1,
            facility => int($1/8),
            severity => int($1%8),
            msg  => $7,
        };

        return $msg;
    }
    else {
        return undef;
    }
}

1;
__END__

=pod

=head1 NAME

POE::Component::Server::Syslog - syslog services for POE

=head1 AUTHOR

Matt Cashner (sungo@cpan.org)

=head1 SYNOPSIS

    POE::Component::Server::Syslog->spawn(BindAddress => '127.0.0.1',
                                          BindPort    => '514',
                                          InputState  => \&input,
                                         );

    sub input {
        my $message = $_[ARG0];
        # .. do stuff ..
    }

=head1 DESCRIPTION

This component provides very simple UDP Syslog services for POE (named pipe and
other syslog interoperability features are expected in future versions). 

=head1 METHODS

=head2 spawn()

Spawns a new udp listener. Requires one argument, InputState which must
be a reference to a subroutine. This argument will become a POE state
that will be called when input from a syslog client has been recieved.
Returns the POE::Session object it creates.

C<spawn()> also accepts the following options:

=over 4

=item * BindAddress

The address to bind the listener to. Defaults to 127.0.0.1

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

The priority of message

=item * facility

The "facility" number decoded from the pri

=item * severity

The "severity" number decoded from the pri

=item * host

The host the message claims to have come from

=item * msg

The message itself. This often includes a process name, pid number, and
user name.

=back

=head1 DATE

$Date: 2003/07/04 04:06:55 $

=head1 REVISION

$Revision: 1.9 $

Note: This does not necessarily correspond to the distribution version number.

=head1 BUGS AND ISSUES

=over 4

=item * Need to export constants for standard names for priorities.

=item * WRITE TESTS

=back

=head1 THANKS

Many thanks to the POE community for being so supportive and wonderful. 
Infinite thanks to Rocco Caputo for POE in the first place, for being a 
wonderful second set of eyes, and for the code on which this is conceptually 
based. 

Thanks to Chris Fedde for providing patches to make this suck less. His code is
provided in the public domain and is available under the license terms below.

=head1 LICENSE

Copyright (c) 2003, Matt Cashner

Permission is hereby granted, free of charge, to any person obtaining 
a copy of this software and associated documentation files (the 
"Software"), to deal in the Software without restriction, including 
without limitation the rights to use, copy, modify, merge, publish, 
distribute, sublicense, and/or sell copies of the Software, and to 
permit persons to whom the Software is furnished to do so, subject 
to the following conditions:

The above copyright notice and this permission notice shall be included 
in all copies or substantial portions of the Software.

THIS SOFTWARE IS PROVIDED BY THE AUTHOR ``AS IS'' AND ANY EXPRESS OR IMPLIED
WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF
MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO
EVENT SHALL THE AUTHOR BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS;
OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,
WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR
OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF
ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

=cut

