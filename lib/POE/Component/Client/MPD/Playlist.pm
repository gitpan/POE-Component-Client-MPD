#
# This file is part of POE::Component::Client::MPD.
# Copyright (c) 2007-2008 Jerome Quelin, all rights reserved.
#
# This program is free software; you can redistribute it and/or modify
# it under the same terms as Perl itself.
#
#

package POE::Component::Client::MPD::Playlist;

use strict;
use warnings;

use POE;
use POE::Component::Client::MPD::Message;

use base qw{ Class::Accessor::Fast };


# -- Playlist: retrieving information

#
# event: pl.as_items()
#
# Return an array of C<Audio::MPD::Common::Item::Song>s, one for each of
# the songs in the current playlist.
#
sub _do_as_items {
    my ($self, $k, $h, $msg) = @_;

    $msg->_commands ( [ 'playlistinfo' ] );
    $msg->_cooking  ( $AS_ITEMS );
    $k->post( $h->{socket}, 'send', $msg );
}


#
# event: pl.items_changed_since( $plversion )
#
# Return a list with all the songs (as Audio::MPD::Common::Item::Song
# objects) added to the playlist since playlist $plversion.
#
sub _do_items_changed_since {
    my ($self, $k, $h, $msg) = @_;
    my $plid = $msg->params->[0];

    $msg->_commands ( [ "plchanges $plid" ] );
    $msg->_cooking  ( $AS_ITEMS );
    $k->post( $h->{socket}, 'send', $msg );
}


# -- Playlist: adding / removing songs

#
# event: pl.add( $path, $path, ... )
#
# Add the songs identified by $path (relative to MPD's music directory) to
# the current playlist.
#
sub _do_add {
    my ($self, $k, $h, $msg) = @_;

    my $args   = $msg->params;
    my @pathes = @$args;         # args of the poe event
    my @commands = (             # build the commands
        'command_list_begin',
        map( qq{add "$_"}, @pathes ),
        'command_list_end',
    );
    $msg->_commands ( \@commands );
    $msg->_cooking  ( $RAW );
    $k->post( $h->{socket}, 'send', $msg );
}


#
# event: pl.delete( $number, $number, ... )
#
# Remove song $number (starting from 0) from the current playlist.
#
sub _do_delete {
    my ($self, $k, $h, $msg) = @_;

    my $args    = $msg->params;
    my @numbers = @$args;
    my @commands = (              # build the commands
        'command_list_begin',
        map( qq{delete $_}, reverse sort {$a<=>$b} @numbers ),
        'command_list_end',
    );
    $msg->_commands ( \@commands );
    $msg->_cooking  ( $RAW );
    $k->post( $h->{socket}, 'send', $msg );
}


#
# event: pl.deleteid( $songid, $songid, ... )
#
# Remove the specified $songid (as assigned by mpd when inserted in playlist)
# from the current playlist.
#
sub _do_deleteid {
    my ($self, $k, $h, $msg) = @_;

    my $args    = $msg->params;
    my @songids = @$args;
    my @commands = (              # build the commands
        'command_list_begin',
        map( qq{deleteid $_}, @songids ),
        'command_list_end',
    );
    $msg->_commands ( \@commands );
    $msg->_cooking  ( $RAW );
    $k->post( $h->{socket}, 'send', $msg );
}


#
# event: clear()
#
# Remove all the songs from the current playlist.
#
sub _do_clear {
    my ($self, $k, $h, $msg) = @_;

    $msg->_commands ( [ 'clear' ] );
    $msg->_cooking  ( $RAW );
    $k->post( $h->{socket}, 'send', $msg );
}


#
# event: crop()
#
#  Remove all of the songs from the current playlist *except* the current one.
#
sub _do_crop {
    my ($self, $k, $h, $msg) = @_;

    if ( not defined $msg->_data ) {
        # no status yet - fire an event
        $msg->_post( 'pl.crop' );
        $h->{mpd}->_dispatch($k, $h, 'status', $msg);
        return;
    }

    # now we know what to remove
    my $cur = $msg->_data->song;
    my $len = $msg->_data->playlistlength - 1;
    my @commands = (
        'command_list_begin',
        map( { $_ != $cur ? "delete $_" : '' } reverse 0..$len ),
        'command_list_end'
    );

    $msg->_cooking  ( $RAW );
    $msg->_commands ( \@commands );
    $k->post( $h->{socket}, 'send', $msg );
}


# -- Playlist: changing playlist order

#
# event: pl.shuffle()
#
# Shuffle the current playlist.
#
sub _do_shuffle {
    my ($self, $k, $h, $msg) = @_;

    $msg->_cooking  ( $RAW );
    $msg->_commands ( [ 'shuffle' ] );
    $k->post( $h->{socket}, 'send', $msg );
}


#
# event: pl.swap( $song1, $song2 )
#
# Swap positions of song number $song1 and $song2 in the current playlist.
#
sub _do_swap {
    my ($self, $k, $h, $msg) = @_;
    my ($from, $to) = @{ $msg->params }[0,1];

    $msg->_cooking  ( $RAW );
    $msg->_commands ( [ "swap $from $to" ] );
    $k->post( $h->{socket}, 'send', $msg );
}


