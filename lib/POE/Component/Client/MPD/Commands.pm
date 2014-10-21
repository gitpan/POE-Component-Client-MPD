#
# This file is part of POE::Component::Client::MPD.
# Copyright (c) 2007-2008 Jerome Quelin, all rights reserved.
#
# This program is free software; you can redistribute it and/or modify
# it under the same terms as Perl itself.
#
#

package POE::Component::Client::MPD::Commands;

use strict;
use warnings;

use POE;
use POE::Component::Client::MPD::Message;

use base qw{ Class::Accessor::Fast };


# -- MPD interaction: general commands

#
# event: version()
#
# Return mpd's version number as advertised during connection.
# Note that mpd returns *protocol* version when connected. This
# protocol version can differ from the real mpd version. eg, mpd
# version 0.13.2 is "speaking" and thus advertising version 0.13.0.
#
sub _do_version {
    my ($self, $k, $h, $msg) = @_;
    $msg->status(1);
    $k->post( $msg->_from, 'mpd_result', $msg, $h->{version} );
}


#
# event: kill()
#
# Kill the mpd server, and request the pococm to be shutdown.
#
sub _do_kill {
    my ($self, $k, $h, $msg) = @_;

    $msg->_commands ( [ 'kill' ] );
    $msg->_cooking  ( $RAW );
    $k->post( $h->{socket}, 'send', $msg );
    $k->delay_set('disconnect'=>1);
}


#
# event: updatedb( [$path] )
#
# Force mpd to rescan its collection. If $path (relative to MPD's music
# directory) is supplied, MPD will only scan it - otherwise, MPD will rescan
# its whole collection.
#
sub _do_updatedb {
    my ($self, $k, $h, $msg) = @_;
    my $path = $msg->params->[0] // '';

    $msg->_commands( [ qq{update "$path"} ] );
    $msg->_cooking ( $RAW );
    $k->post( $h->{socket}, 'send', $msg );
}


#
# event: urlhandlers()
#
# Return an array of supported URL schemes.
#
sub _do_urlhandlers {
    my ($self, $k, $h, $msg) = @_;

    $msg->_commands ( [ 'urlhandlers' ] );
    $msg->_cooking  ( $STRIP_FIRST );
    $k->post( $h->{socket}, 'send', $msg );
}


# -- MPD interaction: handling volume & output

#
# event: volume( $volume )
#
# Sets the audio output volume percentage to absolute $volume.
# If $volume is prefixed by '+' or '-' then the volume is changed relatively
# by that value.
#
sub _do_volume {
    my ($self, $k, $h, $msg) = @_;

    my $volume;
    if ( $msg->params->[0] =~ /^(-|\+)(\d+)/ ) {
        my ($op, $delta) = ($1, $2);
        if ( not defined $msg->_data ) {
            # no status yet - fire an event
            $msg->_post( 'volume' );
            $h->{mpd}->_dispatch($k, $h, 'status', $msg);
            return;
        }

        # already got a status result
        my $curvol = $msg->_data->volume;
        $volume = $op eq '+' ? $curvol + $delta : $curvol - $delta;
    } else {
        $volume = $msg->params->[0];
    }

    $msg->_commands ( [ "setvol $volume" ] );
    $msg->_cooking  ( $RAW );
    $k->post( $h->{socket}, 'send', $msg );
}


#
# event: output_enable( $output )
#
# Enable the specified audio output. $output is the ID of the audio output.
#
sub _do_output_enable {
    my ($self, $k, $h, $msg) = @_;
    my $output = $msg->params->[0];

    $msg->_commands ( [ "enableoutput $output" ] );
    $msg->_cooking  ( $RAW );
    $k->post( $h->{socket}, 'send', $msg );
}


#
# event: output_disable( $output )
#
# Disable the specified audio output. $output is the ID of the audio output.
#
sub _do_output_disable {
    my ($self, $k, $h, $msg) = @_;
    my $output = $msg->params->[0];

    $msg->_commands ( [ "disableoutput $output" ] );
    $msg->_cooking  ( $RAW );
    $k->post( $h->{socket}, 'send', $msg );
}



# -- MPD interaction: retrieving info from current state

