#
# This file is part of POE::Component::Client::MPD.
# Copyright (c) 2007 Jerome Quelin, all rights reserved.
#
# This program is free software; you can redistribute it and/or modify
# it under the same terms as Perl itself.
#
#

package POE::Component::Client::MPD::Collection;

use strict;
use warnings;

use POE  qw[ Component::Client::MPD::Message ];
use base qw[ Class::Accessor::Fast ];


# -- Collection: retrieving songs & directories

#
# event: coll.all_items( [$path] )
#
# Return *all* POCOCM::Items (both songs & directories) currently known
# by mpd.
# If $path is supplied (relative to mpd root), restrict the retrieval to
# songs and dirs in this directory.
#
sub _onpub_all_items {
    my $path = $_[ARG0];
    $path ||= '';
    my $msg = POE::Component::Client::MPD::Message->new( {
        _from     => $_[SENDER]->ID,
        _request  => $_[STATE],
        _answer   => $SEND,
        _commands => [ qq[listallinfo "$path"] ],
        _cooking  => $AS_ITEMS,
    } );
    $_[KERNEL]->yield( '_send', $msg );
}


#
# event: coll.all_items_simple( [$path] )
#
# Return *all* POCOCM::Items (both songs & directories) currently known
# by mpd.
#
# If $path is supplied (relative to mpd root), restrict the retrieval to
# songs and dirs in this directory.
#
# /!\ Warning: the POCOCM::Item::Song objects will only have their tag
# file filled. Any other tag will be empty, so don't use this sub for any
# other thing than a quick scan!
#
sub _onpub_all_items_simple {
    my $path = $_[ARG0];
    $path ||= '';
    my $msg = POE::Component::Client::MPD::Message->new( {
        _from     => $_[SENDER]->ID,
        _request  => $_[STATE],
        _answer   => $SEND,
        _commands => [ qq[listall "$path"] ],
        _cooking  => $AS_ITEMS,
    } );
    $_[KERNEL]->yield( '_send', $msg );
}


#
# event: coll.items_in_dir( [$path] )
#
# Return the items in the given $path. If no $path supplied, do it on mpd's
# root directory.
# Note that this sub does not work recusrively on all directories.
#
sub _onpub_items_in_dir {
    my $path = $_[ARG0];
    $path ||= '';
    my $msg = POE::Component::Client::MPD::Message->new( {
        _from     => $_[SENDER]->ID,
        _request  => $_[STATE],
        _answer   => $SEND,
        _commands => [ qq[lsinfo "$path"] ],
        _cooking  => $AS_ITEMS,
    } );
    $_[KERNEL]->yield( '_send', $msg );
}



# -- Collection: retrieving the whole collection

#
# event: coll.all_files()
#
# Return a mpd_result event with the list of all filenames (strings)
# currently known by mpd.
#
sub _onpub_all_files {
    my $msg = POE::Component::Client::MPD::Message->new( {
        _from     => $_[SENDER]->ID,
        _request  => $_[STATE],
        _answer   => $SEND,
        _commands => [ 'list filename' ],
        _cooking  => $STRIP_FIRST,
    } );
    $_[KERNEL]->yield( '_send', $msg );
}

# -- Collection: picking songs
# -- Collection: songs, albums & artists relations

1;

__END__

=head1 NAME

POE::Component::Client::MPD::Collection - module handling collection commands


=head1 DESCRIPTION

C<POCOCM::Collection> is responsible for handling collection-related
commands. To achieve those commands, send the corresponding event to
the POCOCM session you created: it will be responsible for dispatching
the event where it is needed.


=head1 PUBLIC EVENTS

The following is a list of general purpose events accepted by POCOCM.


=head2 Retrieving songs & directories

=head2 Retrieving the whole collection

=head2 Picking songs

=head2 Songs, albums & artists relations


=head1 SEE ALSO

For all related information (bug reporting, mailing-list, pointers to
MPD and POE, etc.), refer to C<POE::Component::Client::MPD>'s pod,
section C<SEE ALSO>


=head1 AUTHOR

Jerome Quelin, C<< <jquelin at cpan.org> >>


=head1 COPYRIGHT & LICENSE

Copyright (c) 2007 Jerome Quelin, all rights reserved.

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