#
# event: pl.swapid( $songid1, $songid2 )
#
# Swap positions of song id $songid1 and $songid2 in the current playlist.
#
sub _do_swapid {
    my ($self, $k, $h, $msg) = @_;
    my ($from, $to) = @{ $msg->params }[0,1];

    $msg->_cooking  ( $RAW );
    $msg->_commands ( [ "swapid $from $to" ] );
    $k->post( $h->{socket}, 'send', $msg );
}


#
# event: pl.move( $song, $newpos )
#
# Move song number $song to the position $newpos.
#
sub _do_move {
    my ($self, $k, $h, $msg) = @_;
    my ($song, $pos) = @{ $msg->params }[0,1];

    $msg->_cooking  ( $RAW );
    $msg->_commands ( [ "move $song $pos" ] );
    $k->post( $h->{socket}, 'send', $msg );
}


#
# event: pl.moveid( $songid, $newpos )
#
# Move song id $songid to the position $newpos.
#
sub _do_moveid {
    my ($self, $k, $h, $msg) = @_;
    my ($songid, $pos) = @{ $msg->params }[0,1];

    $msg->_cooking  ( $RAW );
    $msg->_commands ( [ "moveid $songid $pos" ] );
    $k->post( $h->{socket}, 'send', $msg );
}


# -- Playlist: managing playlists

#
# event: pl.load( $playlist )
#
# Load list of songs from specified $playlist file.
#
sub _do_load {
    my ($self, $k, $h, $msg) = @_;
    my $playlist = $msg->params->[0];

    $msg->_cooking  ( $RAW );
    $msg->_commands ( [ qq{load "$playlist"} ] );
    $k->post( $h->{socket}, 'send', $msg );
}


#
# event: pl.save( $playlist )
#
# Save the current playlist to a file called $playlist in MPD's
# playlist directory.
#
sub _do_save {
    my ($self, $k, $h, $msg) = @_;
    my $playlist = $msg->params->[0];

    $msg->_cooking  ( $RAW );
    $msg->_commands ( [ qq{save "$playlist"} ] );
    $k->post( $h->{socket}, 'send', $msg );
}


#
# event: pl.rm( $playlist )
#
# Delete playlist named $playlist from MPD's playlist directory.
#
sub _do_rm {
    my ($self, $k, $h, $msg) = @_;
    my $playlist = $msg->params->[0];

    $msg->_cooking  ( $RAW );
    $msg->_commands ( [ qq{rm "$playlist"} ] );
    $k->post( $h->{socket}, 'send', $msg );
}



1;

__END__

=head1 NAME

POE::Component::Client::MPD::Playlist - module handling playlist commands



=head1 DESCRIPTION

C<POCOCM::Playlist> is responsible for handling general purpose
commands. They are in a dedicated module to achieve easier code
maintenance.

To achieve those commands, send the corresponding event to the POCOCM
session you created: it will be responsible for dispatching the event
where it is needed. Under no circumstance should you call directly subs
or methods from this module directly.

Read POCOCM's pod to learn how to deal with answers from those commands.



=head1 PUBLIC EVENTS

The following is a list of playlist-related events accepted by POCOCM.


=head2 Retrieving information


=over 4

=item * pl.as_items()

Return an array of C<Audio::MPD::Common::Item::Song>s, one for each of
the songs in the current playlist.


=item * pl.items_changed_since( $plversion )

Return a list with all the songs (as C<Audio::MPD::Common::Item::Song>
objects) added to the playlist since playlist C<$plversion>.


=back



=head2 Adding / removing songs


=over 4

=item * pl.add( $path, $path, ... )

Add the songs identified by C<$path> (relative to MPD's music directory)
to the current playlist.


=item * pl.delete( $number, $number, ... )

Remove song C<$number> (starting from 0) from the current playlist.


=item * pl.deleteid( $songid, $songid, ... )

Remove the specified C<$songid> (as assigned by mpd when inserted in
playlist) from the current playlist.


=item * clear()

Remove all the songs from the current playlist.


=item * crop()

Remove all of the songs from the current playlist *except* the current one.


=back



=head2 Changing playlist order


=over 4

=item * pl.shuffle()

Shuffle the current playlist.


=item * pl.swap( $song1, $song2 )

Swap positions of song number C<$song1> and C<$song2> in the current
playlist.


=item * pl.swapid( $songid1, $songid2 )

Swap positions of song id C<$songid1> and C<$songid2> in the current
playlist.


=item * pl.move( $song, $newpos )

Move song number C<$song> to the position C<$newpos>.


=item * pl.moveid( $songid, $newpos )

Move song id C<$songid> to the position C<$newpos>.


=back



=head2 Managing playlists


=over 4

=item * pl.load( $playlist )

Load list of songs from specified C<$playlist> file.


=item * pl.save( $playlist )

Save the current playlist to a file called C<$playlist> in MPD's
playlist directory.


=item * pl.rm( $playlist )

Delete playlist named C<$playlist> from MPD's playlist directory.


=back



=head1 SEE ALSO

For all related information (bug reporting, mailing-list, pointers to
MPD and POE, etc.), refer to C<POE::Component::Client::MPD>'s pod,
section C<SEE ALSO>



=head1 AUTHOR

Jerome Quelin, C<< <jquelin@cpan.org> >>



=head1 COPYRIGHT & LICENSE

Copyright (c) 2007-2008 Jerome Quelin, all rights reserved.

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
