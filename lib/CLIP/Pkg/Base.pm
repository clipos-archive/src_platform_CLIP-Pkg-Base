# SPDX-License-Identifier: LGPL-2.1-or-later
# Copyright © 2008-2018 ANSSI. All Rights Reserved.
package CLIP::Pkg::Base;

use 5.008008;
use strict;
use warnings;
use File::Basename;
use Time::Local;
use File::Path;
use Sort::Versions;

use CLIP::Logger qw(:all);

use CLIP::Pkg::Gencrypt;

require Exporter;

our @ISA = qw(Exporter);

our %EXPORT_TAGS = ( 'all' => [ qw(
clippkg_backup
clippkg_rollback
clippkg_replace
clippkg_clean
clippkg_get_arch
clippkg_get_confs
clippkg_get_confname
clippkg_get_fields
clippkg_get_installed_fields
clippkg_get_depends
clippkg_get_dephash
clippkg_get_full_depends
clippkg_get_deplist
clippkg_get_duplicates
clippkg_cache_get_fields
clippkg_cache_get_all_fields
clippkg_format_date
clippkg_check_release_date
clippkg_check_date
clippkg_check_sig
clippkg_check_fields
clippkg_sigcheck_start
clippkg_sigcheck_stop
clippkg_check_pkg
clippkg_check_pkg_msg
clippkg_check_optional
clippkg_is_conf
clippkg_update_db
clippkg_list_installed_confs
clippkg_list_optional
clippkg_list_upgrade_candidates
clippkg_list_upgrade_configurations
clippkg_list_mirror_optional
clippkg_list_allowed_optional
clippkg_prune
clippkg_apt_error
clippkg_lock
clippkg_unlock
$g_dpkg_admin_dir
) ] );

our @EXPORT_OK = ( @{ $EXPORT_TAGS{'all'} } );

our @EXPORT = qw(
);

our $VERSION = '1.1.26';
	
=head1 NAME

CLIP::Pkg::Base - Perl extension to manage CLIP packages - common part.

=head1 VERSION

Version 1.1.26

=head1 SYNOPSIS

  use CLIP::Pkg::Base;
  use CLIP::Pkg::Base ':all';

=head1 DESCRIPTION

CLIP::Pkg::Base provides basic functions to manipulate CLIP binary packages and 
mirrors : field extraction and verification, signature checks, listing of 
available updates, and so forth. It is mostly used through one of the more 
specialized CLIP package management modules, e.g. CLIP::Pkg::Install or 
CLIP::Pkg::Download.

CLIP::Pkg::Base logs its outputs through the CLIP::Logger module.

=head1 EXPORT

The module does not export anything by default. It defines a single Exporter 
tag, ":all", which exports the following functions and variables:

=over 4

=item * 

B<clippkg_backup()>

=item * 

B<clippkg_rollback()>

=item * 

B<clippkg_replace()>

=item * 

B<clippkg_clean()>

=item * 

B<clippkg_get_arch()>

=item * 

B<clippkg_get_confs()>

=item * 

B<clippkg_get_confname()>

=item * 

B<clippkg_get_fields()>

=item * 

B<clippkg_get_installed_fields()>

=item * 

B<clippkg_get_depends()>

=item *

B<clippkg_get_dephash()>

=item * 

B<clippkg_get_full_depends()>

=item * 

B<clippkg_get_deplist()>

=item *

B<clippkg_cache_get_fields()>

=item *

B<clippkg_cache_get_all_fields()>

=item * 

B<clippkg_format_date()>

=item * 

B<clippkg_check_release_date()>

=item * 

B<clippkg_check_date()>

=item * 

B<clippkg_check_sig()>

=item *

B<clippkg_check_fields()>

=item * 

B<clippkg_sigcheck_start()>

=item * 

B<clippkg_sigcheck_stop()>

=item * 

B<clippkg_check_pkg()>

=item * 

B<clippkg_check_pkg_msg()>

=item * 

B<clippkg_get_duplicates()>

=item * 

B<clippkg_check_optional()>

=item *

B<clippkg_is_conf()>

=item *

B<clippkg_update_db()>

=item *

B<clippkg_list_installed_confs()>

=item *

B<clippkg_list_optional()>

=item * 

B<clippkg_list_upgrade_candidates()>

=item * 

B<clippkg_list_upgrade_configurations()>

=item *

B<clippkg_list_mirror_optional()>

=item *

=item *

B<clippkg_list_allowed_optional()>

=item *

B<clippkg_prune()>

=item *

B<clippkg_apt_error()>

=item * 

B<clippkg_lock()>

=item * 

B<clippkg_unlock()>

=item *

B<$g_dpkg_admin_dir>

=back

=cut

###############################################################
#                          VARIABLES                          #
###############################################################

=head1 VARIABLES

CLIP::Pkg::Base can be configured through the following variables:

=cut

                       ####################
		       #      Paths       #
		       ####################

=head2 Paths

=over 4

=cut

=item B<$CLIP::Pkg::Base::g_dpkg_admin_dir>

Path to the current DPKG 'admin' directory, e.g. "/var/lib/dpkg".

=cut

our $g_dpkg_admin_dir;

=item B<$CLIP::Pkg::Base::g_prefix_key>

Prefix that can be prepended to path of certificates used for verification

=cut

our $g_prefix_key = "";

=item B<$CLIP::Pkg::Base::g_optional_pkg_files>

Reference to a list of files containing optional package names 
(short names) that should be installed on this system.

=cut

our $g_optional_pkg_files;

=cut

=item B<$CLIP::Pkg::Base::g_sigcheck_sockpath>

Path to the listening socket created by the checker daemon.

=cut

our $g_sigcheck_sockpath = "";

=back


                       #############################
		       #      Global options       #
		       #############################

=head2 Global options

=over 4

=item B<$CLIP::Pkg::Base::g_lock_nonblock>

Boolean: use non-blocking locks in clippkg_lock() calls (default = 0).

=cut

our $g_lock_nonblock = 0;

=item B<$CLIP::Pkg::Base::g_apt_opts>

Global apt-get options, passed on every call to apt-get.
Defaults to C<--yes --force-yes --allow-unauthenticated>.

=cut

our $g_apt_opts = "-y --force-yes --allow-unauthenticated";

=back

=cut

                       ###################################
		       #      Configuration checks       #
		       ###################################

=head2 Configuration checks

=over 4

=item B<$CLIP::Pkg::Base::g_conf_opts>

Global configuration checking options. This is a reference to a hash, in
which the following keys can be re-defined:

=over 8

=item C<rej_young>

Boolean: reject configurations that are younger than the configured 
minimum age, or younger than the current time (default: 0).

=item C<rej_old>

Boolean: reject configurations that are older than the configured maximum age
(default: 0).

=item C<rej_older> 

Boolean: reject configurations that are older than their installed version
(default: 0).
 
=back

=cut

our $g_conf_opts = {
	"rej_young"	=>	0,
	"rej_old"	=>	0, 
	"rej_older"	=>	0,
};

=item B<$CLIP::Pkg::Base::g_conf_max_ages>

Reference to a hash keyed by configuration names (i.e. the Debian C<Package:> 
field of the configuration deb package) to each configuration's maximum age, 
in seconds (default: no keys == no maximum age).

=cut

our $g_conf_max_ages;

=item B<$CLIP::Pkg::Base::g_conf_max_ages>

Reference to a hash keyed by configuration names (i.e. the Debian C<Package:> 
field of the configuration deb package) to each configuration's minimum age, 
in seconds (default: no keys == no maximum age).

=cut

our $g_conf_min_ages;

=item B<$CLIP::Pkg::Base::g_with_rm_apps_specific>

Define if RM paquages will be specific for each level: rm_h and rm_b.

=cut

our $g_with_rm_apps_specific = 0;

=back

=cut
                       #############################
		       #      Package checks       #
		       #############################

=head2 Package checks

=over 4

=item B<$CLIP::Pkg::Base::g_fields>

Debian package fields that need to be checked by clippkg_check_pkg().
Defaults to C<Priority>, C<Distribution>, C<Impact>.

=cut
our $g_fields = qq(Priority Distribution Impact);

=item B<$CLIP::Pkg::Base::g_pkg_opts>

Expected values for fields checked through B<$CLIP::Pkg::Base::g_fields>.
This is a reference to a hash keyed by the names of checked fields. 
An empty value for a given key (which is the default for all keys) means 
that all values are accepted for this field. Otherwise, an exact match
is checked between that value and that exctracted from the package to 
be checked.

=cut