#
# event: stats()
#
# Return an Audio::MPD::Common::Stats object with the current statistics
# of MPD.
#
sub _do_stats {
    my ($self, $k, $h, $msg) = @_;

    $msg->_commands ( [ 'stats' ] );
    $msg->_cooking  ( $AS_KV );
    $msg->_transform( $AS_STATS );
    $k->post( $h->{socket}, 'send', $msg );
}


#
# event: status()
#
# Return an Audio::MPD::Common::Status object the current status of MPD.
#
sub _do_status {
    my ($self, $k, $h, $msg) = @_;

    $msg->_commands ( [ 'status' ] );
    $msg->_cooking  ( $AS_KV );
    $msg->_transform( $AS_STATUS );
    $k->post( $h->{socket}, 'send', $msg );
}



#
# event: current()
#
# Return an Audio::MPD::Common::Item::Song representing the song
# currently playing.
#
sub _do_current {
    my ($self, $k, $h, $msg) = @_;

    $msg->_commands ( [ 'currentsong' ] );
    $msg->_cooking  ( $AS_ITEMS );
    $msg->_transform( $AS_SCALAR );
    $k->post( $h->{socket}, 'send', $msg );
}


#
# event: song( [$song] )
#
# Return an Audio::MPD::Common::Item::Song representing the song number
# $song. If $song is not supplied, returns the current song.
#
sub _do_song {
    my ($self, $k, $h, $msg) = @_;
    my $song = $msg->params->[0];

    $msg->_commands ( [ defined $song ? "playlistinfo $song" : 'currentsong' ] );
    $msg->_cooking  ( $AS_ITEMS );
    $msg->_transform( $AS_SCALAR );
    $k->post( $h->{socket}, 'send', $msg );
}


#
# event: songid( [$songid] )
#
# Return an Audio::MPD::Common::Item::Song representing the song id
# $songid. If $songid is not supplied, returns the current song.
#
sub _do_songid {
    my ($self, $k, $h, $msg) = @_;
    my $song = $msg->params->[0];

    $msg->_commands ( [ defined $song ? "playlistid $song" : 'currentsong' ] );
    $msg->_cooking  ( $AS_ITEMS );
    $msg->_transform( $AS_SCALAR );
    $k->post( $h->{socket}, 'send', $msg );
}


# -- MPD interaction: altering settings

#
# event: repeat( [$repeat] )
#
# Set the repeat mode to $repeat (1 or 0). If $repeat is not specified then
# the repeat mode is toggled.
#
sub _do_repeat {
    my ($self, $k, $h, $msg) = @_;

    my $mode = $msg->params->[0];
    if ( defined $mode )  {
        $mode = $mode ? 1 : 0;   # force integer
    } else {
        if ( not defined $msg->_data ) {
            # no status yet - fire an event
            $msg->_post( 'repeat' );
            $h->{mpd}->_dispatch($k, $h, 'status', $msg);
            return;
        }

        $mode = $msg->_data->repeat ? 0 : 1; # negate current value
    }

    $msg->_cooking ( $RAW );
    $msg->_commands( [ "repeat $mode" ] );
    $k->post( $h->{socket}, 'send', $msg );
}


#
# event: fade( [$seconds] )
#
# Enable crossfading and set the duration of crossfade between songs. If
# $seconds is not specified or $seconds is 0, then crossfading is disabled.
#
sub _do_fade {
    my ($self, $k, $h, $msg) = @_;
    my $seconds = $msg->params->[0] // 0;

    $msg->_commands ( [ "crossfade $seconds" ] );
    $msg->_cooking  ( $RAW );
    $k->post( $h->{socket}, 'send', $msg );
}


#
# event: random( [$random] )
#
# Set the random mode to $random (1 or 0). If $random is not specified then
# the random mode is toggled.
#
sub _do_random {
    my ($self, $k, $h, $msg) = @_;

    my $mode = $msg->params->[0];
    if ( defined $mode )  {
        $mode = $mode ? 1 : 0;   # force integer
    } else {
        if ( not defined $msg->_data ) {
            # no status yet - fire an event
            $msg->_post( 'random' );
            $h->{mpd}->_dispatch($k, $h, 'status', $msg);
            return;
        }

        $mode = $msg->_data->random ? 0 : 1; # negate current value
    }

    $msg->_cooking ( $RAW );
    $msg->_commands( [ "random $mode" ] );
    $k->post( $h->{socket}, 'send', $msg );
}



