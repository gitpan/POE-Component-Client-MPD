#!perl
#
# This file is part of Audio::MPD.
# Copyright (c) 2007 Jerome Quelin <jquelin@cpan.org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or (at
# your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation Inc., 59 Temple Place, Suite 330, Boston, MA 02111-1307 USA
#
#

use strict;
use warnings;

use POE qw[ Component::Client::MPD::Connection ];
use Test::More;
plan tests => 1;

my $id = POE::Session->create(
    inline_states => {
        _start     => \&_onpriv_start,
        _mpd_error => \&_onpriv_mpd_error,
    }
);
POE::Component::Client::MPD::Connection->spawn( {
    host => 'localhost',
    port => 16600,
    id   => $id,
} );
POE::Kernel->run;
exit;


sub _onpriv_start {
    $_[KERNEL]->alias_set('tester'); # increment refcount
}

sub _onpriv_mpd_error  {
    like( $_[ARG0]->error, qr/^connect: \(\d+\) /, 'connect error trapped' );
}

