#
# This file is part of POE::Component::Client::MPD.
# Copyright (c) 2007 Jerome Quelin, all rights reserved.
#
# This program is free software; you can redistribute it and/or modify
# it under the same terms as Perl itself.
#
#

package POE::Component::Client::MPD;

use strict;
use warnings;

use Audio::MPD::Common::Stats;
use Audio::MPD::Common::Status;
use Carp;
use List::MoreUtils qw[ firstidx ];
use POE;
use POE::Component::Client::MPD::Connection;
use POE::Component::Client::MPD::Message;
use Readonly;

use base qw[ Class::Accessor::Fast Exporter ];
__PACKAGE__->mk_accessors( qw[ _host _password _port  _version ] );
our @EXPORT_OK   = qw[ $MPD $COLLECTION $PLAYLIST $_HUB ];
our %EXPORT_TAGS = ( all => \@EXPORT_OK );


# exportable variables
Readonly our $MPD        => '_pococ_mpd_commands';
Readonly our $COLLECTION => '_pococ_mpd_collection';
Readonly our $PLAYLIST   => '_pococ_mpd_playlist';
Readonly our $_HUB       => '_pococ_mpd_hub';


our $VERSION = '0.8.1';


#
# my $id = spawn( \%params )
#
# This method will create a POE session responsible for communicating
# with mpd. It will return the poe id of the session newly created.
#
# You can tune the pococm by passing some arguments as a hash reference,
# where the hash keys are:
#   - host: the hostname of the mpd server. If none given, defaults to
#     MPD_HOST env var. If this var isn't set, defaults to localhost.
#   - port: the port of the mpd server. If none given, defaults to
#     MPD_PORT env var. If this var isn't set, defaults to 6600.
#   - password: the password to sent to mpd to authenticate the client.
#     If none given, defaults to C<MPD_PASSWORD> env var. If this var
#     isn't set, defaults to empty string.
#   - alias: an optional string to alias the newly created POE session.
#
sub spawn {
    my ($type, $args) = @_;

    require POE::Component::Client::MPD::Collection;
    require POE::Component::Client::MPD::Commands;
    require POE::Component::Client::MPD::Playlist;

    my $session = POE::Session->create(
        args          => [ $args ],
        inline_states => {
            # private events
            '_start'                   => \&_onpriv_start,
            '_send'                    => \&_onpriv_send,
            # protected events
            '_mpd_data'                => \&_onprot_mpd_data,
            '_mpd_error'               => \&_onprot_mpd_error,
            '_mpd_version'             => \&_onprot_mpd_version,
            '_disconnect'              => \&_onprot_disconnect,
            '_version'                 => \&_onprot_version,
        },
    );

    POE::Component::Client::MPD::Collection->_spawn;
    POE::Component::Client::MPD::Commands->_spawn;
    POE::Component::Client::MPD::Playlist->_spawn;

    return $session->ID;
}


sub _onpub_default {
    my ($event, $params) = @_[ARG0, ARG1];

    my $from = $_[SENDER]->ID;
    my $to   = $_[SESSION]->ID;
#     warn "caught $event ($from -> $to)\n";
    die "should not be there! caught $event ($from -> $to)"
        if $_[SENDER] == $_[SESSION];
#     return unless exists $allowed{$event};

    my $msg = POE::Component::Client::MPD::Message->new( {
        _from       => $_[SENDER]->ID,
        _request    => $event,  # /!\ $_[STATE] eq 'default'
        _params     => $params,
        _dispatch   => $event,
        #_answer    => <to be set by handler>
        #_commands  => <to be set by handler>
        #_cooking   => <to be set by handler>
        #_transform => <to be set by handler>
        #_post      => <to be set by handler>
    } );
    $_[KERNEL]->yield( '_dispatch', $msg );
}


#--
# protected events.

