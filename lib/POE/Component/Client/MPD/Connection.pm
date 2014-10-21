#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
#
#

package POE::Component::Client::MPD::Connection;

use strict;
use warnings;

use POE;
use POE::Component::Client::MPD::Message;
use POE::Component::Client::TCP;
use Readonly;


Readonly my $IGNORE    => 0;
Readonly my $RECONNECT => 1;


#
# my $id = POE::Component::Client::MPD::Connection->spawn( \%params )
#
# This method will create a POE::Component::TCP session responsible for
# low-level communication with mpd. It will return the poe id of the
# session newly created.
#
# Arguments are passed as a hash reference, with the keys:
#   - host: hostname of the mpd server.
#   - port: port of the mpd server.
#   - id:   poe session id of the peer to dialog with
#
# Those args are not supposed to be empty - ie, there's no defaut, and you
# will get an error if you don't follow this requirement! :-)
#
sub spawn {
    my ($type, $args) = @_;

    # connect to mpd server.
    my $id = POE::Component::Client::TCP->new(
        RemoteAddress => $args->{host},
        RemotePort    => $args->{port},
        Filter        => 'POE::Filter::Line',
        Args          => [ $args->{id} ],

        ConnectError => sub { }, # quiet errors - FIXME: implement!
        ServerError  => sub { }, # quiet errors
        Started      => \&_onpriv_Started,
        Connected    => \&_onpriv_Connected,
        Disconnected => \&_onpriv_Disconnected,
        ServerInput  => \&_onpriv_ServerInput,

        InlineStates => {
            # protected events
            send       => \&_onprot_send,         # send data
            disconnect => \&_onprot_disconnect,   # force quit

            # private events
            _ServerInput_data         => \&_onpriv_ServerInput_data,
            _ServerInput_data_eot     => \&_onpriv_ServerInput_data_eot,
            _ServerInput_mpd_version  => \&_onpriv_ServerInput_mpd_version,
            _ServerInput_error        => \&_onpriv_ServerInput_error,
        }
    );

    return $id;
}


#--
# protected events

#
# event: disconnect()
#
# Request the pococm-connection to be shutdown. No argument.
#
sub _onprot_disconnect {
    $_[HEAP]->{on_disconnect} = $IGNORE; # no more auto-reconnect.
    $_[KERNEL]->yield( 'shutdown' );     # shutdown socket.
}


#
# event: send( $request )
#
# Request pococm-conn to send the $request over the wires. Note that this
# request is a pococm-request object, and that the ->_commands should
# *not* be newline terminated.
#
sub _onprot_send {
    # $_[HEAP]->{server} is a reserved slot of pococ-tcp.
    $_[HEAP]->{server}->put( @{ $_[ARG0]->_commands } );
    $_[HEAP]->{message} = $_[ARG0];
}


#--
# private events

#
# event: Started( $id )
#
# Called whenever the session is started, but before the tcp connection is
# established. Receives the session $id of the poe-session that will be our
# peer during the life of this session.
#
sub _onpriv_Started {
    $_[HEAP]{session}     = $_[ARG0];       # poe-session peer
    $_[HEAP]{on_disconnect} = $RECONNECT;   # disconnect policy
}


#
# event: Connected()
#
# Called whenever the tcp connection is established.
#
sub _onpriv_Connected {
    $_[HEAP]->{incoming} = [];   # reset incoming data
}


#
# event: Disconnected()
#
# Called whenever the tcp connection is broken / finished.
#
sub _onpriv_Disconnected {
    return if $_[HEAP]->{on_disconnect} != $RECONNECT;
    $_[KERNEL]->yield('reconnect'); # auto-reconnect
}


#
# event: ServerInput( $input )
#
# Called whenever the tcp peer sends data over the wires, with the $input
# transmitted given as param.
#
sub _onpriv_ServerInput {
    my $input = $_[ARG0];

    # table of dispatch: check input against regex, and fire event
    # if it did match.
    my @dispatch = (
        [ qr/^OK$/,          '_ServerInput_data_eot'    ],
        [ qr/^OK MPD (.*)$/, '_ServerInput_mpd_version' ],
        [ qr/^ACK/,          '_ServerInput_error'       ],
        [ qr/^/,             '_ServerInput_data'        ],
    );

    foreach my $d (@dispatch) {
        next unless $input =~ $d->[0];
        $_[KERNEL]->yield( $d->[1], $input, $1 );
        last;
    }
}