# -- MPD interaction: controlling playback

#
# event: play( [$song] )
#
# Begin playing playlist at song number $song. If no argument supplied,
# resume playing.
#
sub _do_play {
    my ($self, $k, $h, $msg) = @_;

    my $number = $msg->params->[0] // '';
    $msg->_commands ( [ "play $number" ] );
    $msg->_cooking  ( $RAW );
    $k->post( $h->{socket}, 'send', $msg );
}


#
# event: playid( [$song] )
#
# Begin playing playlist at song ID $song. If no argument supplied,
# resume playing.
#
sub _do_playid {
    my ($self, $k, $h, $msg) = @_;

    my $number = $msg->params->[0] // '';
    $msg->_commands ( [ "playid $number" ] );
    $msg->_cooking  ( $RAW );
    $k->post( $h->{socket}, 'send', $msg );
}


#
# event: pause( [$sate] )
#
# Pause playback. If $state is 0 then the current track is unpaused, if
# $state is 1 then the current track is paused.
#
# Note that if $state is not given, pause state will be toggled.
#
sub _do_pause {
    my ($self, $k, $h, $msg) = @_;

    my $state = $msg->params->[0] // '';
    $msg->_commands ( [ "pause $state" ] );
    $msg->_cooking  ( $RAW );
    $k->post( $h->{socket}, 'send', $msg );
}


#
# event: stop()
#
# Stop playback.
#
sub _do_stop {
    my ($self, $k, $h, $msg) = @_;

    $msg->_commands ( [ 'stop' ] );
    $msg->_cooking  ( $RAW );
    $k->post( $h->{socket}, 'send', $msg );
}


#
# event: next()
#
# Play next song in playlist.
#
sub _do_next {
    my ($self, $k, $h, $msg) = @_;

    $msg->_commands ( [ 'next' ] );
    $msg->_cooking  ( $RAW );
    $k->post( $h->{socket}, 'send', $msg );
}


#
# event: prev()
#
# Play previous song in playlist.
#
sub _do_prev {
    my ($self, $k, $h, $msg) = @_;

    $msg->_commands ( [ 'previous' ] );
    $msg->_cooking  ( $RAW );
    $k->post( $h->{socket}, 'send', $msg );
}


#
# event: seek( $time, [$song] )
#
# Seek to $time seconds in song number $song. If $song number is not specified
# then the perl module will try and seek to $time in the current song.
#
sub _do_seek {
    my ($self, $k, $h, $msg) = @_;

    my ($time, $song) = @{ $msg->params }[0,1];
    $time ||= 0; $time = int $time;
    if ( not defined $song )  {
        if ( not defined $msg->_data ) {
            # no status yet - fire an event
            $msg->_post( 'seek' );
            $h->{mpd}->_dispatch($k, $h, 'status', $msg);
            return;
        }

        $song = $msg->_data->song;
    }

    $msg->_cooking ( $RAW );
    $msg->_commands( [ "seek $song $time" ] );
    $k->post( $h->{socket}, 'send', $msg );
}


#
# event: seekid( $time, [$songid] )
#
# Seek to $time seconds in song ID $songid. If $songid number is not specified
# then the perl module will try and seek to $time in the current song.
#
sub _do_seekid {
    my ($self, $k, $h, $msg) = @_;

    my ($time, $songid) = @{ $msg->params }[0,1];
    $time ||= 0; $time = int $time;
    if ( not defined $songid )  {
        if ( not defined $msg->_data ) {
            # no status yet - fire an event
            $msg->_post( 'seekid' );
            $h->{mpd}->_dispatch($k, $h, 'status', $msg);
            return;
        }

        $songid = $msg->_data->songid;
    }

    $msg->_cooking ( $RAW );
    $msg->_commands( [ "seekid $songid $time" ] );
    $k->post( $h->{socket}, 'send', $msg );
}


1;

__END__

=head1 NAME

POE::Component::Client::MPD::Commands - module handling basic mpd commands



