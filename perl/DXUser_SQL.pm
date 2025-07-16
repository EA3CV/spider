package DXUser_SQL;

use strict;
use warnings;
use DBI;
use JSON;
use Scalar::Util qw(blessed);
use DXVars;
use DXChannel;
use Encode;
use File::Copy qw(copy move);

my $dbh;
my $json = JSON->new->canonical(1);
my $table = 'users';

# Field list
my @FIELDS = qw(
	call sort addr alias annok autoftx bbs bbsaddr believe buddies build clientoutput clientinput connlist
	dxok email ftx group hmsgno homenode isolate K lang lastin lastoper lastping lastseen lat lockout long
	maxconnect name node nopings nothere pagelth passphrase passwd pingint priv prompt qra qth rbnseeme
	registered startt user_interval version wantann wantann_talk wantbeacon wantbeep wantcw wantdx
	wantdxcq wantdxitu wantecho wantemail wantft wantgtk wantlogininfo wantpc16 wantpc9x wantpsk
	wantrbn wantroutepc19 wantrtty wantsendpc16 wanttalk wantusstate wantwcy wantwwv wantwx width xpert
	wantgrid
);

sub init {
	my ($mode) = @_;

	my ($dsn, $user, $pass);

	if ($main::db_backend eq 'sqlite') {
		$dsn  = $main::sqlite_dsn;
		$user = $main::sqlite_dbuser;
		$pass = $main::sqlite_dbpass;

		my ($db_path) = $dsn =~ /dbname=([^;]+)/;
		my $db_missing = !-e $db_path;

		$dbh = DBI->connect($dsn, $user, $pass, {
			RaiseError     => 1,
			AutoCommit     => 1,
			sqlite_unicode => 1,
		}) or die "SQLite connect error: $DBI::errstr";

		my $needs_init = $db_missing || !_table_exists('users');
		if ($needs_init) {
			print "[DXUser_SQL] Creating SQLite table: $table...\n";
			_create_table_if_needed();
			_import_from_v3j();
		}

	} else {
		my $mysql_db = $main::mysql_db;
		$dsn = "DBI:mysql:host=$main::mysql_host";
		$user = $main::mysql_user;
		$pass = $main::mysql_pass;

		my $dbh_tmp = DBI->connect($dsn, $user, $pass, {
			RaiseError => 1,
			AutoCommit => 1
		}) or die "MySQL connect error: $DBI::errstr";

		my $db_exists = $dbh_tmp->selectrow_array("SHOW DATABASES LIKE ?", undef, $mysql_db);

		unless ($db_exists) {
			print "[DXUser_SQL] Creating MySQL database $mysql_db...\n";
			$dbh_tmp->do("CREATE DATABASE `$mysql_db` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci");
		}

		$dbh_tmp->disconnect;

		$dsn = "DBI:mysql:database=$mysql_db;host=$main::mysql_host";
		$dbh = DBI->connect($dsn, $user, $pass, {
			RaiseError           => 1,
			AutoCommit           => 1,
			mysql_enable_utf8mb4 => 1,
		}) or die "MySQL connect error: $DBI::errstr";

		my $table_exists = $dbh->selectrow_array("SHOW TABLES LIKE '$table'");
		unless ($table_exists) {
			print "[DXUser_SQL] Creating MySQL $table\n";
			_create_table_if_needed();
			_import_from_v3j();
		}
	}

	return bless {}, __PACKAGE__;
}