#
# event: _ServerInput_data( $input )
#
# Called when the stream of data is finished.
#
sub _onpriv_ServerInput_data {
    my ($h, $input) = @_[HEAP, ARG0];

    # regular data, to be cooked (if needed) and stored.
    my $cooking = $h->{message}->_cooking;
    COOKING:
    {
        last COOKING if $cooking == $RAW;

        $cooking == $STRIP_FIRST and do {
            # Lots of POCOCM methods are sending commands and then parse the
            # output to remove the first field (with the colon ":" acting as
            # separator).
            $input = ( split(/:\s+/, $input, 2) )[1];
            last COOKING;
        };
    }
    push @{ $h->{incoming} }, $input;
}


#
# event: _ServerInput_data_eot()
#
# Called when the stream of data is finished.
#
sub _onpriv_ServerInput_data_eot {
    my ($k, $h) = @_[KERNEL, HEAP];
    my $session = $h->{session};
    my $msg     = $h->{message};
    $msg->data( $h->{incoming} );           # complete message with data
    $k->post($session, '_got_data', $msg);  # signal poe session
    $h->{incoming} = [];                    # reset incoming data
}


#
# event: _ServerInput_mpd_version(undef, $version)
#
# Called just after the connection, with mpd's $version.
#
sub _onpriv_ServerInput_mpd_version {
    my $session = $_[HEAP]->{session};
    $_[KERNEL]->post($session, '_got_mpd_version', $_[ARG1]);
}


#
# event: _ServerInput_error(undef, $error)
#
# Called when a message resulted in an $error for mpd.
#
sub _onpriv_ServerInput_error {
    # FIXME: implement
}


1;

__END__

=head1 NAME

POE::Component::Client::MPD::Connection - module handling the tcp connection with mpd


=head1 DESCRIPTION

This module will spawn a poe session responsible for low-level communication
with mpd. It is written as a pococ-tcp, which is taking care of everything
needed.

Note that you're B<not> supposed to use this class directly: it's one of the
helper class for POCOCM.


=head1 PUBLIC PACKAGE METHODS

=head2 spawn( \%params )

This method will create a POE::Component::TCP session responsible for low-level
communication with mpd.

It will return the poe id of the session newly created.

You should provide some arguments as a hash reference, where the hash keys are:

=over 4

=item * host

The hostname of the mpd server.


=item * port

The port of the mpd server.


=item * id

The POE session id of the peer to dialog with.


=back


Those args are not supposed to be empty - ie, there's no defaut, and you
will get an error if you don't follow this requirement! :-)


=head1 PROTECTED EVENTS ACCEPTED

The following events are accepted from outside this class - but of course
restricted to POCOCM.


=head2 disconnect()

Request the pococm-connection to be shutdown. No argument.


=head2 send( $request )

Request pococm-conn to send the C<$request> over the wires. Note that this
request is a pococm-request object, and that the ->_commands should
B<not> be newline terminated.


=head1 SEE ALSO

You can find more information on the mpd project on its homepage at
L<http://www.musicpd.org>, or its wiki L<http://mpd.wikia.com>.

Regarding this Perl module, you can report bugs on CPAN via
L<http://rt.cpan.org/Public/Bug/Report.html?Queue=Audio-MPD>.

POE::Component::Client::MPD development takes place on
<audio-mpd@googlegroups.com>: feel free to join us.
(use L<http://groups.google.com/group/audio-mpd> to sign in). Our subversion
repository is located at L<https://svn.musicpd.org>.


=head1 AUTHOR

Jerome Quelin <jquelin@cpan.org>


=head1 COPYRIGHT AND LICENSE

Copyright (c) 2007 Jerome Quelin <jquelin@cpan.org>


This program is free software; you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation; either version 2 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

=cut