#
# event: _disconnect()
#
# Request the pococm to be shutdown. Leave mpd running.
#
sub _onprot_disconnect {
    my ($k,$h) = @_[KERNEL, HEAP];
    $k->alias_remove( $h->{alias} ) if defined $h->{alias}; # refcount--
    $k->alias_remove( $_HUB );
    $k->post( $h->{_socket}, 'disconnect' );    # pococm-conn
    $k->post( $PLAYLIST,     '_disconnect' );    # pococm-playlist
    $k->post( $COLLECTION,   '_disconnect' );    # pococm-coll
}


#
# event: _version()
#
# Fill in the mpd version, and fakes that we received some data to send
# version back to requester.
#
sub _onprot_version {
    my ($k,$h,$msg) = @_[KERNEL, HEAP, ARG0];
    $msg->data( $_[HEAP]->{version} );
    $k->yield( '_mpd_data', $msg );
}


#
# Event: _mpd_data( $msg )
#
# Received when mpd finished to send back some data.
#
sub _onprot_mpd_data {
    my ($k, $h, $msg) = @_[KERNEL, HEAP, ARG0];

    TRANSFORM:
    {
        # transform data if needed.
        my $transform = $msg->_transform;
        last TRANSFORM unless defined $msg->_transform;

        $transform == $AS_SCALAR and do {
            my $data = $msg->data->[0];
            $msg->data($data);
            last TRANSFORM;
        };
        $transform == $AS_STATS and do {
            my %stats = @{ $msg->data };
            my $stats = Audio::MPD::Common::Stats->new( \%stats );
            $msg->data($stats);
            last TRANSFORM;
        };
        $transform == $AS_STATUS and do {
            my %status = @{ $msg->data };
            my $status = Audio::MPD::Common::Status->new( \%status );
            $msg->data($status);
            last TRANSFORM;
        };
    }


    # check for post-callback.
    # need to be before pre-callback, since a pre-event may need to have
    # a post-callback.
    if ( defined $msg->_post_event ) {
        $msg->_dispatch( $msg->_post_event );
        $msg->_post_event( undef );           # remove postback.
        $k->post( $msg->_post_to, '_dispatch', $msg ); # need a post-treatment...
        return;
    }

    # check for pre-callback.
    my $preidx = firstidx { $msg->_request eq $_->_pre_event } @{ $h->{pre_messages} };
    if ( $preidx != -1 ) {
        my $pre = splice @{ $h->{pre_messages} }, $preidx, 1;
        $k->yield( $pre->_pre_from, $pre, $msg );  # call post pre-event
        $pre->_pre_from ( undef );                 # remove pre-callback
        $pre->_pre_event( undef );                 # remove pre-event
        return;
    }

    return if $msg->_answer == $DISCARD;

    # send result.
    $k->post( $msg->_from, 'mpd_result', $msg );
}

sub _onprot_mpd_error {
    # send error.
    my $msg = $_[ARG0];
    $_[KERNEL]->post( $msg->_from, 'mpd_error', $msg );
}


#
# Event: _mpd_version( $vers )
#
# Event received during connection, when mpd server sends its version.
# Store it for later usage if needed.
#
sub _onprot_mpd_version {
    $_[HEAP]->{version} = $_[ARG0];
}


#--
# private events

#
# Event: _start( \%params )
#
# Called when the poe session gets initialized. Receive a reference
# to %params, same as spawn() received.
#
sub _onpriv_start {
    my ($h, $args) = @_[HEAP, ARG0];

    # set up connection details.
    $args = {} unless defined $args;
    my %params = (
        host     => $ENV{MPD_HOST}     || 'localhost',
        port     => $ENV{MPD_PORT}     || '6600',
        password => $ENV{MPD_PASSWORD} || '',
        %$args,                        # overwrite previous defaults
        id       => $_[SESSION]->ID,   # required for connection
    );

    # set an alias (for easier communication) if requested.
    $h->{alias} = delete $params{alias};
    $_[KERNEL]->alias_set($h->{alias}) if defined $h->{alias};
    $_[KERNEL]->alias_set( $_HUB );

    $h->{password} = delete $params{password};
    $h->{_socket}  = POE::Component::Client::MPD::Connection->spawn(\%params);
    $h->{pre_messages} = [];
}