our $g_pkg_opts = {
	Priority		=> "",
	Distribution		=> "",
	Impact			=> "",
};

                       ########################
		       #      Constants       #
		       ########################

# Month indexes
my $g_months = {
	Jan	=> 0,
	Feb	=> 1,
	Mar	=> 2,
	Apr	=> 3,
	May	=> 4,
	Jun	=> 5,
	Jul	=> 6,
	Aug	=> 7,
	Sep	=> 8,
	Oct	=> 9,
	Nov	=> 10,
	Dec	=> 11,
};

# RFC 822 date parser, extracting day, month, year, hour, min, sec, +/-, delta
my $g_rfc822_re = '\D{3}, (\d{1,2}) (\D{3}) (\d{4}) (\d{2}):(\d{2}):(\d{2}) ([\+-])(\d{2})\d{2}';

###############################################################
#                          SUBS                               #
###############################################################

=back

=head1 FUNCTIONS

CLIP::Pkg::Base provides the following functions:

=cut
		       
                       ################################
		       #      Backup / rollback       #
		       ################################

=head2 Backup / rollback functions

=over 4

=item B<CLIP::Pkg::Base::_rcopy($src, $dst)

Internal use only. Copy $src (file or directory) to $dest (file or directory),
while preserving permissions and ownership. Used rather than 
File::Copy::Recursive::rcopy, which does not preserve ownership

=cut

sub _rcopy($$) {
	my ($src, $dst) = @_;
	my @args = ("cp", "-af", "$src", "$dst");

	if (system(@args) == 0) {
		return 1;
	} else {
		return 0;
	}
}

=item B<CLIP::Pkg::Base::_rmove($src, $dst)

Internal use only. Move $src (file or directory) to $dest (file or directory),
while preserving permissions and ownership. Used rather than 
File::Copy::Recursive::rmove, which does not preserve ownership

=cut

sub _rmove($$) {
	my ($src, $dst) = @_;
	my @args = ("mv", "-f", "$src", "$dst");

	if (system(@args) == 0) {
		return 1;
	} else {
		return 0;
	}
}

=item B<clippkg_backup($path)>

Creates a backup of the file or directory under $path, by copying it to 
C<$path.bck>.  A temporary file named C<$path.tmp> is used during the copy, 
to make sure C<$path.bck> is whole when created.
Returns 1 on success, 0 on error.

=cut

sub clippkg_backup($) {
	my $path = shift;
	unless ($path and -e $path) {
		clip_warn "cannot backup $path: no such file or directory";
		# Do not return an error here
		return 1;
	}

	if (-e "$path.bck") {
		clip_warn "$path.bck exists, will keep it";
		return 1;
	}

	if (-e "$path.tmp") {
		clip_warn "leftover $path.tmp will be removed";
		unless (rmtree("$path.tmp")) {
			clip_warn "leftover $path.tmp could not be removed";
			return 0;
		}
	}

	unless (_rcopy("$path", "$path.tmp")) {
		clip_warn "could not copy $path to $path.tmp";
		return 0;
	}

	unless (_rmove("$path.tmp", "$path.bck")) {
		clip_warn "could not mv $path.tmp to $path.bck";
		rmtree("$path.tmp");
		return 0;
	}

	return 1;
}

=item B<clippkg_rollback($path)>

Rolls back the file or directory under $path, by copying over it the contents 
of C<$path.bck>, if it exists. C<$path.bck> is removed before the function 
returns.
Returns 1 on success, 0 on error.

=cut

sub clippkg_rollback($) {
	my $path = shift;

	unless ($path) {
		clip_warn "cannot rollback empty path";
		return 0;
	}
	unless (-e "$path.bck") {
		clip_warn "cannot rollback $path: no backup";
		# No error here - no file was backed up, no
		# point failling the whole update
		return 1;
	}

	if (-e "$path" and not rmtree("$path")) {
		clip_warn "could not remove $path for rollback";
		return 0;
	}

	unless (_rmove("$path.bck", "$path")) {
		clip_warn "could not rollback $path";
		return 0;
	}

	return 1;
}

=item B<clippkg_replace($src, $dest)>

Replaces  the file or directory under $dest by $src, after saving a backup of 
the original $dest under C<$dest.bck> (which must not exist before the call).
Returns 1 on success, 0 on error.

=cut

sub clippkg_replace($$) {
	my ($src, $dest) = @_;

	unless (-e $src) {
		clip_warn "Cannot replace $dest with $src - "
			."source file does not exist";
		# No error here - no point blocking updates
		# because a silly admin removed one file.
		return 1;
	}
	if (-e $dest) {
		if (-e "$dest.bck") {
			clip_warn "$dest.bck exists, will not overwrite it";
			unless (rmtree($dest)) {
				clip_warn "could not remove $dest "
					."to replace it";
				# leave here, we cannot rollback if we cannot 
				# delete
				return 0;
			}
		} else {
			unless (_rmove("$dest", "$dest.bck")) {
				clip_warn "could not move $dest to $dest.bck";
				return 0;
			}
		}
	} else {
		clip_warn "no $dest to replace, will create it";
	}

	unless (_rcopy($src, $dest)) {
		clip_warn "could not copy $src to $dest";
		clippkg_rollback($dest);
		return 0;
	}
	return 1;
}

=item B<clippkg_clean($path)>

Safely removes  a backup of file or directory $path, created under 
C<$path.bck> by clippkg_backup() or clippkg_replace().
Returns 1 on success, 0 on error.

=cut

sub clippkg_clean($) {
	my $path = shift;

	unless (-e "$path.bck") {
		clip_warn "$path.bck does not exist, cannot clean it";
		return 1;
	}
	if (-e "$path.tmp" and not rmtree("$path.tmp")) {
		clip_warn "failed to remove $path.tmp, cannot clean $path.bck";
		return 0;
	}
	unless (_rmove("$path.bck", "$path.tmp")) {
		clip_warn "failed to rename $path.bck, cannot clean it";
		return 0;
	}
	unless (rmtree("$path.tmp")) {
		clip_warn "failed to remove $path.tmp";
		return 0;
	}

	return 1;
}

=back

=cut
                       ################################
		       #      Local configuration     #
		       ################################

=head2 Local config information

=over 4

=item B<clippkg_get_arch()>

Returns the arch string (e.g. C<i386>) of the current dpkg installation,
or C<undef> in case of error.

=cut

sub clippkg_get_arch() {
	open PIPE, "dpkg --print-architecture 2>&1 |";
	my @output = <PIPE>;
	close PIPE;

	if ($?) {
		clip_warn "dpkg --print-architecture failed";
		foreach (@output) {
			clip_warn "dpkg output: $_";
		}
		return undef;
	}
	if ($#output != 0) {
		clip_warn "dpkg --print-architecture : unexpected output:";
		foreach (@output) {
			clip_warn "dpkg output: $_";
		}
	}
	my $arch = $output[0];
	chomp $arch;
	return $arch;
}

=back

=cut
                       ############################
		       #      Package parsing     #
		       ############################

=head2 Package parsing

=over 4

=item B<clippkg_get_fields($pkg, $fields)>

Reads the fields whose names are defined in the string $fields (space 
separated), in the package file located at $pkg (full path). 
If $fields is empty, read all fields in the package control file.
Returns a reference to a hash keyed by the field names, and containing the 
field values, or C<undef> in case of error.

=cut

sub clippkg_get_fields($$) {
	my ($pkg, $fields) = @_;

	open PIPE, "dpkg -f $pkg $fields 2>&1|";
	my @output = <PIPE>;
	close PIPE;
	if ($?) {
		clip_warn "failed to get control fields on ".(basename($pkg));
		foreach (@output) {
			clip_warn "dpkg output: $_";
		}
		return undef;
	}

	my %hashed_fields; 
	if (not $fields or $fields =~ /\s/) {
		# Several fields read at once
		foreach (@output) {
			unless ((/^([^:]+): (.*)/)) {
				clip_warn "failed to read control field $_ on "
							.(basename($pkg));
				return undef;
			}
			$hashed_fields{$1} = $2;
		}
	} else {
		# Read only one field
		$hashed_fields{$fields} = $output[0];
	}

	return \%hashed_fields;
}


=item B<clippkg_get_installed_fields($pkg, $fields, $warn_p)>

Reads  the Debian package fields defined in $fields (space separated string) 
for the installed version of $pkg (package name).
Returns a reference to a hash keyed by the field names and containing the 
field values, or C<undef> in case of error, in particular if the package is
not locally installed. In that precise case, a warning is output if and only
if $warn_p is non-null.

=cut