=head1 DESCRIPTION

L<POE::Component::Client::MPD::Commands> is responsible for handling
general purpose commands. They are in a dedicated module to achieve
easier code maintenance.

To achieve those commands, send the corresponding event to the POCOCM
session you created: it will be responsible for dispatching the event
where it is needed. Under no circumstance should you call directly subs
or methods from this module directly.

Read POCOCM's pod to learn how to deal with answers from those commands.



=head1 PUBLIC EVENTS

The following is a list of general purpose events accepted by POCOCM.


=head2 General commands


=over 4

=item * version()

Return mpd's version number as advertised during connection. Note that
mpd returns B<protocol> version when connected. This protocol version can
differ from the real mpd version. eg, mpd version 0.13.2 is "speaking"
and thus advertising version 0.13.0.


=item * kill()

Kill the mpd server, and request the pococm to be shutdown.


=item * updatedb( [$path] )

Force mpd to rescan its collection. If C<$path> (relative to MPD's music
directory) is supplied, MPD will only scan it - otherwise, MPD will
rescan its whole collection.


=item * urlhandlers()

Return an array of supported URL schemes.


=back



=head2 Handling volume & output


=over 4

=item * volume( $volume )

Sets the audio output volume percentage to absolute C<$volume>. If
C<$volume> is prefixed by '+' or '-' then the volume is changed
relatively by that value.


=item * output_enable( $output )

Enable the specified audio output. C<$output> is the ID of the audio
output.


=item * output_disable( $output )

Disable the specified audio output. C<$output> is the ID of the audio output.


=back



=head2 Retrieving info from current state


=over 4

=item * stats()

Return an L<Audio::MPD::Common::Stats> object with the current
statistics of MPD.


=item * status ()

Return an L<Audio::MPD::Common::Status> object with the current
status of MPD.


=item * current()

Return an L<Audio::MPD::Common::Item::Song> representing the song
currently playing.


=item * song( [$song] )

Return an L<Audio::MPD::Common::Item::Song> representing the song number
C<$song>. If C<$song> is not supplied, returns the current song.


=item * songid( [$songid] )

Return an L<Audio::MPD::Common::Item::Song> representing the song id
C<$songid>. If C<$songid> is not supplied, returns the current song.


=back



=head2 Altering settings


=over 4

=item * repeat( [$repeat] )

Set the repeat mode to C<$repeat> (1 or 0). If C<$repeat> is not
specified then the repeat mode is toggled.


=item * fade( [$seconds] )

Enable crossfading and set the duration of crossfade between songs. If
C<$seconds> is not specified or C<$seconds> is 0, then crossfading is
disabled.


=item * random( [$random] )

Set the random mode to C<$random> (1 or 0). If C<$random> is not
specified then the random mode is toggled.


=back



=head2 Controlling playback


=over 4

=item * play( [$song] )

Begin playing playlist at song number C<$song>. If no argument supplied,
resume playing.


=item * playid( [$song] )

Begin playing playlist at song ID C<$song>. If no argument supplied,
resume playing.


=item * pause( [$sate] )

Pause playback. If C<$state> is 0 then the current track is unpaused, if
C<$state> is 1 then the current track is paused.

Note that if C<$state> is not given, pause state will be toggled.


=item * stop()

Stop playback.


=item * next()

Play next song in playlist.


=item * prev()

Play previous song in playlist.


=item * seek( $time, [$song] )

Seek to C<$time> seconds in song number C<$song>. If C<$song> number is
not specified then the perl module will try and seek to C<$time> in the
current song.


=item * seekid( $time, [$songid] )

Seek to C<$time> seconds in song ID C<$songid>. If C<$songid> number is
not specified then the perl module will try and seek to C<$time> in the
current song.


=back



=head1 SEE ALSO

For all related information (bug reporting, mailing-list, pointers to
MPD and POE, etc.), refer to L<POE::Component::Client::MPD>'s pod,
section C<SEE ALSO>



=head1 AUTHOR

Jerome Quelin, C<< <jquelin@cpan.org> >>



=head1 COPYRIGHT & LICENSE

Copyright (c) 2007-2008 Jerome Quelin, all rights reserved.

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
