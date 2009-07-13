#!/usr/bin/env perl
use strict;
use warnings;
use Test::More tests => 3;

use List::PriorityQueue;

my $q = new List::PriorityQueue;

# try to insert an already existing element.
# you shouldn't do that anyway and use update instead, but if you suck so
# much that you cannot, then you at least shouldn't confuse the module with
# duplicates. - so insert DOES call update if the entry exists, but it
# could just as well croak.
$q->insert("a", 2);
$q->insert("a", 5);
$q->insert("b", 3);
is($q->pop(), "b", "1st retrieved element is b");
is($q->pop(), "a", "2nd retrieved element is a");
ok(!defined($q->pop()), "No 3rd element");

