#!/usr/bin/perl
#
# This file is part of GNU Stow.
#
# GNU Stow is free software: you can redistribute it and/or modify it
# under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# GNU Stow is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
# General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program. If not, see https://www.gnu.org/licenses/.

#
# Testing defer().
#

use strict;
use warnings;

use testutil;

use Test::More tests => 4;

init_test_dirs();
cd("$TEST_DIR/target");

my $stow;

$stow = new_Stow( defer => ['man'] );
ok( $stow->defer('man/man1/file.1') => 'simple success' );

$stow = new_Stow( defer => ['lib'] );
ok( !$stow->defer('man/man1/file.1') => 'simple failure' );

$stow = new_Stow( defer => [ 'lib', 'man', 'share' ] );
ok( $stow->defer('man/man1/file.1') => 'complex success' );

$stow = new_Stow( defer => [ 'lib', 'man', 'share' ] );
ok( !$stow->defer('bin/file') => 'complex failure' );