sub clippkg_get_installed_fields($$$) {
	my ($pkg, $fields, $warn_p) = @_;

	my @all_fields = split ' ', $fields;

	my $pname = basename $pkg;
	$pname =~ s/_\S+.deb$//;

	open PIPE, "dpkg-query --admindir=$g_dpkg_admin_dir "
			."-s \'$pname\' 2>&1|";
	my @output = <PIPE>;
	close PIPE;
	if ($?) {
		if ($warn_p) {
			clip_warn "dpkg-query failed on $pname";
			foreach (@output) {
				clip_warn "dpkg-query output: $_";
			}
		}
		return undef;
	}

	my %hashed_fields; 

	foreach my $line (@output) {
		foreach my $field (@all_fields) {
			next unless ($line =~ /^$field: (.*)/);
			
			# Silently overwrite in case of duplicates
			$hashed_fields{$field} = $1;
		}
	}

	foreach my $field (@all_fields) {
		unless (defined ($hashed_fields{$field})) {
			clip_warn "failed to read control field $field "
					."on $pname";
			return undef;
		}
	}
	return \%hashed_fields;
}

=item B<clippkg_get_depends($pkg, $suggests_p)>

Gets  the dependencies (names only) of the package file located at $pkg.
Returns a reference to a list of package names $pkg depends upon, or 
C<undef> in case of error.
By default (when $suggests_p is zero), the "Depends:" field of package 
$pkg is used to extract the dependencies. When $suggests_p is passed as 1,
the "Suggests:" field is used instead.

=cut

