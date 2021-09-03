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
# Testing cleanup_invalid_links()
#

use strict;
use warnings;

use Test::More tests => 2;
use English qw(-no_match_vars);

use testutil;

init_test_dirs();
cd("$TEST_DIR/target");

make_path('../stow/pkg1/bin1');
make_file('../stow/pkg1/bin1/file1');
ok(make_link('bin1', '../stow/pkg1/bin1'), 'create link');
ok(-e 'bin1', 'link exists')
