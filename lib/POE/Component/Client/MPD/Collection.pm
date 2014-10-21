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
# -- Collection: retrieving the whole collection

#
# event: pl.all_files()
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