=begin FIXME

#
# _connected()
#
# received when the poe::component::client::tcp is (re-)connected to the
# mpd server.
#
sub _connected {
    my ($self, $k) = @_[OBJECT, KERNEL];
    $k->post($_[HEAP]{_socket}, 'send', 'status' );
    # send password information
}

=end FIXME

=cut



#
# event: _send( $msg )
#
# Event received to request message sending over tcp to mpd server.
# $msg is a pococm-message partially filled.
#
sub _onpriv_send {
    my ($k, $h, $msg) = @_[KERNEL, HEAP, ARG0];
    if ( defined $msg->_pre_event ) {
        $k->yield( $msg->_pre_event );        # fire wanted pre-event
        push @{ $h->{pre_messages} }, $msg;   # store message
        return;
    }
    $k->post( $_[HEAP]->{_socket}, 'send', $msg );
}



1;

__END__


=head1 NAME

POE::Component::Client::MPD - a full-blown mpd client library


=head1 SYNOPSIS

    use POE qw[ Component::Client::MPD ];
    POE::Component::Client::MPD->spawn( {
        host     => 'localhost',
        port     => 6600,
        password => 's3kr3t',  # mpd password
        alias    => 'mpd',     # poe alias
    } );

    # ... later on ...
    $_[KERNEL]->post( 'mpd', 'next' );


=head1 DESCRIPTION

POCOCM gives a clear message-passing interface (sitting on top of POE)
for talking to and controlling MPD (Music Player Daemon) servers. A
connection to the MPD server is established as soon as a new POCOCM
object is created.

Commands are then sent to the server as messages are passed.


=head1 PUBLIC PACKAGE METHODS

=head2 spawn( \%params )

This method will create a POE session responsible for communicating with mpd.
It will return the poe id of the session newly created.

You can tune the pococm by passing some arguments as a hash reference, where
the hash keys are:

=over 4

=item * host

The hostname of the mpd server. If none given, defaults to C<MPD_HOST>
environment variable. If this var isn't set, defaults to C<localhost>.


=item * port

The port of the mpd server. If none given, defaults to C<MPD_PORT>
environment variable. If this var isn't set, defaults to C<6600>.


=item * password

The password to sent to mpd to authenticate the client. If none given, defaults
to C<MPD_PASSWORD> environment variable. If this var isn't set, defaults to C<>.


=item * alias

An optional string to alias the newly created POE session.


=back


=head1 PUBLIC EVENTS

For a list of public events that you can send to a POCOCM session, check:

=over 4

=item *

C<POCOCM::Commands> for general commands

=item *

C<POCOCM::Playlist> for playlist-related commands

=item *

C<POCOCM::Collection> for collection-related commands

=back


=head1 BUGS

Please report any bugs or feature requests to C<bug-poe-component-client-mpd at
rt.cpan.org>, or through the web interface at
L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=POE-Component-Client-MPD>.
I will be notified, and then you'll automatically be notified of progress on
your bug as I make changes.


=head1 SEE ALSO

You can find more information on the mpd project on its homepage at
L<http://www.musicpd.org>, or its wiki L<http://mpd.wikia.com>.

C<POE::Component::Client::MPD development> takes place on C<< <audio-mpd
at googlegroups.com> >>: feel free to join us. (use
L<http://groups.google.com/group/audio-mpd> to sign in). Our subversion
repository is located at L<https://svn.musicpd.org>.


You can also look for information on this module at:

=over 4

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/POE-Component-Client-MPD>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/POE-Component-Client-MPD>

=item * RT: CPAN's request tracker

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=POE-Component-Client-MPD>

=back


=head1 AUTHOR

Jerome Quelin, C<< <jquelin at cpan.org> >>


=head1 COPYRIGHT & LICENSE

Copyright (c) 2007 Jerome Quelin, all rights reserved.

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