sub _create_table_if_needed {
	my $sql;

	if ($main::db_backend eq 'mysql') {
		$sql = qq{
CREATE TABLE IF NOT EXISTS `$table` (
  `call` VARCHAR(64) NOT NULL,
  `sort` VARCHAR(255) DEFAULT NULL,
  `addr` VARCHAR(255) DEFAULT NULL,
  `alias` VARCHAR(255) DEFAULT NULL,
  `annok` BOOLEAN DEFAULT 0,
  `autoftx` BOOLEAN DEFAULT 0,
  `bbs` VARCHAR(255) DEFAULT NULL,
  `bbsaddr` VARCHAR(255) DEFAULT NULL,
  `believe` TEXT DEFAULT NULL,
  `buddies` TEXT DEFAULT NULL,
  `build` VARCHAR(255) DEFAULT NULL,
  `clientoutput` TEXT DEFAULT NULL,
  `clientinput` TEXT DEFAULT NULL,
  `connlist` TEXT DEFAULT NULL,
  `dxok` BOOLEAN DEFAULT 0,
  `email` TEXT DEFAULT NULL,
  `ftx` BOOLEAN DEFAULT 0,
  `group` VARCHAR(255) DEFAULT NULL,
  `hmsgno` INT DEFAULT NULL,
  `homenode` VARCHAR(255) DEFAULT NULL,
  `isolate` BOOLEAN DEFAULT 0,
  `K` BOOLEAN DEFAULT 0,
  `lang` VARCHAR(255) DEFAULT NULL,
  `lastin` BIGINT DEFAULT NULL,
  `lastoper` BIGINT DEFAULT NULL,
  `lastping` TEXT DEFAULT NULL,
  `lastseen` BIGINT DEFAULT NULL,
  `lat` VARCHAR(255) DEFAULT NULL,
  `lockout` BOOLEAN DEFAULT 0,
  `long` VARCHAR(255) DEFAULT NULL,
  `maxconnect` INT DEFAULT NULL,
  `name` VARCHAR(255) DEFAULT NULL,
  `node` VARCHAR(255) DEFAULT NULL,
  `nopings` INT DEFAULT NULL,
  `nothere` TEXT DEFAULT NULL,
  `pagelth` INT DEFAULT NULL,
  `passphrase` VARCHAR(255) DEFAULT NULL,
  `passwd` VARCHAR(255) DEFAULT NULL,
  `pingint` INT DEFAULT NULL,
  `priv` BOOLEAN DEFAULT 0,
  `prompt` VARCHAR(255) DEFAULT NULL,
  `qra` VARCHAR(255) DEFAULT NULL,
  `qth` TEXT DEFAULT NULL,
  `rbnseeme` BOOLEAN DEFAULT 0,
  `registered` BOOLEAN DEFAULT 0,
  `startt` VARCHAR(255) DEFAULT NULL,
  `user_interval` INT DEFAULT NULL,
  `version` VARCHAR(255) DEFAULT NULL,
  `wantann` BOOLEAN DEFAULT 0,
  `wantann_talk` BOOLEAN DEFAULT 0,
  `wantbeacon` BOOLEAN DEFAULT 0,
  `wantbeep` BOOLEAN DEFAULT 0,
  `wantcw` BOOLEAN DEFAULT 0,
  `wantdx` BOOLEAN DEFAULT 0,
  `wantdxcq` BOOLEAN DEFAULT 0,
  `wantdxitu` BOOLEAN DEFAULT 0,
  `wantecho` BOOLEAN DEFAULT 0,
  `wantemail` BOOLEAN DEFAULT 0,
  `wantft` BOOLEAN DEFAULT 0,
  `wantgtk` BOOLEAN DEFAULT 0,
  `wantlogininfo` BOOLEAN DEFAULT 0,
  `wantpc16` BOOLEAN DEFAULT 0,
  `wantpc9x` BOOLEAN DEFAULT 0,
  `wantpsk` BOOLEAN DEFAULT 0,
  `wantrbn` BOOLEAN DEFAULT 0,
  `wantroutepc19` BOOLEAN DEFAULT 0,
  `wantrtty` BOOLEAN DEFAULT 0,
  `wantsendpc16` BOOLEAN DEFAULT 0,
  `wanttalk` BOOLEAN DEFAULT 0,
  `wantusstate` BOOLEAN DEFAULT 0,
  `wantwcy` BOOLEAN DEFAULT 0,
  `wantwwv` BOOLEAN DEFAULT 0,
  `wantwx` BOOLEAN DEFAULT 0,
  `width` INT DEFAULT NULL,
  `xpert` BOOLEAN DEFAULT 0,
  `wantgrid` BOOLEAN DEFAULT 0,
  PRIMARY KEY (`call`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
		};
	} else {
		# SQLite version
		$sql = qq{
CREATE TABLE IF NOT EXISTS `$table` (
  `call` TEXT PRIMARY KEY,
  `sort` TEXT,
  `addr` TEXT,
  `alias` TEXT,
  `annok` INTEGER DEFAULT 0,
  `autoftx` INTEGER DEFAULT 0,
  `bbs` TEXT,
  `bbsaddr` TEXT,
  `believe` TEXT,
  `buddies` TEXT,
  `build` TEXT,
  `clientoutput` TEXT,
  `clientinput` TEXT,
  `connlist` TEXT,
  `dxok` INTEGER DEFAULT 0,
  `email` TEXT,
  `ftx` INTEGER DEFAULT 0,
  `group` TEXT,
  `hmsgno` INTEGER,
  `homenode` TEXT,
  `isolate` INTEGER DEFAULT 0,
  `K` INTEGER DEFAULT 0,
  `lang` TEXT,
  `lastin` INTEGER,
  `lastoper` INTEGER,
  `lastping` TEXT,
  `lastseen` INTEGER,
  `lat` TEXT,
  `lockout` INTEGER DEFAULT 0,
  `long` TEXT,
  `maxconnect` INTEGER,
  `name` TEXT,
  `node` TEXT,
  `nopings` INTEGER,
  `nothere` TEXT,
  `pagelth` INTEGER,
  `passphrase` TEXT,
  `passwd` TEXT,
  `pingint` INTEGER,
  `priv` INTEGER DEFAULT 0,
  `prompt` TEXT,
  `qra` TEXT,
  `qth` TEXT,
  `rbnseeme` INTEGER DEFAULT 0,
  `registered` INTEGER DEFAULT 0,
  `startt` TEXT,
  `user_interval` INTEGER,
  `version` TEXT,
  `wantann` INTEGER DEFAULT 0,
  `wantann_talk` INTEGER DEFAULT 0,
  `wantbeacon` INTEGER DEFAULT 0,
  `wantbeep` INTEGER DEFAULT 0,
  `wantcw` INTEGER DEFAULT 0,
  `wantdx` INTEGER DEFAULT 0,
  `wantdxcq` INTEGER DEFAULT 0,
  `wantdxitu` INTEGER DEFAULT 0,
  `wantecho` INTEGER DEFAULT 0,
  `wantemail` INTEGER DEFAULT 0,
  `wantft` INTEGER DEFAULT 0,
  `wantgtk` INTEGER DEFAULT 0,
  `wantlogininfo` INTEGER DEFAULT 0,
  `wantpc16` INTEGER DEFAULT 0,
  `wantpc9x` INTEGER DEFAULT 0,
  `wantpsk` INTEGER DEFAULT 0,
  `wantrbn` INTEGER DEFAULT 0,
  `wantroutepc19` INTEGER DEFAULT 0,
  `wantrtty` INTEGER DEFAULT 0,
  `wantsendpc16` INTEGER DEFAULT 0,
  `wanttalk` INTEGER DEFAULT 0,
  `wantusstate` INTEGER DEFAULT 0,
  `wantwcy` INTEGER DEFAULT 0,
  `wantwwv` INTEGER DEFAULT 0,
  `wantwx` INTEGER DEFAULT 0,
  `width` INTEGER,
  `xpert` INTEGER DEFAULT 0,
  `wantgrid` INTEGER DEFAULT 0
);
		};
	}

	$dbh->do($sql);
}

sub get {
	my ($call) = @_;
	$call = uc $call;
	my $sql = "SELECT * FROM `$table` WHERE `call` = ?";
	my $sth = $dbh->prepare($sql);
	$sth->execute($call);
	my $row = $sth->fetchrow_hashref;
	return undef unless $row;

	my %obj = %$row;

	# Lista explícita de campos que SÍ son JSON
	my %json_fields = map { $_ => 1 } qw(
		believe
		buddies
		connlist
		email
		group
	);

	foreach my $key (keys %obj) {
		next unless defined $obj{$key};

		if ($json_fields{$key}) {
			my $val = $obj{$key};
			next if $val eq '' or $val eq 'null';  # evitar decode vacío
			eval {
				$obj{$key} = $json->decode($val);
			};
			if ($@) {
				warn "[DXUser_SQL] JSON decode failed for $key on $call: $@\n";
				$obj{$key} = [];
			}
		} else {
			$obj{$key} = Encode::decode('utf8', $obj{$key})
			  unless Encode::is_utf8($obj{$key});
		}
	}

	my %defaults = %{ __PACKAGE__->alloc($call) };
	foreach my $k (keys %defaults) {
		$obj{$k} = $defaults{$k} unless exists $obj{$k};
	}

	return bless \%obj, 'DXUser';
}

sub alloc {
	my ($class, $call) = @_;
	my $self = {
		call           => uc $call,
		sort           => 'U',
		group          => ['local'],
		registered     => 0,
		priv           => 0,
		lockout        => 0,
		isolate        => 0,
		lang           => 'en',
		K              => 0,
		annok          => 1,
		dxok           => 1,
		rbnseeme       => 0,
		wantann        => 1,
		wantann_talk   => 1,
		wantbeacon     => 0,
		wantbeep       => 0,
		wantcw         => 0,
		wantdx         => 1,
		wantdxcq       => 0,
		wantdxitu      => 0,
		wantecho       => 0,
		wantemail      => 1,
		wantft         => 0,
		wantgrid       => 0,
		wantgtk        => 1,
		wantlogininfo  => 0,
		wantpc16       => 1,
		wantpc9x       => 1,
		wantpsk        => 0,
		wantrbn        => 0,
		wantrtty       => 0,
		wantsendpc16   => 1,
		wanttalk       => 1,
		wantusstate    => 0,
		wantwcy        => 1,
		wantwwv        => 1,
		wantwx         => 1,
	};
	return bless $self, 'DXUser';
}

sub put {
	my ($self) = @_;
	my $call = uc $self->{call};
	return unless $call;

	$self->{lastseen} = $main::systime unless $self->{lastseen};

	my @values;
	my @columns = map { "`$_`" } @FIELDS;

	# Only these fields should be serialised as JSON
	my %json_fields = map { $_ => 1 } qw(
		believe
		buddies
		connlist
		email
		group
	);

	foreach my $f (@FIELDS) {
		my $val = $self->{$f};

		if ($json_fields{$f}) {
			push @values, defined $val ? $json->encode($val) : undef;
		} else {
			if (defined $val && !Encode::is_utf8($val)) {
				$val = Encode::decode('utf8', $val);
			}
			push @values, $val;
		}
	}

	my $placeholders = join(", ", ("?") x @FIELDS);

	my $sql = ($main::db_backend eq 'mysql')
		? "INSERT INTO `$table` (" . join(", ", @columns) . ") VALUES ($placeholders)
		   ON DUPLICATE KEY UPDATE " . join(", ", map { "$_ = VALUES($_)" } @columns)
		: "REPLACE INTO `$table` (" . join(", ", @columns) . ") VALUES ($placeholders)";

	my $sth = $dbh->prepare($sql);
	$sth->execute(@values);

	return 1;
}

sub new {
	my ($class, $call) = @_;
	my $self = $class->alloc($call);
	$self->put;
	return $self;
}

sub del {
	my ($self) = @_;
	my $call = uc $self->{call};
	my $sql = "DELETE FROM `$table` WHERE `call` = ?";
	my $sth = $dbh->prepare($sql);
	$sth->execute($call);
	return 1;
}

sub close {
	my ($self, $startt, $ip) = @_;
	$self->{lastin} = $main::systime;
	my $ref = [ $startt || $self->{startt}, $main::systime ];
	push @$ref, $ip if $ip;
	push @{$self->{connlist}}, $ref;
	shift @{$self->{connlist}} if @{$self->{connlist}} > $DXUser::maxconnlist;
	$self->put;
}

sub get_all_calls {
	my $sth = $dbh->prepare("SELECT `call` FROM `$table`");
	$sth->execute();
	my @calls;
	while (my ($call) = $sth->fetchrow_array) {
		push @calls, $call;
	}
	return @calls;
}

sub sync {
	my ($self) = @_;
	return put($self) if $self && ref($self) eq 'DXUser';
	return 1;
}

sub export {
	my $name = 'user_json';
	my $fn = $name =~ m{/} ? $name : "$main::local_data/$name";

	require IO::File;
	require Time::HiRes;
	require File::Copy;

	print "[DXUser_SQL] Exporting users to $fn...\n";

	copy($fn, "$fn.bak") if -e $fn;

	my $ta = [Time::HiRes::gettimeofday];
	my $count = 0;

	my $fh = IO::File->new(">$fn") or return "Cannot open $fn ($!)";
	binmode $fh, ":utf8";

	use DXUser ();
	print $fh DXUser::export_preamble() if defined &DXUser::export_preamble;

	foreach my $call (get_all_calls()) {
		my $user = get($call);
		next unless $user;

		my %filtered;
		foreach my $field ($user->fields) {
			next unless exists $user->{$field};

			my $val = $user->{$field};

			next if !defined $val;
			next if (!ref($val) && $val eq '');
			next if (ref($val) eq 'ARRAY' && !@$val);
			next if (ref($val) eq 'HASH'  && !%$val);

			$filtered{$field} = $val;
		}

		my $json_str = eval {
			'{' .
			join(',', map {
				my $k = $_;
				my $v = $filtered{$k};
				my $jval = $json->encode($v);
				$json->encode($k) . ':' . $jval;
			} sort keys %filtered)
			. '}';
		};
		if ($@) {
			warn "[DXUser_SQL] JSON encode error for $call: $@";
			next;
		}

		print $fh "$call\t$json_str\n";
		++$count;
	}

	$fh->close;

	my $diff = Time::HiRes::tv_interval($ta);
	my $s = "Exported $count users to $fn in ${diff}s\n";
	print "[DXUser_SQL] $s";
	return $s;
}

sub _table_exists {
	my ($t) = @_;
	if ($main::db_backend eq 'sqlite') {
		my $sth = $dbh->prepare("SELECT name FROM sqlite_master WHERE type='table' AND name=?");
		$sth->execute($t);
		my ($exists) = $sth->fetchrow_array;
		return defined $exists;
	} else {
		my $sth = $dbh->prepare("SHOW TABLES LIKE ?");
		$sth->execute($t);
		my ($exists) = $sth->fetchrow_array;
		return defined $exists;
	}
}

sub _import_from_v3j {
	print "[DXUser_SQL] Importing users from users.v3j...\n";
	use DB_File;
	use Fcntl;

	my $file = "$main::root/local_data/users.v3j";
	return unless -e $file;

	my %u;
	tie %u, 'DB_File', $file, O_RDONLY, 0644, $DB_BTREE or return;

	foreach my $call (keys %u) {
		my $data = eval { $json->decode($u{$call}) };
		next unless $data && ref $data eq 'HASH';

		my %defaults = %{ DXUser_SQL->alloc($call) };
		foreach my $k (keys %defaults) {
			$data->{$k} = $defaults{$k} unless exists $data->{$k};
		}

		my $user = bless $data, 'DXUser';
		put($user);
	}

	untie %u;
}

sub recover {
	return;
}

sub fields {
	my ($self) = @_;
	return @FIELDS;
}

1;