sub clippkg_get_depends($$) {
	my ($pkg, $sug_p) = @_;
	my $field = ($sug_p) ? "Suggests" : "Depends";

	open PIPE, "dpkg -f \'$pkg\' $field 2>&1 |";
	my @output = <PIPE>;
	close PIPE;
	if ($?) {
		clip_warn "failed to get dependencies for ".(basename $pkg);
		foreach my $line (@output) {
			clip_warn "dpkg output: $line";
		}
		return undef;
	}
	if ($#output < 0) {
		# No deps
		my @deps = ();
		return \@deps;
	}

	chomp $output[0];
	my @fdeps = split ", ", $output[0];
	my @deps = map { s/ \(.*\)$//; $_ } @fdeps;

	return \@deps;
}

=item B<clippkg_get_dephash($pkg, $suggests_p, $hash)>

Creates a hash of dependencies for a configuration found under $pkg.
$pkg can be either a full package path (ending in ".deb"), or a short package
name (no version/arch, no ".deb") for an installed package. 
$hash is a reference to a hash keyed by package names (without version or arch),
whose values are the versions required for each of those packages. 
The dependencies extracted from $pkg are added to that hash.
By default (when $suggests_p is zero), the "Depends:" field of package 
$pkg is used to extract the dependencies. When $suggests_p is passed as 1,
the "Suggests:" field is used instead.

Returns 1 on success, 0 on error.

=cut

sub clippkg_get_dephash($$$) {
	my ($pkg, $sug_p, $hash) = @_;

	my $field = ($sug_p) ? "Suggests" : "Depends";

	my @output = ();
	if ($pkg =~ /.deb$/) {
		open PIPE, "dpkg -f \'$pkg\' $field 2>&1 |";
		@output = <PIPE>;
		close PIPE;
		if ($?) {
			clip_warn "Failed to get \"$field\" dependencies for "
								.(basename $pkg);
			foreach (@output) {
				clip_warn "dpkg output: $_";
			}
			return 0;
		}
	} else {
		open PIPE, "dpkg-query --admindir=$g_dpkg_admin_dir "
						."-s \'$pkg\' 2>&1|";
		my @tmp = <PIPE>;
		close PIPE;
		if ($?) {
			clip_warn "dpkg-query failed on $pkg";
			foreach (@tmp) {
				clip_warn "dpkg-query output: $_";
			}
		}
	INLOOP:
		foreach my $line (@tmp) {
			if ($line =~ /$field: (.*)$/) {
				push @output, ($1);
				last INLOOP;
			}
		}
	}
	
	if ($#output < 0) {
		# No deps
		return 1;
	}

	chomp $output[0];
	my @fdeps = split ", ", $output[0];
DEPLOOP:
	foreach my $dep (@fdeps) {
		unless ($dep =~ /(\S+) \(= (\S+)\)/) {
			clip_warn "cannot extract unique version from "
					."dependency: $dep";
			return 0;
		}
		my $pname = $1;
		my $pver = $2;
		if (defined ($hash->{$pname})) {
			if ("$hash->{$pname}" ne "$pver") {
				clip_warn "conflicting versions for dependency "					."$pname $hash->{$pname} != $pver";
				return 0;
			} else {
				clip_warn "redundant dependency on $pname";
				next DEPLOOP;
			}
		}
		$hash->{$pname} = $pver;
	}

	return 1;
}

=item B<clippkg_get_full_depends($pkg, $suggests_p)>

Gets  the full dependencies of the package file located at $pkg.
Returns a reference to a list of full package names 
([name]_[version]_[arch].deb) $pkg depends upon, or 
C<undef> in case of error.
By default (when $suggests_p is zero), the "Depends:" field of package 
$pkg is used to extract the dependencies. When $suggests_p is passed as 1,
the "Suggests:" field is used instead. When $suggests_p is passed as 2,
both fields are used.

=cut

sub clippkg_get_full_depends($$) {
	my ($pkg, $sug_p) = @_;
	my $arch;

	if ($pkg =~ /_([^_]+)\.deb$/) {
		$arch = $1;
	} else {
		clip_warn "cannot extract arch from package name: "
							.(basename $pkg);
		return 0;
	}

	my %hash;
	if ($sug_p == 2) {
		unless (clippkg_get_dephash($pkg, 0, \%hash)) {
			clip_warn "failure to get dephash";
			return undef;
		}
		unless (clippkg_get_dephash($pkg, 1, \%hash)) {
			clip_warn "failure to get dephash";
			return undef;
		}
	} else {
		unless (clippkg_get_dephash($pkg, $sug_p, \%hash)) {
			clip_warn "failure to get dephash";
			return undef;
		}
	}

	my @deps = ();
	foreach my $pname (keys %hash) {
		push @deps, ("$pname"."_"."$hash{$pname}"."_"."$arch.deb");
	}

	return \@deps;
}

=item B<clippkg_get_deplist($conflist, $path, $suggests_p)>

Creates  a hash of dependencies for a list of configurations, whose names are 
in the list referenced by $conflist, and whose package files can be found 
under the directory path $path.
By default (when $suggests_p is zero), the "Depends:" field of package $pkg is 
used to extract the dependencies. When $suggests_p is passed as 1, the 
"Suggests:" field is used instead. When $suggests_p is passed as 2, both 
fields are used.
Returns a reference to a hash keyed by package full names, with keys 
corresponding to every package that is referenced as a dependency of any one 
of the configurations in $conflist (and with '1' as the associated value for 
each key). The configurations themselves are not included in that hash, unless 
they depend on each other.  C<undef> is returned in case of error.

=cut

sub clippkg_get_deplist($$$) {
	my ($clist, $path, $sug_p) = @_;

	$path = "$path/" if ($path);

	my %refs;

	foreach my $conf (@{$clist}) {
		my $deplist;
		if (defined ($deplist = 
			clippkg_get_full_depends("$path$conf", $sug_p))) {
			foreach my $pkg (@{$deplist}) {
				$refs{$pkg} = 1;
			}
		} else {
			return undef;
		}
	}
		
	return \%refs;
}



=item B<clippkg_get_duplicates($plist, $dups, $keep)>

Extracts duplicates from a list of packages (full names) referenced by $plist.
Duplicates are versions of each package that are older (inferior version) than 
the latest version of the same package listed in @{$plist}. The full names of 
duplicates are added to the list referenced by $dups, while those of other 
packages (which are the latest version of their package) are added to the list 
referenced by $keep.
Returns 1.

=cut

sub clippkg_get_duplicates($$$) {
	# Ref to a list of packages present in the mirror
	my ($plist,$dups,$keep) = @_;

	return 1 if ($#{$plist} == -1);


	# Hash: match package name -> ref to list of versions of that package
	# present in the mirror
	my %versions; 

	my $suf = "";
	foreach my $pkg (@{$plist}) {
		if ($pkg =~ /^([^_]+)_([^_]+)_(\S+)/) {
			my $pname = $1;
			my $pver = $2;
			$suf = $3 unless ($suf);
			unless (defined ($versions{$pname})) {
				$versions{$pname} = [ $pver ];
			} else {
				push @{$versions{$pname}}, ($pver);
			}
		} else {
			clip_warn "cannot extract version from package $pkg";
		}
	}
	
	foreach my $pname (keys %versions) {
		my $lref = $versions{$pname};
		my @slist = sort versioncmp @{$lref};
		if ($#slist > 0) {
			# All elements except the last one are duplicates
			foreach my $pver (@slist[0 .. $#slist - 1]) {
				push @{$dups}, 
					("$pname"."_"."$pver"."_"."$suf");
			}
		}
		push @{$keep}, ("$pname"."_"."$slist[-1]"."_"."$suf");
	}

	return 1;
}

=item B<clippkg_cache_get_fields($pkg>

Return all fields of the latest version of package $pkg in the current apt 
cache, as a hash matching field names to field values.

Returns a reference to that hash if found, C<undef> otherwise.

=cut

sub clippkg_cache_get_fields($) {
	my $pkg = shift;
	my %hash;

	open PIPE, "apt-cache show --no-all-versions -- $pkg 2>&1|";
	my @output = <PIPE>;
	close PIPE;
	if ($?) {
		clip_warn "failed to get cached control fields on $pkg";
		foreach (@output) {
			clip_warn "apt-cache output: $_";
		}
		return undef;
	}

FIELDLOOP:
	foreach (@output) {
		# Return first match : only latest version available
		if (/^([^: ]+): (.*)/) {
			# Dual definition for any field means we've reached the
			# second entry in cache
			last FIELDLOOP if (defined($hash{$1}));
			$hash{$1} = $2;
		}
	}
	return \%hash;
}

=item B<clippkg_cache_get_all_fields($pkg>

Return all fields of the latest version of package $pkg in the current apt 
cache, as a hash matching field names to field values.
This is the same function as clippkg_cache_get_all(), except it keeps going 
over any duplicate entries, without overriding fields, but adding new fields 
as it goes.  
Returns a reference to that hash if found, C<undef> otherwise.

=cut

sub clippkg_cache_get_all_fields($) {
	my $pkg = shift;
	my %hash;

	open PIPE, "apt-cache show --no-all-versions -- $pkg 2>&1|";
	my @output = <PIPE>;
	close PIPE;
	if ($?) {
		clip_warn "failed to get cached control fields on $pkg";
		foreach (@output) {
			clip_warn "apt-cache output: $_";
		}
		return undef;
	}

FIELDLOOP:
	foreach (@output) {
		# Keep first match : latest version available
		if (/^([^: ]+): (.*)/) {
			$hash{$1} = $2 unless (defined($hash{$1}));;
		}
	}
	return \%hash;
}

=back

=cut
                       ####################################
		       #      Date parsing and checks     #
		       ####################################

=head2 Date parsing and checks

=over 4

=item B<clippkg_format_date($822_date)>

Parses  the RFC-822 formatted (e.g. C<Tue, 14 Oct 2008 15:16:38 +0200>)
date in $822_date, and return the epoch time corresponding to that date.
Returns an empty string if parsing failed.

=cut

sub clippkg_format_date($) {
	my $date822 = shift;

	my ($sec, $min, $hour, $mday, $mon, $year);

	if ($date822 =~ /^$g_rfc822_re$/) {
		$mday = $1;
		unless (defined ($g_months->{$2})) {
			clip_warn "invalid month: $2";
			return "";
		}
		$mon = $g_months->{$2};
		$year = $3;
		$hour = $4;
		$min = $5;
		$sec = $6;
		# Taking time zone into account is actually more 
		# complicated than that - leaving it off for now...
		#$hour = ($7 eq '+') ? $hour - $8 : $hour + $8;
	} else {
		clip_warn "invalid release date: $date822";
		return "";
	}

	my $ptime = timegm($sec, $min, $hour, $mday, $mon, $year);

	return $ptime;
}

=item B<clippkg_check_release_date($pkg, $pinfo)>

Checks the Release-Date on a configuration package $pkg, against the 
constraints defined in $g_conf_opts, $g_conf_max_ages and $g_conf_min_ages.
The configuration's Release-Date is passed through the package field hash 
(as returned by, e.g. clippkg_get_fields()) referenced by $pinfo.
Returns 1 if the configuration matches all of its constraints, and 0 if it
doesn't, or in case of error.

=cut

sub clippkg_check_release_date($$) {
	my ($pkg, $pinfo) = @_;
	my $pbase = basename $pkg;

	unless (defined ($pinfo->{"Release-Date"})) {
		clip_warn "package $pbase lacks a Release-Date";
		return 0;
	}
	my $ptime = clippkg_format_date($pinfo->{"Release-Date"});
	return 0 unless ($ptime);

	my $iinfo = clippkg_get_installed_fields($pkg, "Release-Date", 1);
	unless (defined $iinfo) {
		clip_warn "failed to read Release-Date on installed $pbase";
		return 0;
	}
	my $itime = clippkg_format_date($iinfo->{"Release-Date"});
	return 0 unless ($itime);

	my $time = time();

	my $age = $time - $ptime;

	if ($ptime > $time) {
		clip_warn "$pbase released in the future";
		return 0 if ($g_conf_opts->{"rej_young"});
		# Let's avoid negative ages...
		$age = 0;
	}
	if ($itime > $ptime) {
		clip_warn "$pbase is older than installed version";
		return 0 if ($g_conf_opts->{"rej_older"});
	}
	
	unless ($pbase =~ /^([^_]+)_/) {
		clip_warn "cannot extract package name for $pbase";
		return 0;
	}
	my $pname = $1;

	if ($g_conf_opts->{"rej_old"} 
			and defined ($g_conf_max_ages->{$pname})) {
		if ($ptime > $g_conf_max_ages->{$pname}) {
			clip_warn "$pbase is too old";
			return 0;
		}
	}
	if ($g_conf_opts->{"rej_young"} 
			and defined ($g_conf_min_ages->{$pname})) {
		if ($ptime < $g_conf_min_ages->{$pname}) {
			clip_warn "$pbase is too young";
			return 0;
		}
	}	

	return 1
}

=item B<clippkg_check_date($pkg, $curtime, $max_age)>

Checks  that package $pkg (full path) is not older than $max_age seconds, 
based on the current epoch time passed as $time, and on the Release-Date 
(for configurations) or Build-Date (for other packages) extracted from $pkg.
Returns 0 if the package is older than $max_age, and 1 otherwise.

=cut

sub clippkg_check_date($$$) {
	my ($pkg,$time,$max_age) = @_;

	my $pfields;
	
	unless (defined ($pfields = 
			clippkg_get_fields($pkg, "Release-Date Build-Date"))) {
		clip_warn "failed to read date fields on ".(basename $pkg);
		return 0;
	}

	my $pdate;
	if (defined ($pfields->{"Release-Date"})) {
		$pdate = $pfields->{"Release-Date"};
	}
	if (defined ($pfields->{"Build-Date"})) {
		$pdate = $pfields->{"Build-Date"};
	}
	unless ($pdate) {
		clip_warn "no valid date field in ".(basename $pkg);
		return 0;
	}

	my $ptime = clippkg_format_date($pdate);
	return 0 unless ($ptime);

	if ($ptime > $time) {
		clip_warn "package ".(basename $pkg)." is from the future";
		return 1; 	# Do not remove such a package. 
				# Note: expect the sh** to hit the fan sometime
				# around year 2038 :)
	}

	if (($time - $ptime) > $max_age) {
		return 0;
	} else {
		return 1;
	}
}

=back

=cut
                       #############################
		       #      Signature checks     #
		       #############################

=head2 Signature checks

=over 4

=item B<clippkg_check_sig($pkg)>

Checks the double signature of package $pkg (full path), using the certificates
referenced as $g_prefix_key/$g_ctrl_key and $g_prefix_key/$g_dev_key.
Returns 1 if both signatures match, and 0 otherwise.

=cut

sub clippkg_check_sig($) {
	my $pkg = shift;
	my $pname = basename($pkg);
	if (-e $g_sigcheck_sockpath) {
		my $args = "-S $g_sigcheck_sockpath";
		open PIPE, "check-client $args -c \'$pkg\' 2>&1|";
	} else {
		# Fall back if daemon is not started
		my $args = "-k $g_prefix_key/$g_dev_cert".
			" -K $g_prefix_key/$g_ctrl_cert".
			" -l $g_prefix_key/$g_dev_crl".
			" -L $g_prefix_key/$g_ctrl_crl".
			" -t $g_prefix_key/$g_dev_trusted_ca ".
			" -T $g_prefix_key/$g_ctrl_trusted_ca -d";
		open PIPE, "check $args \'$pkg\' 2>&1|";
	}
	my @output = <PIPE>;
	close PIPE;
	if ($?) {
		clip_warn "signature check failed on $pname";
		foreach (@output) {
			clip_warn "signature check output: $_";
		}
		return 0;
	} else {
		clip_debug "signature check OK on $pname";
		return 1;
	}
}

=item B<clippkg_check_fields($hash, $pkg)>

Check a package fields against those specified in the $g_pkg_opts hash.
The package fields are passed as a reference $hash to a hash matching 
field names to field values. The package name is passed as $pkg.

Only those fields defined in $g_pkg_opts need to be referenced in $hash, 
although other fields might be in there as well. $hash is typically returned 
by clippkg_get_fields() or clippkg_cache_get_fields().

Returns 1 if $hash matches $g_pkg_opts, 0 otherwise.

=cut

sub clippkg_check_fields($$) {
	my ($hash, $pname) = @_;

	foreach my $key (keys %{$g_pkg_opts}) {
		next if not ($g_pkg_opts->{$key});
		unless (defined($hash->{$key})) {
			clip_warn "Package $pname: no $key field";
			return 0;
		}
		if (lc($hash->{$key}) ne lc($g_pkg_opts->{$key})) {
			clip_warn "Excluding package $pname : "
				."wrong $key ($hash->{$key})";
			return 0;
		}
	}

	return 1;
}

=item B<clippkg_check_pkg_msg($pkg, $conf_p, $msg)>

Performs  full checks on package $pkg, by first checking its signatures, then 
its $g_fields fields against the values defined in $g_pkg_opts, then finally, 
and only in the case of a configuration package (which is indicated by $conf_p 
being non-null), checking its Release-Date against the age constraints defined 
in $g_conf_opts, $g_conf_max_ages and $g_conf_min_ages.
The $msg string argument is prepended to the 'XXX passed all checks' message 
logged in case of successful checks.
Returns 1 if $pkg passes all checks, and 0 otherwise.

=cut

sub clippkg_check_pkg_msg($$$) {
	my ($pkg, $conf_p, $msg) = @_;

	unless (clippkg_check_sig($pkg)) {
		clip_warn "removing ".(basename $pkg)." : wrong signature";
		return 0;
	}
	
	my $pinfo;
	my $fields = $g_fields;
	$fields = "$fields Release-Date" if ($conf_p);
	unless (defined ($pinfo = clippkg_get_fields($pkg, $fields))) {
		clip_warn "removing ".(basename $pkg)
				." : could not retrieve package information";
		return 0;
	}

	unless (clippkg_check_fields($pinfo, (basename $pkg))) {
		clip_warn "removing ".(basename $pkg)." : wrong fields";
		return 0;
	}

	if ($conf_p) {
		unless (clippkg_check_release_date($pkg, $pinfo)) {
			clip_warn "removing ".(basename $pkg)
						." : wrong release date";
			return 0;
		}
		clip_log "$msg"."configuration ".(basename $pkg)
							." passed all checks";
		return 1;
	} else {
		clip_log "$msg"."package ".(basename $pkg)
							." passed all checks";
		return 1;
	}

}

=item B<clippkg_sigcheck_start($checkdate)>

Start the check-daemon to check package signatures, with or without
checking for out-of-date certificates depending on $checkdate.
Returns 1 if daemon started OK, 0 otherwise.

=cut

sub clippkg_sigcheck_start($) {
	my $checkdate = shift;
	unlink $g_sigcheck_sockpath if (-e $g_sigcheck_sockpath);

	my $args = "-k $g_prefix_key/$g_dev_cert".
		" -K $g_prefix_key/$g_ctrl_cert".
		" -l $g_prefix_key/$g_dev_crl".
		" -L $g_prefix_key/$g_ctrl_crl".
		" -t $g_prefix_key/$g_dev_trusted_ca".
		" -T $g_prefix_key/$g_ctrl_trusted_ca".
		" -S $g_sigcheck_sockpath";

	$args .= " -d" if ($checkdate);

	# We do not chroot the checker daemon in the case of rm
	# core installs, because of missing CAP_SYS_CHROOT privileges.
	$args .= " -c"
		unless (($g_pkg_opts->{'Distribution'} eq "rm")
			and ($g_pkg_opts->{'Priority'} eq "Required"));
	
	open PIPE, "check-daemon $args 2>&1|";
	my @output = <PIPE>;
	close PIPE;
	if ($?) {
		clip_warn "Failed to start signature checker";
		foreach (@output) {
			clip_warn "signature checker output output: $_";
		}
		return 0;
	} else {
		clip_debug "Signature checker started";
	}

	my $i;
	for ($i = 0; $i < 10; $i++) {
		return 1 if (-e $g_sigcheck_sockpath);
		sleep 1;
	}
	clip_warn "Time-out waiting for signature checker";
	return 0;
}

=item B<clippkg_sigcheck_stop()>

Stop the check-daemon once package signatures have been checked
Returns 1 if daemon stopped OK, 0 otherwise.

=cut

sub clippkg_sigcheck_stop() {
	my $ret = 0;
	unless (-e $g_sigcheck_sockpath) {
		clip_warn "Signature checker socket could not be "
				."found at $g_sigcheck_sockpath";
		return 0;
	}

	open PIPE, "check-client -S $g_sigcheck_sockpath -q 2>&1|";
	my @output = <PIPE>;
	close PIPE;
	if ($?) {
		clip_warn "Failed to stop signature checker";
		foreach (@output) {
			clip_warn "signature checker output output: $_";
		}
	} else {
		clip_debug "Signature checker stopped";
		$ret = 1;
	}

	unlink $g_sigcheck_sockpath 
		or clip_warn "Failed to unlink socket at $g_sigcheck_sockpath";
	return $ret;
}

=item B<clippkg_check_pkg($pkg, $conf_p)>

Performs  full checks on package $pkg, by first checking its signatures, then 
its $g_fields fields against the values defined in $g_pkg_opts, then finally, 
and only in the case of a configuration package (which is indicated by $conf_p 
being non-null), checking its Release-Date against the age constraints defined 
in $g_conf_opts, $g_conf_max_ages and $g_conf_min_ages.
Returns 1 if $pkg passes all checks, and 0 otherwise.

=cut

sub clippkg_check_pkg($$) {
	my ($pkg, $conf_p) = @_;
	return clippkg_check_pkg_msg($pkg, $conf_p, "");
}
=back

=cut

                       #############################
		       #      Optionnal checks     #
		       #############################

=head2 Optionnal checks

=over 4

=item B<clippkg_check_optional($pkg, $hash)>

Checks that package $pkg (full name) is an allowed optional package
based on the pkgname->pkgver hash referenced by $hash. This hash is
typically returned by clippkg_list_allowed_optional() or
clippkg_list_mirror_optional().

Returns 1 if allowed, 0 otherwise.

=cut

sub clippkg_check_optional($$) {
	my ($pkg,$hash) = @_;

	my $pname;
	my $pver;
	
	if ($pkg =~ /^([^_]+)_([^_]+)_(\S+)/) {
			$pname = $1;
			$pver = $2;
	} else {
		clip_warn "Package name format not recognized: $pkg";
		return 0;
	}

	my $allowed;
	unless (defined($allowed = $hash->{$pname})) {
		clip_warn "Package $pname is not an allowed optional package";
		return 0;
	}

	if ($allowed ne $pver) {
		clip_warn "Optionnal package $pname is not allowed in version "
				."$pver (version $allowed is allowed)";
		return 0;
	}

	return 1;
}

                       ##############################
		       #      Upgrade / updates     #
		       ##############################

=head2 Upgrades and updates

=over 4

=item B<clippkg_update_db($retry)>

Updates  the apt database, by running C<apt-get update>. The apt configuration
options must have been properly set up before the call, for example through
the definition of the C<$APT_CONFIG> path.
If $retry is != 0, the function will try $retry times to fix any errors it 
encounters by calling clippkg_apt_error().
Returns 1 on success, 0 on failure.

=cut

sub clippkg_update_db($) {
	my $retry = shift;
	my $toget = 2; # Run without retry by clip_download - we need
	               # to hit at least 2 mirrors (one of which is local)

RETRY:
	open PIPE, "apt-get update 2>&1|";
	my @output = <PIPE>;
	close PIPE;
	if ($?) {
		unless ($retry) {
			foreach (@output) {
				# We only consider the update successful if
				# at least two mirrors have been hit: 
				#  - there should be at least a core and apps
				#  mirrors
				#  - this means a RM download which only hits
				#  the other RM jail's mirror won't be
				#  considered successful.
				# DB updates during the install phase only look
				# at a single mirror, but should never return
				# an error code anyway.
				if (/^Get:$toget/ or /^Hit/) {
					clip_warn "Some index files failed to "
						."download, continuing with "
						."what we've got";
					return 1;
				}
			}
		}
		clip_warn "apt-get update failed";
		foreach (@output) {
			clip_warn "apt output: $_";
		}
		return 0 unless ($retry);

		# Retry 
		clippkg_apt_error(\@output);
		# On second try, we consider hitting even just one 
		# mirror a success (when run through clip_install)
		$toget = 1;
		$retry--;
		goto RETRY;
	}
	return 1;
}

=item B<clippkg_is_conf($pname)>

Return 1 if the package name match the configuration template. 0 otherwise.

=cut

sub clippkg_is_conf($) {
	my $pname = shift;
	return $pname =~ /-conf(?:-[bh])?(?:_\d.*.deb)?$/;
}

=item B<clippkg_get_confs($mirpath)>

Return configuration packages in the specified mirror path.

=cut

sub clippkg_get_confs($) {
	my $mirpath = shift;
	return <$mirpath/*-conf{,-[bh]}_*.deb>;
}

=item B<clippkg_get_confname($dist, $type, $jail)>

Return the configuration package for the specified dist (and jail if defined).

=cut

sub clippkg_get_confname($$$) {
	my ($dist, $type, $jail) = @_;
	my @rjail = ();

	if ($dist eq "clip") {
		return "clip-$type-conf";
	} elsif ( $dist eq "rm") {
		if (not defined($jail)) {
			if (open IN, "<", "/etc/shared/jail_name") {
				@rjail = <IN>;
				close IN;
			} else {
				clip_warn "failed to open jail_name";
				return undef;
			}
			$jail = $rjail[0];
		}
		if (grep { /^rm_h$/ } $jail) {
			return "rm-$type-conf-h" if ($g_with_rm_apps_specific);
			return "rm-$type-conf";
		} elsif (grep { /^rm_b$/ } $jail) {
			return "rm-$type-conf-b" if ($g_with_rm_apps_specific);
			return "rm-$type-conf";
		} else {
			clip_warn "unknown jail: $jail";
		}
	} else {
		clip_warn "unknown dist: $dist";
	}
	return undef;
}

=item B<clippkg_list_installed_confs()>

Returns a reference to a list of configurations installed in the current 
distribution.  The list contains the short package names for each of those 
configs (no version / arch).

=cut

sub clippkg_list_installed_confs() {
	my @list = ();

	open PIPE, "dpkg --admindir=$g_dpkg_admin_dir -l 2>&1 |";
	my @output = <PIPE>;
	close PIPE;
	if ($?) {
		clip_warn "failed to list installed packages";
		foreach (@output) {
			clip_warn "dpkg -l output: $_";
		}
		return undef;
	}

	foreach (@output) {
		if (/^ii\s+(\S+)/) {
			my $pname = $1;

			push @list, ($pname) if (clippkg_is_conf($pname));
		}
	}

	return \@list;
}

=item B<clippkg_list_optional()>

List optional packages to be installed on this system, based on the content of
the files whose path are referenced in the argument (reference to a list of file
paths). All files in the list it references are read into a list 
of packages, which is filtered for non-supported characters : only alphanumerics, 
'_', '-', '.' and whitespace characters are allowed in that file. Note that a 
non-supported character in a file prevents all package names from that file from
being included in the list of optional package names, but does not prevent those
from another file referenced in the arguments from being included.

Returns a reference to a (possibly empty) list of optional package short names on 
success, or a C<undef> on error.

=cut
sub clippkg_list_optional($) {
	my $flist = shift;
	my @opt = ();
	return \@opt if (not (@{$flist}));

FLOOP:
	foreach my $file (@{$flist}) {
		my @read = ();
		if (open IN, "<", "$file") {
			@read = <IN>;
			close IN;
		} else {
			clip_warn "failed to open optional file $file";
			next FLOOP;
		}

		if (grep { /[^-\.\w\s]/ } @read) {
			clip_warn "unsupported characters in optional file "
				."$file, dropping it";
			next FLOOP;
		}
		push @opt, (map {chomp $_; $_} @read);
	}

	return \@opt;
}


=item B<CLIP::Pkg::Base::parse_deps($deps)>

Internal use only. Parse a dependency string (comma-separated list of 
dependencies, debian-style, as a string) $deps into a hash matching package 
names to a reference to a list of [ <rel>, <ver> ] pairs (themselves as 
references to lists), where <ver> is a version and <rel> is the required 
relation (">>", ">=", "=", etc.). 

Returns a reference to a hash on success, undef on failure.

=cut

sub parse_deps($) {
	my $deps = shift;

	chomp $deps;
	my @fdeps = split ", ", $deps;
	my %hash = ();

DEPLOOP:
	foreach my $dep (@fdeps) {
		if ($dep =~ /(\S+) \(([><=]{1,2}) (\S+)\)/) {
			my $pname = $1;
			my $prel = $2;
			my $pver = $3;
			if (defined ($hash{$pname})) {
				# We don't try to detect conflicting 
				# requirements here, they should be
				# found in check_deps() anyway.
				push @{$hash{$pname}}, ([ $prel, $pver ]);
			} else {
				$hash{$pname} = [[ $prel, $pver ]];
			}
		} else {
			clip_warn "cannot extract unique version from "
				."dependency: $dep";
			return 0;
		}
	}

	return \%hash;
}

=itemB<CLIP::Pkg::Base::check_dep($pfor, $pname, $ver, $dep)>

Internal use only. Check that a given dependency condition $dep 
(expressed as a [ $rel, $ver ] list reference, as returned in the
parse_deps() hash) is satisfied by version $ver of package $pname.
$pfor is the name of the package on account of which the dependency
is checked. $pfor and $pname are passed for logging purposes only.

Returns 1 if the dependency is satisfied, 0 otherwise.

=cut

sub check_dep($$$$) {
	my ($pfor, $pname, $ver, $dep) = @_;
	my ($prel, $pver) = @{$dep};

	my $cmp = versioncmp($ver, $pver);
	
	if ($prel eq ">>") { return 1 if ($cmp > 0); }
	elsif ($prel eq ">=") { return 1 if ($cmp >= 0); }
	elsif ($prel eq "=") { return 1 if ($cmp == 0); }
	elsif ($prel eq "<=") { return 1 if ($cmp <= 0); }
	elsif ($prel eq "<<") { return 1 if ($cmp < 0); }

	clip_warn "Package $pfor depends on $pname with version $prel $pver, "
			."version $ver is installed";
	return 0;
}

=item B<CLIP::Pkg::Base::check_deps($pkg, $deps)>

Internal use only. Check that all the dependencies passed as $deps 
(comma-separated list of debian dependencies, as a string) are satisfied by 
packages currently installed in the system. The $pkg param is the name of the 
package for which these dependencies are checked. It is provided for logging 
purposes only.

Returns 1 if all dependencies are satisfied, 0 otherwise.

=cut

sub check_deps($$) {
	my ($pkg, $cdeps) = @_;

	my $hash;

	unless (defined($hash = parse_deps($cdeps))) {
		clip_warn "failed to parse confdep : $cdeps";
		return 0;
	}

	DEPS:
	foreach my $pname (keys %{$hash}) {
		my $fver;
		unless (defined($fver = 
			clippkg_get_installed_fields($pname, "Version", 0))) {
				clip_warn "Package $pkg depends on $pname, "
					." which is not installed";
				return 0;
		}
		my $cver = $fver->{'Version'};

		foreach my $dep (@{$hash->{$pname}}) {
			return 0 unless check_dep($pkg, $pname, $cver, $dep);
		}
	}

	return 1;
}

=item B<CLIP::Pkg::Base::list_upgrade_candidates($cdep_p, $opt_p)>

Internal use only. Lists upgrade candidates among configurations only, or
configurations and optional packages, depending on the value of $opt_p, for 
the current value of $g_pkg_opts (i.e. current distribution and type of 
packages).

This is done by checking the cached fields of all locally installed 
configurations, and all optional packages if requested, and keeping only those 
that match. This does not imply that upgrades are available for those packages.

If the $opt_p parameter is passed as 1, both configurations and optional packages
are listed. If it is passed as 0, only configurations are listed.

If the $cdep_p parameter is passed as 1, the "ConfDepends:" dependencies of 
each upgrade candidate are also automatically checked before adding them to 
the returned candidates list.  Otherwise, no such check is performed.

Returns a string listing candidate package names (short names), or 
C<undef> in case of error.

=cut

sub list_upgrade_candidates($$) {
	my ($cdep_p, $opt_p) = @_;
	my $clist;
	my $plist;

	return undef
		unless (defined($clist = clippkg_list_installed_confs()));

	if ($opt_p) {
		return undef unless (defined($plist = 
			clippkg_list_optional($g_optional_pkg_files)));
	} else {
		$plist = [];
	}

	my $hash;
	my $ret = "";
	foreach my $list ($clist, $plist) {
PKGLOOP:
		foreach my $pkg (@{$list}) {
			if ($pkg =~ /^$/) {
				next;
			}
			next PKGLOOP 
				unless (defined($hash = 
					clippkg_cache_get_fields($pkg)));
			next PKGLOOP
				unless (clippkg_check_fields($hash, $pkg));
			if ($cdep_p) {
				my $cdeps;
				if (defined ($cdeps = $hash->{"ConfDepends"})) {
					next PKGLOOP unless 
						(check_deps($pkg, $cdeps));
				}
			}
			$ret .= "$pkg ";
		}
	}
	
	return $ret;
}

=item B<clippkg_list_upgrade_candidates($cdep_p)>

Lists upgrade candidates among configurations and optional packages for 
the current value of $g_pkg_opts (i.e. current distribution and type of 
packages).

If the $cdep_p parameter is passed as 1, the "ConfDepends:" dependencies of 
each upgrade candidate are also automatically checked before adding them to 
the returned candidates list.  Otherwise, no such check is performed.

Returns a string listing candidate package names (short names), or 
C<undef> in case of error.

=cut

sub clippkg_list_upgrade_candidates($) {
	my $cdep_p = shift;
	
	return list_upgrade_candidates($cdep_p, 1);
}

=item B<clippkg_list_upgrade_configurations($cdep_p)>

Lists upgrade candidates among configurations only (i.e. not optional packages)
for the current value of $g_pkg_opts (i.e. current distribution and type of 
packages).

If the $cdep_p parameter is passed as 1, the "ConfDepends:" dependencies of 
each upgrade candidate are also automatically checked before adding them to 
the returned candidates list.  Otherwise, no such check is performed.

Returns a string listing candidate package names (short names), or 
C<undef> in case of error.

=cut

sub clippkg_list_upgrade_configurations($) {
	my $cdep_p = shift;
	
	return list_upgrade_candidates($cdep_p, 0);
}

=item B<clippkg_list_mirror_optional($clist, $mirpath, $path)>

Lists allowed optional packages for the current distribution, based on the 
configurations currently available in the local mirrors, and on those being 
downloaded. This is appropriate when generating a list of allowed optional 
packages for the purpose of downloading those packages.

Building the allowed list of packages is based on the "Depends:" and "Suggests:" 
fields of all configurations available in the local mirror at $mirpath, or of 
those of a list of freshly downloaded configurations passed as reference $clist
(list of full package name, with version and arch).  Configurations in $clist 
override installed configurations with the same name. The packages 
corresponding to those downloaded configurations can be found in directory 
$path.

The list of allowed optional packages is returned as a reference to a hash 
keyed by allowed package names, with values corresponding to the allowed 
versions. undef is returned in case of error. Note that this hash also 
contains the names and versions of those configurations used to build it.


=cut

sub clippkg_list_mirror_optional($$$) {
	my ($clist, $mirpath, $path) = @_;
	my %hash;

	my $cname;
	my $cver;

	my @confs = clippkg_get_confs($mirpath);

INMIRROR:
	foreach my $cpath (map {basename $_ } @confs) {
		if ($cpath =~ /([^_\/]+)_([^_]+)/) {
			$cname = $1;
			$cver = $2;
		} else {
			clip_warn "unsupported package path: $cpath";
			return undef;
		}
		my $tmp = "$cname"."_";
		# in mirror version overriden by freshly downloaded one
		next INMIRROR if (grep { /^$tmp/ } @{$clist}); 
		
		unless (clippkg_get_dephash("$mirpath/$cpath", 0, \%hash)) {
			clip_warn "failed to get dependencies for new "
					."configuration $cpath";
			return undef;
		}
		unless (clippkg_get_dephash("$mirpath/$cpath", 1, \%hash)) {
			clip_warn "failed to get optional packages for new "
					."configuration $cpath";
			return undef;
		}
		# Add configuration itself.
		$hash{$cname} = $cver;
	}

DOWNLOADED:
	foreach my $cpath (@{$clist}) {
		if ($cpath =~ /([^_\/]+)_([^_]+)/) {
			$cname = $1;
			$cver = $2;
		} else {
			clip_warn "unsupported package path: $cpath";
			return undef;
		}
		unless (clippkg_get_dephash("$path/$cpath", 0, \%hash)) {
			clip_warn "failed to get dependencies for new "
					."configuration $cpath";
			return undef;
		}
		unless (clippkg_get_dephash("$path/$cpath", 1, \%hash)) {
			clip_warn "failed to get optional packages for new "
					."configuration $cpath";
			return undef;
		}
		# Add configuration itself.
		$hash{$cname} = $cver;
	}

	return \%hash;
}

=item B<clippkg_list_allowed_optional($clist, $path)>

Lists allowed optional packages for the current distribution, based on the 
configurations currently installed in the system, and on those being 
downloaded or installed. This is appropriate when generating a list of allowed 
optional packages for the purpose of installing those packages.

Building the allowed list of packages is based on the "Depends:" and "Suggests:" 
fields of all configurations currently installed in the system for the current
distribution, or of those of a list of freshly downloaded configurations passed 
as reference $clist (list of full package name, with version and arch).  
Configurations in $clist override installed configurations with the same name. 
The packages corresponding to those downloaded configurations can be found in 
directory $path.

The list of allowed optional packages is returned as a reference to a hash 
keyed by allowed package names, with values corresponding to the allowed 
versions. undef is returned in case of error. Note that this hash also 
contains the names and versions of those configurations used to build it.

=cut

sub clippkg_list_allowed_optional($$) {
	my ($clist,$path) = @_;
	my $ilist;

	return undef unless (defined($ilist = clippkg_list_installed_confs()));

	my %hash;

INSTALLED:
	foreach my $cname (@{$ilist}) {
		my $tmp = "$cname"."_";
		# installed version overriden by freshly downloaded one
		next INSTALLED if (grep { /^$tmp/ } @{$clist}); 

		my $cver;
		unless (defined($cver = 
			clippkg_get_installed_fields($cname, "Version", 1))) {
				clip_warn "failed to get installed version "
					."for $cname";
				return undef;
		}
		unless (clippkg_get_dephash($cname, 0, \%hash)) {
			clip_warn "failed to get dependencies for installed "
					."configuration $cname";
			return undef;
		}
		unless (clippkg_get_dephash($cname, 1, \%hash)) {
			clip_warn "failed to get optional packages for "
					."installed configuration $cname";
			return undef;
		}
		# Add configuration itself.
		$hash{$cname} = $cver->{"Version"};
	}

DOWNLOADED:
	foreach my $cpath (@{$clist}) {
		my $cname;
		my $cver;
		if ($cpath =~ /([^_\/]+)_([^_]+)/) {
			$cname = $1;
			$cver = $2;
		} else {
			clip_warn "unsupported package path: $cpath";
			return undef;
		}
		unless (clippkg_get_dephash("$path/$cpath", 0, \%hash)) {
			clip_warn "failed to get dependencies for new "
					."configuration $cpath";
			return undef;
		}
		unless (clippkg_get_dephash("$path/$cpath", 1, \%hash)) {
			clip_warn "failed to get optional packages for new "
					."configuration $cpath";
			return undef;
		}
		# Add configuration itself.
		$hash{$cname} = $cver;
	}

	return \%hash;
}

=item B<clippkg_prune($path)>

Prunes  unneeded packages from the directory under $path. The algorithm
used for pruning is as follows: 

=over 8

=item 1.

Get a list of all the configurations among the packages in $path.

=item 2. 

Remove duplicates in that list, keeping only the latest configurations.

=item 3.

Get a list of the combined dependencies for the remaining configurations

=item 4.

For each non-configuration package in $path, remove it if it isn't referenced
in the combined dependencies.

=back

Returns 1 on success, 0 on error.

=cut

sub clippkg_prune($) {
	my $path = shift;

	unless (chdir $path) {
		clip_warn "failed to enter directory: $path";
		return 0;
	}

	my @all; # all pkgs + confs
	my @confs; # all confs
	my @pkgs; # all pkgs;

	@all = <*.deb>;

	if ($#all < 0) {
		clip_warn "no packages in $path ?";
		return 1; # no error here, just weird
	}

	foreach my $pkg (@all) {
		if (clippkg_is_conf($pkg)) {
			push @confs, ($pkg);
		} else {
			push @pkgs, ($pkg);
		}
	}

	my @remove; # pkgs and confs to remove
	my @keep; # confs to keep

	# Remove duplicate confs
	clippkg_get_duplicates(\@confs, \@remove, \@keep);


	my $reflist; 
	# Get dependencies of latest confs
	unless (defined ($reflist = clippkg_get_deplist(\@keep, "", 2))) {
		clip_warn "failed to get dependencies of all confs";
		return 0;
	}

	# Then remove packages that are no longer referenced
	foreach my $pkg (@pkgs) {
		unless (defined ($reflist->{$pkg})) {
			push @remove, ($pkg);
		}
	}

	# Finally, perform the actual removal of confs and packages
	foreach my $pkg (@remove) {
		clip_debug "removing $pkg from $path";
		unlink $pkg 
			or clip_warn "failed to remove $pkg";
	}

	return 1;
}

                       #########################
		       #      Error recovery   #
		       #########################

=back

=head2 Error recovery

=over 4

=item B<CLIP::Pkg::Base::$g_dpkg_reinst_cache>

Internal use. Path to the cache directory where (in the 'archives/' 
subdirectory) packages can be found for reinstallation attempts.

=cut

our $g_dpkg_reinst_cache = "";

=item B<CLIP::Pkg::Base::dpkg_configure($pkg)>

Internal use only. Attempt to reconfigure package $pkg (short package name).

Returns 1 on success, 0 on failure.

=cut

sub dpkg_configure($) {
	my $pname = shift;

	clip_log "attempting to reconfigure $pname";

	open PIPE, "dpkg --force-depends --force-overwrite --force-conflicts "
		."--admindir=$g_dpkg_admin_dir --configure $pname 2>&1|";
	my @output = <PIPE>;
	close PIPE;
	if ($?) {
		clip_warn "dpkg --configure $pname failed";
		foreach (@output) {
			clip_warn "dpkg output: $_";
		}
		return 0
	} else {
		clip_log "[$pname] has been reconfigured";
		return 1;
	}
}

=item B<CLIP::Pkg::Base::dpkg_configure($pkg)>

Internal use only. Attempt to reinstall package $pkg (full package name, with 
version and arch) from the $g_dpkg_reinst_cache directory. The package to 
reinstall, if found, is first checked.

Returns 1 on success, 0 on failure.

=cut

sub dpkg_reinst($) {
	my $pkg = shift;

	clip_log "attempting to reinstall $pkg from cache";

	my $ppath = "$g_dpkg_reinst_cache/archives/$pkg";

	unless (-f "$ppath") {
		clip_warn "cannot find $pkg in cache, aborting reinstall";
		return 0;
	}

	unless (clippkg_check_pkg($ppath, 0)) {
		clip_warn "aborting reinstall of $pkg: cached version "
				."failed check";
		return 0;
	}

	open PIPE, "dpkg --force-depends --force-overwrite --force-conflicts "
			."--admindir=$g_dpkg_admin_dir -i $ppath 2>&1|";
	my @output = <PIPE>;
	close PIPE;
	if ($?) {
		clip_warn "dpkg -i $ppath failed";
		foreach (@output) {
			clip_warn "dpkg output: $_";
		}
		return 0
	} else {
		clip_log "[$pkg] has been reinstalled from cache";
		return 1;
	}
}

=item B<CLIP::Pkg::Base::dpkg_fix_status()>

Internal use only. Try to fix the dpkg status by parsing the output of 
dpkg -l, then reinstalling or reconfiguring those packages that need it.

Returns 1 on success (at least one package was successfully reinstalled or 
reconfigured), 0 on failure.

=cut

sub dpkg_fix_status() {
	my %todo = ();
	my $arch;

	unless ($g_dpkg_reinst_cache) {
		clip_warn "dpkg status cannot be fixed without a "
			."reinstall cache";
		return 0;
	}

	return 0 unless (defined($arch = clippkg_get_arch()));

	open PIPE, "dpkg --admindir=$g_dpkg_admin_dir -l 2>&1|";
	my @output = <PIPE>;
	close PIPE;
	if ($?) {
		clip_warn "dpkg -l failed";
		foreach (@output) {
			clip_warn "dpkg output: $_";
		}
		return 0;
	}

	# Snip first five lines : dpkg -l header
LOOP:
	foreach my $line (@output[5 ... $#output]) {
		next LOOP unless ($line =~ /^\S*[A-Z]/);
		my ($stat, $name, $ver);
		if ($line =~ /^\S*([A-Z])\S*\s+(\S+)\s+(\S+)/) {
			$stat = $1;
			$name = $2;
			$ver = $3;
			# Not checking for duplicates, should not happen
			if ($stat eq "F") {
				$todo{$name} = "conf";
			} elsif ($stat eq "R" or $stat eq "H" or $stat eq "U") {
				$todo{$name."_".$ver."_".$arch.".deb"} = "inst";
			} else {
				clip_warn "unrecognized status letter: $stat";
				next LOOP;
			}
		} else {
			chomp $line;
			clip_warn "unrecognized status line: $line";
			next LOOP;
		}
	}

	my $ret = 0;
	foreach my $pkg (keys %todo) {
		if ($todo{$pkg} eq "inst") {
			$ret = 1 if dpkg_reinst($pkg);
		} elsif ($todo{$pkg} eq "conf") {
			$ret = 1 if dpkg_configure($pkg);
		}
	}	
	return $ret;
}

=item B<clippkg_apt_error($ref)>

Try to handle an apt / dpkg error to restore a workable apt system.
The actions taken depend on the error output passed as $ref (reference
to a list of lines of output from apt).

=cut
sub clippkg_apt_error($) {
	my $lref = shift;
	my $ret = 0;
	my $configure = 0; # Do we need dpkg --configure ?

	foreach my $line (@{$lref}) {
		$configure = 1 if $line =~ /dpkg --configure/;
	}

	if ($configure) {
		clip_warn "Apt error recovery - trying to run dpkg "
			."--configure -a";
		open PIPE, "dpkg --force-depends --force-overwrite "
			."--force-conflicts --admindir=$g_dpkg_admin_dir "
			."--configure -a 2>&1|";
		my @output = <PIPE>;
		close PIPE;
		if ($?) {
			clip_warn "dpkg --configure -a failed";
			foreach (@output) {
				clip_warn "dpkg output: $_";
			}
		} else {
			# Not sure we fixed everything, but a least we
			# did something.
			$ret = 1;
		}
	} else {
		clip_warn "Apt error recovery - trying generic "
			."status-based fix";
		$ret = 1 if (dpkg_fix_status());
	}
	
	return $ret;
}


                       #########################
		       #      File locking     #
		       #########################

=back

=head2 File locking

=over 4

=item B<clippkg_lock($file)>

Takes  an exclusive lock on file $file (which is created as needed).
The lock taking action is blocking by default, unless $g_lock_nonblock
is set to something non-zero, in which case a failure to take the 
lock immediately causes a direct error return.
Returns the anonymous file handle for the locked $file in case of 
success, and C<undef> on error.

=cut

sub clippkg_lock($) {
	my $file = shift;

	my $cmd = 2; # LOCK_EX

	my $fh; # anonymous file handle

	if ($g_lock_nonblock) {
		$cmd = $cmd + 4; # LOCK_NB
	}

	# Note: small race condition window remains
	# if lockfile must be created - this only happens once, at most...
	unless (open $fh, ">", "$file") {
		clip_warn "failed to open $file for locking";
		return undef;
	}

	unless (flock $fh, $cmd) {
		clip_warn "failed to lock $file";
		return undef;
	}
	
	return $fh;
}

=item B<clippkg_unlock($handle, $file)>

Releases  an exclusive lock on the file handle $handle, which corresponds
to the file path $file.
Never returns an error.

=cut

sub clippkg_unlock($$) {
	my ($fh, $file) = @_;

	# No error here...

	# 8 <-> LOCK_UN 
	unless (flock $fh, 8) {
		clip_warn "failed to unlock $file";
	}

	unless (close $fh) {
		clip_warn "failed to close $file";
	}
}
	

1;
__END__

=back

=head1 SEE ALSO

CLIP::Pkg::Download(3), CLIP::Pkg::Install(3), CLIP::Logger(3), dpkg(1)

=head1 AUTHOR

Vincent Strubel, E<lt>clip@ssi.gouv.frE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2008-2009 SGDN/DCSSI
Copyright (C) 2010-2012 SGDSN/ANSSI

All rights reserved.

=cut
