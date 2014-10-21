#!perl
#
# This file is part of POE::Component::Client::MPD.
# Copyright (c) 2007 Jerome Quelin, all rights reserved.
#
# This program is free software; you can redistribute it and/or modify
# it under the same terms as Perl itself.
#
#

use strict;
use warnings;

use POE qw[ Component::Client::MPD::Message ];
use Readonly;
use Test::More;


our $nbtests = 6;
our @tests   = (
    # [ 'event', [ $arg1, $arg2, ... ], $answer_back, \&check_results ]

    # coll.all_albums
    [ 'coll.all_albums',  [], $SEND, \&check_all_albums ],

    # coll.all_artists
    [ 'coll.all_artists', [], $SEND, \&check_all_artists ],

    # coll.all_titles
    [ 'coll.all_titles',  [], $SEND, \&check_all_titles ],
);


# are we able to test module?
eval 'use POE::Component::Client::MPD::Test';
plan skip_all => $@ if $@ =~ s/\n+BEGIN failed--compilation aborted.*//s;
exit;


sub check_all_albums {
    my @list = @{ $_[0]->data };
    is( scalar @list, 1, 'all_albums return the albums' );
    is( $list[0], 'our album', 'all_albums return strings' );
}

sub check_all_artists {
    my @list = @{ $_[0]->data };
    is( scalar @list, 1, 'all_artists return the artists' );
    is( $list[0], 'dir1-artist', 'all_artists return strings' );
}

sub check_all_titles {
    my @list = @{ $_[0]->data };
    is( scalar @list, 3, 'all_titles return the titles' );
    like( $list[0], qr/-title$/, 'all_titles return strings' );
}
