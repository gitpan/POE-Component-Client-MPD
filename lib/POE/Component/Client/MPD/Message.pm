#
# This file is part of POE::Component::Client::MPD.
# Copyright (c) 2007-2008 Jerome Quelin, all rights reserved.
#
# This program is free software; you can redistribute it and/or modify
# it under the same terms as Perl itself.
#
#

package POE::Component::Client::MPD::Message;

use strict;
use warnings;

use Readonly;

use base qw{ Class::Accessor::Fast Exporter };
__PACKAGE__->mk_accessors( qw{
    request params status
    _data _commands _cooking _transform _post _from
} );

our @EXPORT = qw{
    $SEND $DISCARD $SLEEP1
    $RAW $AS_ITEMS $AS_KV $STRIP_FIRST
    $AS_SCALAR $AS_STATS $AS_STATUS
};


# constants for _answer
Readonly our $SEND    => 0;
Readonly our $DISCARD => 1;
Readonly our $SLEEP1  => 2; # for test purposes

# constants for _cooking
Readonly our $RAW         => 0; # data is to be returned raw
Readonly our $AS_ITEMS    => 1; # data is to be returned as amc-item
Readonly our $AS_KV       => 2; # data is to be returned as kv (hash)
Readonly our $STRIP_FIRST => 3; # data should have its first field stripped

# constants for _transform
Readonly our $AS_SCALAR => 0; # transform data: return first elem instead of full list
Readonly our $AS_STATS  => 1; # transform data: from kv to amc-stats
Readonly our $AS_STATUS => 2; # transform data: from kv to amc-status



1;

__END__

=head1 NAME

POE::Component::Client::MPD::Message - a message from POCOCM


=head1 SYNOPSIS

    print $msg->data . "\n";


=head1 DESCRIPTION

C<POCOCM::Message> is more a placeholder for a hash ref with some pre-defined
keys.


=head1 PUBLIC METHODS

This module has a C<new()> constructor, which should only be called by
one of the C<POCOCM>'s modules.

The other public methods are the following accessors:

=over 4

=item * request()

The event sent to POCOCM.


=item * params()

The params of the event to POCOCM, as sent by client.


=item * status()

The status of the request. True for success, False in case of error.


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
