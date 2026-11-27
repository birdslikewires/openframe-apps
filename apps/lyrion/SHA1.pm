package Digest::SHA1;

# Digest::SHA1's interface over Perl's own Digest::SHA, for Lyrion on the OpenFrame: Debian doesn't package Digest::SHA1, and Lyrion has no compiled copy of it for i386 with Trixie's Perl.

use strict;
use Digest::SHA ();
use Exporter 'import';

our $VERSION = '2.13';
our @EXPORT_OK = qw(sha1 sha1_hex sha1_base64);

*sha1 = \&Digest::SHA::sha1;
*sha1_hex = \&Digest::SHA::sha1_hex;
*sha1_base64 = \&Digest::SHA::sha1_base64;

sub new { return Digest::SHA->new(1) }

1;
