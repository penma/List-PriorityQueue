#!/usr/bin/env perl
use strict;
use warnings;
use Module::Build;

my $build = Module::Build->new(
	module_name => "List::PriorityQueue",
	recursive_test_files => 1,
);
$build->create_build_script;
