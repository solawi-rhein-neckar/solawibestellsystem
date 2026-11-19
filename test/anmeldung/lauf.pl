#!/usr/bin/perl
#
# Test: Anmeldung per Mail-Link über die Website und Sitzungen je Gerät (cgi-bin/SolawiSitzung.pm, wp.pl, resql.pl), Pflege der
# Mailadressen in BenutzerZugang (resql.pl, nur Orga und Admin) und das Einmal-Skript model/BenutzerZugangFuellen.pl.
# Nur erfundene Mitglieder (example.org). Startet eine eigene, leere MySQL in einem Temp-Ordner und räumt sie danach weg;
# wp.pl und resql.pl laufen als CGI wie auf dem Server, nur mit Verbindung zu dieser Test-MySQL.
#
#   perl test/anmeldung/lauf.pl                      mit dem Platzhalter-Schema (test/anmeldung/schema-platzhalter.sql)
#   perl test/anmeldung/lauf.pl --schema dump.sql    mit dem Schema-Dump der AG (mysqldump --no-data --routines --triggers)
#   perl test/anmeldung/lauf.pl --web <ordner>       zusätzlich gegen die echte Brücke der Website: <ordner> enthält
#                                                    mitglieder/_intern/ (tuer.php, versand.php, bestellsystem.php), z. B. dist-viios/
#
# Braucht: mysqld und mysql (MySQL 8.4 o. ä.; MYSQLD=… oder im PATH), php (PHP=… oder im PATH), DBD::mysql (PERL5LIB),
# für --web zusätzlich Digest::SHA (auf dem Mac in Perl enthalten). Einzelheiten: test/anmeldung/README.md
#
use strict;
use warnings;
use utf8;
use Cwd qw(abs_path);
use Encode ();
use File::Basename qw(dirname);
use File::Temp qw(tempdir);
use Getopt::Long;
use IPC::Open3;
use JSON::PP;
use POSIX qw(WNOHANG);
use Symbol qw(gensym);
use Test::More;

binmode(STDOUT, ':encoding(UTF-8)');
binmode(Test::More->builder->output, ':encoding(UTF-8)');
binmode(Test::More->builder->failure_output, ':encoding(UTF-8)');

my $REPO = abs_path(dirname(__FILE__) . '/../..');
my ($SCHEMA, $WEB) = ("$REPO/test/anmeldung/schema-platzhalter.sql", undef);
GetOptions('schema=s' => \$SCHEMA, 'web=s' => \$WEB) or die "Aufruf: perl test/anmeldung/lauf.pl [--schema dump.sql] [--web ordner]\n";

my $LOKAL = "$ENV{HOME}/.cache/solawi-bestellsystem-test/perl5/lib/perl5";
$ENV{PERL5LIB} = join(':', grep { $_ } ($ENV{PERL5LIB}, (-d $LOKAL ? $LOKAL : ())));
require lib;
lib->import(split(/:/, $ENV{PERL5LIB}), "$REPO/cgi-bin"); # wie -I: mit den Architektur-Ordnern (DBD::mysql ist XS)
require DBI;
require Authen::Passphrase::PHPass;

sub finde {
	my ($name, @auch) = @_;
	foreach my $d (split(/:/, $ENV{PATH} || ''), @auch) {
		return "$d/$name" if -x "$d/$name";
	}
	return undef;
}
my $MYSQLD = $ENV{MYSQLD} || finde('mysqld', '/opt/homebrew/opt/mysql@8.4/bin') or BAIL_OUT('mysqld nicht gefunden (MYSQLD=…)');
my $MYSQL  = finde('mysql', dirname($MYSQLD)) or BAIL_OUT('mysql (Client) nicht gefunden');
my $PHP    = $ENV{PHP} || finde('php') or BAIL_OUT('php nicht gefunden (PHP=…)');

# ---------- Test-MySQL ----------
my $TMP  = tempdir('solawi-anmeldung-XXXXXX', TMPDIR => 1, CLEANUP => !$ENV{BEHALTEN}); # BEHALTEN=1: Ordner (Logs) bleiben
my $SOCK = "$TMP/mysql.sock";
system($MYSQLD, '--no-defaults', "--datadir=$TMP/daten", '--initialize-insecure', "--log-error=$TMP/init.log") == 0
	or BAIL_OUT("mysqld --initialize-insecure ging nicht, siehe $TMP/init.log");
my $MYSQLD_PID = fork();
if (!$MYSQLD_PID) {
	open(STDOUT, '>', '/dev/null');
	open(STDERR, '>', '/dev/null');
	exec($MYSQLD, '--no-defaults', "--datadir=$TMP/daten", "--socket=$SOCK", '--skip-networking', '--mysqlx=OFF',
		"--pid-file=$TMP/mysqld.pid", "--log-error=$TMP/mysqld.log") or exit(1);
}
END {
	if ($MYSQLD_PID) {
		kill('TERM', $MYSQLD_PID);
		for (1 .. 50) { last if waitpid($MYSQLD_PID, WNOHANG) != 0; select(undef, undef, undef, 0.2); }
	}
}
my $root;
for (1 .. 100) {
	$root = eval { DBI->connect("DBI:mysql:mysql_socket=$SOCK", 'root', '', { RaiseError => 1, PrintError => 0, AutoCommit => 1 }) };
	last if $root;
	select(undef, undef, undef, 0.2);
}
BAIL_OUT("Test-MySQL startet nicht, siehe $TMP/mysqld.log") unless $root;
note('MySQL ' . $root->selectrow_array('SELECT VERSION()') . ", Schema: $SCHEMA");

sub sql_datei {
	my ($db, $datei) = @_;
	system("'$MYSQL' --no-defaults -uroot -S '$SOCK' $db < '$datei'") == 0 or BAIL_OUT("Einspielen von $datei in $db ging nicht");
}
# Für den Dump: Einzelne Prozeduren, die MySQL 5.7 noch annahm, lehnt MySQL 8 ab. --force überspringt sie; was fehlt, steht
# im Testlauf. Tabellen, Trigger und Views, die der Test braucht, müssen da sein (prüft das Einspielen der neuen Tabellen).
sub sql_datei_nachsichtig {
	my ($db, $datei) = @_;
	system("'$MYSQL' --no-defaults --force -uroot -S '$SOCK' $db < '$datei' 2> '$TMP/schema-fehler.log'");
	open(my $fh, '<', "$TMP/schema-fehler.log") or die $!;
	my @fehler = grep { /^ERROR/ } <$fh>;
	close($fh);
	note(scalar(@fehler) . ' Anweisung(en) des Schemas von MySQL 8 abgelehnt und übersprungen:') if @fehler;
	note('  ' . substr($_, 0, 110)) foreach @fehler;
}
# Der Dump vom Server stammt aus MySQL 5.7: Dessen sql_mode NO_AUTO_CREATE_USER kennt MySQL 8 nicht mehr, und Trigger, Views
# und Prozeduren laufen als DEFINER, den es in der Test-MySQL erst geben muss. Angepasst wird eine Kopie im Temp-Ordner.
sub schema_fuer_test {
	my ($datei) = @_;
	open(my $fh, '<:raw', $datei) or BAIL_OUT("$datei: $!");
	my $t = do { local $/; <$fh> };
	close($fh);
	my $modus = ($t =~ s/,NO_AUTO_CREATE_USER\b|\bNO_AUTO_CREATE_USER,?//g) || 0;
	my %definer = map { $_ => 1 } ($t =~ /DEFINER=(`[^`]+`@`[^`]+`)/g);
	foreach my $d (sort keys %definer) {
		$root->do("CREATE USER IF NOT EXISTS $d");
		$root->do("GRANT ALL ON db208674_361.* TO $d");
	}
	note("Schema für MySQL 8 angepasst: NO_AUTO_CREATE_USER $modus-mal entfernt, " . scalar(keys %definer) . ' DEFINER angelegt') if $modus || %definer;
	open($fh, '>:raw', "$TMP/schema.sql") or die $!;
	print $fh $t;
	close($fh);
	return "$TMP/schema.sql";
}
$root->do("CREATE DATABASE db208674_361 DEFAULT CHARACTER SET utf8 COLLATE utf8_german2_ci");
$root->do("CREATE DATABASE db208674_220 DEFAULT CHARACTER SET utf8mb4");
sql_datei_nachsichtig('db208674_361', schema_fuer_test($SCHEMA));
note('Trigger: ' . $root->selectrow_array("SELECT COUNT(*) FROM information_schema.TRIGGERS WHERE TRIGGER_SCHEMA = 'db208674_361'")
	. ', Prozeduren: ' . $root->selectrow_array("SELECT COUNT(*) FROM information_schema.ROUTINES WHERE ROUTINE_SCHEMA = 'db208674_361'")
	. ', Views: ' . $root->selectrow_array("SELECT COUNT(*) FROM information_schema.VIEWS WHERE TABLE_SCHEMA = 'db208674_361'"));
sql_datei('db208674_361', "$REPO/model/BenutzerZugangSitzung.sql");
$root->do("CREATE TABLE db208674_220.wp_users (ID bigint(20) unsigned NOT NULL AUTO_INCREMENT, user_login varchar(60) NOT NULL, user_pass varchar(255) NOT NULL, user_email varchar(100) NOT NULL, PRIMARY KEY (ID)) ENGINE=InnoDB");
$root->do("CREATE TABLE db208674_220.wp_usermeta (umeta_id bigint(20) unsigned NOT NULL AUTO_INCREMENT, user_id bigint(20) unsigned NOT NULL DEFAULT '0', meta_key varchar(255) DEFAULT NULL, meta_value longtext, PRIMARY KEY (umeta_id), KEY user_id (user_id)) ENGINE=InnoDB");

# ---------- erfundene Mitglieder ----------
#   Benutzer 1 Anna (Mitglied), Zugang: zwei Adressen; in WordPress wpID 101, wpMitID 102
#   Benutzer 2 Bert (Mitglied), nur WordPress wpID 103, dazu wpMit2ID 104 (Dora) – dieselbe Person an zwei Anteilen
#   Benutzer 3 Carla (Orga, Rolle 4), Zugang: eine Adresse
#   Benutzer 4 Dora (Mitglied), WordPress wpID 104
#   Benutzer 5 Erik (Depotverwaltung, Rolle 3), Benutzer 6 Fritz (Admin, Rolle 5): Passwort-Login über resql.pl, ohne WordPress
#   (Teil 13 legt für das Einmal-Skript weitere an)
my $db = DBI->connect("DBI:mysql:database=db208674_361;mysql_socket=$SOCK", 'root', '', { RaiseError => 1, AutoCommit => 1, mysql_enable_utf8mb4 => 1 });
# Testdaten nur mit den Spalten, die der Test braucht. Weitere Pflichtfelder ohne Standardwert im echten Schema (z. B. Role.Nr,
# Depot.KurzName) bekommen ohne strikten Modus ihren leeren Standardwert; danach gilt wieder der Modus des Servers.
$db->do("SET SESSION sql_mode = ''");
$db->do("INSERT INTO Role (ID, Name) VALUES (1,'Packteam'),(2,'Mitglied'),(3,'Depotverwaltung'),(4,'Orga'),(5,'Admin')");
$db->do("INSERT INTO Depot (ID, Name) VALUES (1,'Testdepot')");
$db->do("INSERT INTO Benutzer (ID, Name, Passwort, Cookie, Role_ID, Depot_ID, wpID, wpMitID, wpMit2ID) VALUES
	(1,'Anna Test','','',2,1,101,102,NULL),(2,'Bert Test','geheim-klartext','',2,1,103,NULL,104),(3,'Carla Orga','','',4,1,105,NULL,NULL),(4,'Dora Test','','',2,1,104,NULL,NULL),
	(5,'Erik Depot','erik-klartext','',3,1,NULL,NULL,NULL),(6,'Fritz Admin','fritz-klartext','',5,1,NULL,NULL,NULL)");
$db->do("INSERT INTO BenutzerZugang (ID, Benutzer_ID, Email, Bezeichnung) VALUES
	(1,1,'anna.zugang\@example.org','Hauptmitglied'),(2,1,'anna.handy\@example.org','Mit-Mitglied'),(3,3,'carla\@example.org',NULL)");
$db->do("SET SESSION sql_mode = DEFAULT");
my $hash = Authen::Passphrase::PHPass->new(cost => 8, salt => 'Testsalz', passphrase => 'anna-passwort')->as_crypt;
my $wp = DBI->connect("DBI:mysql:database=db208674_220;mysql_socket=$SOCK", 'root', '', { RaiseError => 1, AutoCommit => 1 });
$wp->do("INSERT INTO wp_users (ID, user_login, user_pass, user_email) VALUES (101,'Anna_Test',?,'anna\@example.org'),(102,'Anna_Mit','x','mit-anna\@example.org'),(103,'Bert_Test','x','bert\@example.org'),(104,'Dora_Test','x','dora\@example.org'),(105,'Carla_Orga','x','carla-wp\@example.org')", undef, $hash);
$wp->do("INSERT INTO wp_usermeta (user_id, meta_key, meta_value) VALUES (101,'account_status','approved'),(102,'account_status','approved'),(103,'account_status','approved'),(104,'account_status','approved'),(105,'account_status','approved')");

# ---------- cgi-bin als Kopie, verbunden mit der Test-MySQL ----------
my $CGI = "$TMP/cgi-bin";
system('cp', '-R', "$REPO/cgi-bin", $CGI) == 0 or BAIL_OUT('cgi-bin kopieren ging nicht');
my $ATTRAPPE = "$REPO/test/anmeldung/bruecke-attrappe.php";
sub ersetze {
	my ($datei, $muster, $neu, $soll) = @_;
	open(my $fh, '<:raw', $datei) or die $!;
	my $t = do { local $/; <$fh> };
	close($fh);
	my $n = ($t =~ s/$muster/$neu->()/ge);
	BAIL_OUT("$datei: $n statt $soll Ersetzungen für $muster") unless $n == $soll;
	open($fh, '>:raw', $datei) or die $!;
	print $fh $t;
	close($fh);
}
my $dsn = sub { my ($name) = ($& =~ /database=(\w+)/); qq{DBI->connect("DBI:mysql:database=$name;mysql_socket=$SOCK", "root", ""} };
ersetze("$CGI/wp.pl", qr/DBI->connect\("DBI:mysql:database=\w+;host=mysql", "\w+", "[^"]*"/, $dsn, 2);
ersetze("$CGI/resql.pl", qr/DBI->connect\("DBI:mysql:database=\w+;host=mysql", "\w+", "[^"]*"/, $dsn, 1);
ersetze("$CGI/createProcedures.pl", qr/DBI->connect\("DBI:mysql:database=\w+;host=mysql", "\w+", "[^"]*"/, $dsn, 1);
ersetze("$CGI/SolawiSitzung.pm", qr/our \$PHP\s*=\s*'[^']*';/, sub { "our \$PHP = '$PHP';" }, 1);
ersetze("$CGI/SolawiSitzung.pm", qr/our \$BRUECKE\s*=\s*'[^']*';/, sub { "our \$BRUECKE = \$ENV{TEST_BRUECKE} || '$ATTRAPPE';" }, 1);

# Anmeldungen der Website für die Attrappe
my $ANMELDUNGEN = "$TMP/anmeldungen.json";
sub keks { my ($p) = @_; return substr($p . ('x' x 43), 0, 43); }
my %WEB = (anna => keks('annaZugang'), handy => keks('annaHandy'), annawp => keks('annaWordpress'), mitanna => keks('mitAnnaWp'),
	dora => keks('doraDoppelt'), carla => keks('carlaOrga'), fremd => keks('niemand'), alt => keks('abgelaufen'),
	bert => keks('bertZugang'), bertneu => keks('bertNeu'), lenamit3 => keks('lenaMit3'));
sub anmeldungen_schreiben {
	my $bis = time() + 14 * 86400;
	my %a = (
		$WEB{anna}    => { email => 'Anna.Zugang@Example.org', bis => $bis },
		$WEB{handy}   => { email => 'anna.handy@example.org',  bis => $bis },
		$WEB{annawp}  => { email => 'anna@example.org',        bis => $bis },
		$WEB{mitanna} => { email => 'mit-anna@example.org',    bis => $bis },
		$WEB{dora}    => { email => 'dora@example.org',        bis => $bis },
		$WEB{carla}   => { email => 'carla@example.org',       bis => $bis },
		$WEB{bert}    => { email => 'bert@example.org',        bis => $bis },
		$WEB{bertneu} => { email => 'bert.neu@example.org',    bis => $bis },
		$WEB{lenamit3} => { email => 'lena-mit3@example.org',  bis => $bis },
		$WEB{fremd}   => { email => 'niemand@example.org',     bis => $bis },
		$WEB{alt}     => { email => 'anna.zugang@example.org', bis => time() - 60 },
	);
	open(my $fh, '>', $ANMELDUNGEN) or die $!;
	print $fh encode_json(\%a);
	close($fh);
	unlink("$ANMELDUNGEN.log");
}
anmeldungen_schreiben();

# ---------- CGI-Aufruf wie über cgi-bin/*.php ----------
sub cgi {
	my (%a) = @_;
	my $body = defined $a{body} ? encode_json($a{body}) : '';
	my %env = (
		REQUEST_METHOD => $a{methode} || 'GET', PATH_INFO => $a{pfad}, SCRIPT_NAME => "/cgi-bin/$a{skript}.php",
		HTTP_HOST => 'www.solawi-rhein-neckar.org', HTTPS => 'on', SERVER_PORT => 443, SERVER_PROTOCOL => 'HTTP/1.1',
		HTTP_X_REQUESTED_WITH => 'XMLHttpRequest', ATTRAPPE_DATEI => $ANMELDUNGEN, PERL5LIB => $ENV{PERL5LIB},
		PATH => $ENV{PATH}, HOME => $ENV{HOME},
	);
	if (($a{methode} || 'GET') ne 'GET') {
		$env{CONTENT_TYPE} = 'application/json; charset=utf-8';
		$env{CONTENT_LENGTH} = length($body);
	}
	$env{HTTP_COOKIE} = join('; ', map { "$_=$a{cookies}{$_}" } sort keys %{ $a{cookies} }) if $a{cookies} && %{ $a{cookies} };
	$env{TEST_BRUECKE} = $a{bruecke} if $a{bruecke};
	foreach my $k (keys %{ $a{kopf} || {} }) {
		if (defined $a{kopf}{$k}) { $env{$k} = $a{kopf}{$k}; } else { delete $env{$k}; }
	}
	local %ENV = %env;
	my $err = gensym;
	my $pid = open3(my $in, my $out, $err, $^X, "-I$CGI", "$CGI/$a{skript}.pl");
	binmode($in, ':raw');
	print $in $body;
	close($in);
	my $text = do { local $/; <$out> } // '';
	my $fehler = do { local $/; <$err> } // '';
	waitpid($pid, 0);
	my ($kopf, $rest) = split(/\r?\n\r?\n/, $text, 2);
	$rest //= '';
	my @zeilen = split(/\r?\n/, $kopf // '');
	my ($status) = map { /^Status:\s*(\d+)/i ? $1 : () } @zeilen;
	my @cookies = map { /^Set-Cookie:\s*(.*)$/i ? $1 : () } @zeilen;
	# mehrere JSON-Objekte hintereinander möglich (OPTIONS-Zweig); das letzte zählt
	my ($json_text) = $rest =~ /(\{[^{}]*(?:\{[^{}]*\}[^{}]*)*\}|\[.*\])\s*$/s;
	my $json = defined $json_text ? eval { JSON::PP->new->utf8->decode($json_text) } : undef;
	return { status => $status || 200, cookies => \@cookies, json => $json, roh => $rest, stderr => $fehler };
}
sub cookie_aus {
	my ($antwort, $name) = @_;
	foreach my $c (@{ $antwort->{cookies} }) {
		return $1 if $c =~ /^\Q$name\E=([^;]*)/;
	}
	return undef;
}
sub zeilen { return $db->selectrow_array($_[0], undef, @_[1 .. $#_]); }
sub login_web {
	my ($web, %mehr) = @_;
	return cgi(skript => 'wp', methode => 'POST', pfad => '/login/web', body => {}, cookies => { mg_s => $web, %{ $mehr{cookies} || {} } }, %mehr);
}
sub eigene { my ($sid) = @_; return cgi(skript => 'resql', pfad => '/Benutzer/OWN', cookies => { sessionid => $sid }); }
sub name_von { my ($r) = @_; return ref $r->{json} eq 'ARRAY' && $r->{json}[0] ? $r->{json}[0]{Name} : ''; }

# =====================================================================================================================
note('1 Ohne Anmeldung');
my $r = cgi(skript => 'resql', pfad => '/Benutzer/OWN');
like($r->{json}{reason} // '', qr/not authenticated/, 'resql ohne Cookie: not authenticated');
$r = login_web(undef, cookies => {});
is($r->{json}{result}, 'not logged in on website', 'login/web ohne mg_s: nicht angemeldet');
is(scalar(@{ $r->{cookies} }), 0, 'kein Cookie gesetzt');

note('2 Anmeldung über die Website (BenutzerZugang)');
$r = login_web($WEB{anna});
is($r->{json}{result}, 'success', 'login/web mit Anmeldung der Website: success');
is($r->{json}{user}, 'Anna Test', 'Benutzer Anna (Adresse in anderer Schreibweise)');
my $sid1 = cookie_aus($r, 'sessionid');
like($sid1 // '', qr/^[0-9a-f]{64}$/, 'sessionid: 64 Hex-Zeichen (32 Zufallsbytes)');
my ($sc) = grep { /^sessionid=/ } @{ $r->{cookies} };
like($sc, qr/Path=\/;/, 'Cookie: Path=/');
like($sc, qr/; Secure/, 'Cookie: Secure');
like($sc, qr/; HttpOnly/, 'Cookie: HttpOnly');
like($sc, qr/SameSite=Lax/, 'Cookie: SameSite=Lax');
my ($max) = $sc =~ /Max-Age=(\d+)/;
ok(abs($max - 14 * 86400) < 120, 'Cookie: Max-Age = Rest der Website-Anmeldung (14 Tage)');
is(zeilen('SELECT COUNT(*) FROM BenutzerSitzung WHERE IDHash = SHA2(?, 256) AND Benutzer_ID = 1 AND BenutzerZugang_ID = 1', $sid1), 1, 'BenutzerSitzung: Zeile mit Prüfsumme, Benutzer 1, Zugang 1');
is(zeilen('SELECT COUNT(*) FROM BenutzerSitzung WHERE IDHash = ?', $sid1), 0, 'die Sitzungs-ID selbst steht nirgends in der Datenbank');
SKIP: {
	skip('Schema ohne Audit-Tabellen (Platzhalter)', 1)
		unless zeilen("SELECT COUNT(*) FROM information_schema.TABLES WHERE TABLE_SCHEMA = 'db208674_361' AND TABLE_NAME = 'zaudit_meta'");
	is(zeilen('SELECT COUNT(*) FROM zaudit_meta WHERE old_value LIKE ? OR new_value LIKE ?', "%$sid1%", "%$sid1%"), 0, '… auch nicht im Audit (zaudit_meta)');
}
ok(zeilen('SELECT ABS(TIMESTAMPDIFF(SECOND, GueltigBis, NOW() + INTERVAL 14 DAY)) < 120 FROM BenutzerSitzung WHERE IDHash = SHA2(?, 256)', $sid1), 'GueltigBis = Ende der Website-Anmeldung');
is(name_von(eigene($sid1)), 'Anna Test', 'resql Benutzer/OWN mit der neuen Sitzung: Anna');
is(zeilen("SELECT Cookie FROM Benutzer WHERE ID = 1"), '', 'Benutzer.Cookie bleibt unberührt');
open(my $log, '<', "$ANMELDUNGEN.log") or die;
my @log = <$log>;
close($log);
like($log[-1], qr/^pruefen argumente=0 zeilen=\d+$/, 'Brücke: nur der Befehl auf der Kommandozeile, Adressen über stdin');

note('3 Mehrere Geräte und Mit-Mitglied gleichzeitig');
$r = login_web($WEB{anna});
my $sid2 = cookie_aus($r, 'sessionid');
ok($sid2 && $sid2 ne $sid1, 'zweites Gerät: neue, andere Sitzung');
$r = login_web($WEB{handy});
my $sid3 = cookie_aus($r, 'sessionid');
is($r->{json}{user}, 'Anna Test', 'Mit-Mitglied (zweite Adresse im Zugang) landet im selben Anteil');
is(zeilen('SELECT BenutzerZugang_ID FROM BenutzerSitzung WHERE IDHash = SHA2(?, 256)', $sid3), 2, 'Sitzung des Mit-Mitglieds hängt an Zugang 2');
is(name_von(eigene($_)), 'Anna Test', 'Sitzung ' . substr($_, 0, 6) . '… gilt weiter') foreach ($sid1, $sid2, $sid3);

note('4 BenutzerZugang hat Einträge: WordPress zählt für die Anmeldung nicht mehr (Übergang: Teil 11)');
foreach my $fall (['annawp', 'Adresse nur in wp_users (wpID 101)'], ['mitanna', 'Mit-Mitglied nur über wpMitID 102'],
	['dora', 'wp-Konto an zwei Anteilen (wpID bei Dora, wpMit2ID bei Bert)']) {
	$r = login_web($WEB{ $fall->[0] });
	is($r->{json}{result}, 'not logged in on website', "$fall->[1] → keine Anmeldung");
	is(cookie_aus($r, 'sessionid'), undef, '… und kein Cookie');
}
$r = login_web($WEB{fremd});
is($r->{json}{result}, 'not logged in on website', 'angemeldet auf der Website, aber Adresse unbekannt im Bestellsystem → keine Sitzung');
$r = login_web($WEB{alt});
is($r->{json}{result}, 'not logged in on website', 'abgelaufene Anmeldung der Website → keine Sitzung');
$r = login_web('kaputt;sessionid=1');
is($r->{json}{result}, 'not logged in on website', 'mg_s in falscher Form → keine Sitzung');

note('5 Herkunft (gegen Login- und Logout-CSRF)');
$r = login_web($WEB{anna}, kopf => { HTTP_X_REQUESTED_WITH => undef });
is($r->{status}, 403, 'ohne X-Requested-With → 403');
$r = login_web($WEB{anna}, kopf => { HTTP_ORIGIN => 'https://boese.example.org' });
is($r->{status}, 403, 'fremde Origin → 403');
$r = login_web($WEB{anna}, kopf => { HTTP_SEC_FETCH_SITE => 'cross-site' });
is($r->{status}, 403, 'Sec-Fetch-Site cross-site → 403');
$r = login_web($WEB{anna}, kopf => { HTTP_ORIGIN => 'https://www.solawi-rhein-neckar.org', HTTP_SEC_FETCH_SITE => 'same-origin' });
is($r->{json}{result}, 'success', 'eigene Origin, same-origin → success');
my $sid5 = cookie_aus($r, 'sessionid');
$r = cgi(skript => 'wp', methode => 'POST', pfad => '/logout', body => {}, cookies => { sessionid => $sid5 }, kopf => { HTTP_X_REQUESTED_WITH => undef });
is($r->{status}, 403, 'logout ohne X-Requested-With → 403');
is(name_von(eigene($sid5)), 'Anna Test', 'und die Sitzung gilt weiter');

note('6 Tabellen BenutzerSitzung und BenutzerZugang über resql.pl');
$r = cgi(skript => 'resql', pfad => '/BenutzerSitzung', cookies => { sessionid => $sid1 });
like($r->{json}{reason} // '', qr/no access right/, 'Mitglied: GET BenutzerSitzung gesperrt');
$r = cgi(skript => 'resql', pfad => '/BenutzerZugang', cookies => { sessionid => $sid1 });
like($r->{json}{reason} // '', qr/no access right/, 'Mitglied: GET BenutzerZugang (alle) gesperrt');
$r = cgi(skript => 'resql', pfad => '/BenutzerZugang/MY', cookies => { sessionid => $sid1 });
# Rolle 2 bekommt höchstens die eigenen Adressen (das Frontend fragt sie nicht ab)
ok(ref $r->{json} eq 'ARRAY' ? adressen($r) eq 'anna.handy@example.org,anna.zugang@example.org' : ($r->{json}{reason} // '') =~ /no access right/,
	'Mitglied: GET BenutzerZugang/MY → nur die eigenen Adressen oder keine');
$r = cgi(skript => 'resql', methode => 'POST', pfad => '/BenutzerZugang', body => { Benutzer_ID => 1, Email => 'neu@example.org' }, cookies => { sessionid => $sid1 });
like($r->{json}{reason} // '', qr/no access right/, 'Mitglied: POST BenutzerZugang gesperrt');
is(zeilen("SELECT COUNT(*) FROM BenutzerZugang WHERE Email = 'neu\@example.org'"), 0, 'und nichts eingetragen');
$r = cgi(skript => 'resql', pfad => '/benutzersitzung', cookies => { sessionid => $sid1 });
like($r->{json}{reason} // '', qr/no access right/, 'Kleinschreibung umgeht die Sperre nicht');
$r = login_web($WEB{carla});
my $sidC = cookie_aus($r, 'sessionid');
is($r->{json}{user}, 'Carla Orga', 'Orga meldet sich über die Website an');
$r = cgi(skript => 'resql', pfad => '/BenutzerZugang', cookies => { sessionid => $sidC });
is(scalar(@{ ref $r->{json} eq 'ARRAY' ? $r->{json} : [] }), 3, 'Orga: GET BenutzerZugang → alle Adressen');
$r = cgi(skript => 'resql', pfad => '/BenutzerSitzung', cookies => { sessionid => $sidC });
like($r->{json}{reason} // '', qr/no access right/, 'Orga: BenutzerSitzung trotzdem gesperrt');

note('7 Abmelden');
$r = cgi(skript => 'wp', methode => 'POST', pfad => '/logout', body => {}, cookies => { sessionid => $sid1, mg_s => $WEB{anna} });
is($r->{json}{result}, 'success', 'logout: success');
ok((grep { /^sessionid=deleted;.*Max-Age=0/ } @{ $r->{cookies} }), 'logout löscht sessionid');
ok((grep { /^mg_s=deleted;.*Path=\/;/ } @{ $r->{cookies} }) && (grep { /^mg_s=deleted;.*Path=\/mitglieder\/;/ } @{ $r->{cookies} }), 'logout löscht mg_s für / und /mitglieder/');
is(zeilen('SELECT COUNT(*) FROM BenutzerSitzung WHERE IDHash = SHA2(?, 256)', $sid1), 0, 'Sitzung dieses Geräts gelöscht');
like(eigene($sid1)->{json}{reason} // '', qr/not authenticated/, 'dieses Gerät ist abgemeldet');
is(name_von(eigene($sid2)), 'Anna Test', 'das zweite Gerät bleibt angemeldet');
is(name_von(eigene($sid3)), 'Anna Test', 'das Mit-Mitglied bleibt angemeldet');
is(login_web($WEB{anna})->{json}{result}, 'not logged in on website', 'Website-Anmeldung beendet → login/web meldet nicht wieder an');
anmeldungen_schreiben();

note('8 Ablauf, aufräumen, zuletzt gesehen');
$db->do('UPDATE BenutzerSitzung SET GueltigBis = NOW() - INTERVAL 1 MINUTE WHERE IDHash = SHA2(?, 256)', undef, $sid2);
like(eigene($sid2)->{json}{reason} // '', qr/not authenticated/, 'abgelaufene Sitzung gilt nicht');
login_web($WEB{anna});
is(zeilen('SELECT COUNT(*) FROM BenutzerSitzung WHERE GueltigBis < NOW()'), 0, 'nächster Login räumt abgelaufene Sitzungen weg');
$db->do('UPDATE BenutzerSitzung SET ZuletztGesehen = NOW() - INTERVAL 2 HOUR WHERE IDHash = SHA2(?, 256)', undef, $sid3);
eigene($sid3);
ok(zeilen('SELECT ZuletztGesehen > NOW() - INTERVAL 1 MINUTE FROM BenutzerSitzung WHERE IDHash = SHA2(?, 256)', $sid3), 'ZuletztGesehen wird nach einer Stunde nachgezogen');
$db->do("DELETE FROM BenutzerZugang WHERE ID = 2");
like(eigene($sid3)->{json}{reason} // '', qr/not authenticated/, 'Adresse aus dem Zugang gelöscht → ihre Sitzungen enden (ON DELETE CASCADE)');
$db->do("INSERT INTO BenutzerZugang (ID, Benutzer_ID, Email, Bezeichnung) VALUES (2,1,'anna.handy\@example.org','Mit-Mitglied')");

note('9 Übergang: Passwort-Login wie bisher');
$r = cgi(skript => 'wp', methode => 'POST', pfad => '/login', body => { name => 'Anna_Test', password => 'anna-passwort' });
is($r->{json}{result}, 'success', 'wp.pl Passwort-Login: success');
my $alt = cookie_aus($r, 'sessionid');
like($alt // '', qr/^0\.\d+/, 'alte Sitzung (rand()) in Benutzer.Cookie');
my ($alt_kopf) = grep { /^sessionid=/ } @{ $r->{cookies} };
like($alt_kopf // '', qr/;\s*path=\/(;|$)/i, 'Cookie des Passwort-Logins: Path=/');
like($alt_kopf // '', qr/;\s*secure(;|$)/i, '… Secure');
like($alt_kopf // '', qr/;\s*HttpOnly(;|$)/i, '… HttpOnly (Abmelden geht über /logout)');
like($alt_kopf // '', qr/;\s*SameSite=Lax(;|$)/i, '… SameSite=Lax');
is(name_von(eigene($alt)), 'Anna Test', 'resql mit alter Sitzung: Anna');
is(name_von(eigene($sid5)), 'Anna Test', 'neue Sitzungen gelten daneben weiter');
$r = cgi(skript => 'wp', methode => 'POST', pfad => '/login', body => { name => 'Anna_Test', password => 'falsch' });
is($r->{json}{result}, 'wrong pw', 'falsches Passwort: wrong pw');
$r = cgi(skript => 'wp', methode => 'POST', pfad => '/logout', body => {}, cookies => { sessionid => $alt });
is(zeilen("SELECT Cookie FROM Benutzer WHERE ID = 1"), '', 'logout mit alter Sitzung leert Benutzer.Cookie');
like(eigene($alt)->{json}{reason} // '', qr/not authenticated/, 'und sie gilt nicht mehr');

note('9b Leere Sitzungs-IDs und Passwort-Login über resql.pl');
# Benutzer.Cookie ist jetzt bei allen leer (nie angemeldet bzw. abgemeldet). Der Parser liefert für "&" einen leeren
# Wert, für "+" ein Leerzeichen; MySQL vergleicht ' ' und '' als gleich.
foreach my $w ('&', '+', '%20', '%C2%AD', '0') {
	like(eigene($w)->{json}{reason} // '', qr/not authenticated/, "Cookie sessionid=$w: abgewiesen");
}
$r = cgi(skript => 'resql', methode => 'POST', pfad => '/login', body => { name => 'Carla Orga', password => '' });
is($r->{json}{result}, 0, 'resql /login mit leerem Passwort (Benutzer.Passwort leer): 0');
like(eigene(cookie_aus($r, 'sessionid'))->{json}{reason} // '', qr/not authenticated/, '… und das Cookie gilt nicht');
$r = cgi(skript => 'resql', methode => 'POST', pfad => '/login', body => { name => 'Bert Test', password => 'geheim-klartext' });
is($r->{json}{result}, 1, 'resql /login mit richtigem Passwort: 1');
my ($resql_kopf) = grep { /^sessionid=/ } @{ $r->{cookies} };
like($resql_kopf // '', qr/HttpOnly.*SameSite=Lax|SameSite=Lax.*HttpOnly/i, '… Cookie mit HttpOnly und SameSite=Lax');
is(name_von(eigene(cookie_aus($r, 'sessionid'))), 'Bert Test', '… Bert ist angemeldet');
foreach my $pw ('GEHEIM-KLARTEXT', 'geheim-klartext ') {
	$r = cgi(skript => 'resql', methode => 'POST', pfad => '/login', body => { name => 'Bert Test', password => $pw });
	is($r->{json}{result}, 0, "resql /login mit '$pw': 0 (exakt verglichen)");
}

note('9c createProcedures.pl kennt die neuen Sitzungen');
# GET auf einen unbekannten Pfad: angemeldet → leere Antwort, sonst "not authenticated". Ändert nichts an der Datenbank.
foreach my $fall ([$sid5, 'neue Sitzung', 0], ['&', 'leerer Wert', 1], [undef, 'ohne Cookie', 1]) {
	my ($wert, $was, $abgewiesen) = @$fall;
	$r = cgi(skript => 'createProcedures', pfad => '/NICHTS', defined $wert ? (cookies => { sessionid => $wert }) : ());
	if ($abgewiesen) { like($r->{roh}, qr/not authenticated/, "createProcedures.pl, $was: abgewiesen"); }
	else { unlike($r->{roh}, qr/not authenticated/, "createProcedures.pl, $was: angemeldet"); }
	(my $m = $r->{stderr}) =~ s/^.*Issuing rollback\(\) due to DESTROY without explicit disconnect\(\).*\n?//mg;
	is($m, '', "createProcedures.pl, $was: keine Fehlermeldung");
}

note('10 Brücke fehlt (z. B. Mitgliederbereich noch nicht live)');
$r = login_web($WEB{anna}, bruecke => "$TMP/gibt-es-nicht.php");
is($r->{json}{result}, 'not logged in on website', 'ohne Brücke: keine Anmeldung, kein Fehler');
# bekannt und nicht von dieser Änderung: wp.pl schließt $dbh2 (WordPress) nie, DBI meldet das beim Beenden
(my $meldungen = $r->{stderr}) =~ s/^.*Issuing rollback\(\) due to DESTROY without explicit disconnect\(\).*\n?//mg;
unlike($meldungen, qr/\S/, 'keine Fehlermeldung (außer der bekannten DESTROY-Warnung von $dbh2)');

# BenutzerZugang auf einen festen Stand setzen (Sitzungen über gelöschte Adressen enden dabei, ON DELETE CASCADE)
my @ZUGANG_START = @{ $db->selectall_arrayref('SELECT ID, Benutzer_ID, Email, Bezeichnung FROM BenutzerZugang ORDER BY ID') };
sub zugang_setzen {
	$db->do('DELETE FROM BenutzerZugang');
	$db->do('INSERT INTO BenutzerZugang (ID, Benutzer_ID, Email, Bezeichnung) VALUES (?, ?, ?, ?)', undef, @$_) foreach @_;
}

note('11 Übergang: Solange BenutzerZugang leer ist, ordnet login/web über WordPress zu');
zugang_setzen();
$r = login_web($WEB{annawp});
my $sid4 = cookie_aus($r, 'sessionid');
is($r->{json}{user}, 'Anna Test', 'BenutzerZugang leer: Adresse nur in wp_users (wpID 101) → Anna');
is(zeilen('SELECT BenutzerZugang_ID IS NULL FROM BenutzerSitzung WHERE IDHash = SHA2(?, 256)', $sid4), 1, 'Sitzung ohne Zugang (Übergang)');
$r = login_web($WEB{mitanna});
is($r->{json}{user}, 'Anna Test', 'Mit-Mitglied über wpMitID 102 → Anna');
$r = login_web($WEB{dora});
is($r->{json}{result}, 'mehrdeutig', 'wp-Konto an zwei Anteilen (wpID bei Dora, wpMit2ID bei Bert) → mehrdeutig');
is(cookie_aus($r, 'sessionid'), undef, 'mehrdeutig: keine Sitzung');
is(login_web($WEB{fremd})->{json}{result}, 'not logged in on website', 'Adresse weder hier noch in WordPress → keine Sitzung');
$db->do("INSERT INTO BenutzerZugang (Benutzer_ID, Email) VALUES (3, 'carla\@example.org')");
is(login_web($WEB{annawp})->{json}{result}, 'not logged in on website', 'erste Adresse in BenutzerZugang: WordPress zählt sofort nicht mehr');
is(login_web($WEB{carla})->{json}{user}, 'Carla Orga', '… die eingetragene Adresse meldet an');
is(name_von(eigene($sid4)), 'Anna Test', 'Sitzung aus dem Übergang läuft bis zu ihrem Ende weiter (höchstens so lange wie die Website-Anmeldung)');
zugang_setzen(@ZUGANG_START);

note('12 Mailadressen pflegen über resql.pl (nur Orga und Admin)');
sub zpost { my ($sid, $pfad, $body) = @_; return cgi(skript => 'resql', methode => 'POST', pfad => $pfad, body => $body, cookies => { sessionid => $sid }); }
sub zdel  { my ($sid, $pfad) = @_; return cgi(skript => 'resql', methode => 'DELETE', pfad => $pfad, cookies => { sessionid => $sid }); }
sub zget  { my ($sid, $pfad) = @_; return cgi(skript => 'resql', pfad => $pfad, cookies => { sessionid => $sid }); }
sub adressen { my ($r) = @_; return join(',', sort map { $_->{Email} } @{ ref $r->{json} eq 'ARRAY' ? $r->{json} : [] }); }
sub anzahl_zugang { return zeilen('SELECT COUNT(*) FROM BenutzerZugang'); }
sub kanonisch { return JSON::PP->new->canonical->encode($_[0] // {}); }
my $orga = cookie_aus(login_web($WEB{carla}), 'sessionid');
is(name_von(eigene($orga)), 'Carla Orga', 'Orga (Rolle 4) per Mail-Link angemeldet');

$r = zpost($orga, '/BenutzerZugang', { Benutzer_ID => 2, Email => "  Bert\@Example.ORG \t", Bezeichnung => ' Hauptmitglied ' });
is($r->{json}{result}, 1, 'Orga: neue Adresse für Bert');
my $zb = $r->{json}{id} // 0;
is(zeilen('SELECT Email FROM BenutzerZugang WHERE ID = ?', $zb), 'bert@example.org', '… getrimmt und in Kleinbuchstaben gespeichert');
is(zeilen('SELECT CONCAT(Benutzer_ID, "/", Bezeichnung, "/", AenderBenutzer_ID) FROM BenutzerZugang WHERE ID = ?', $zb), '2/Hauptmitglied/3', '… am Anteil von Bert, Bezeichnung getrimmt, Carla als Änderin');
ok(!exists $r->{json}{query} && !exists $r->{json}{params}, '… Antwort ohne Abfrage und ohne Werte');
my $bert = cookie_aus(login_web($WEB{bert}), 'sessionid');
is(name_von(eigene($bert)), 'Bert Test', 'Bert meldet sich jetzt per Mail-Link an');

my $vorher = anzahl_zugang();
# Dubletten: Orga und Admin sehen alle Adressen ohnehin, die Meldung sagt deshalb genau, bei welchem Anteil die Adresse steht
foreach my $fall (
	['bert@example.org', 4, 'Adresse, die schon bei Bert steht, für Dora', 'Nicht gespeichert: Diese Adresse ist schon beim Anteil „Bert Test“ (Nr. 2) eingetragen.'],
	['BERT@example.org ', 2, 'dieselbe Adresse anders geschrieben, gleicher Anteil', 'Nicht gespeichert: Diese Adresse ist bei diesem Anteil schon eingetragen.'],
	['anna.zugang@example.org', 4, 'Adresse von Anna für Dora', 'Nicht gespeichert: Diese Adresse ist schon beim Anteil „Anna Test“ (Nr. 1) eingetragen.'],
) {
	my ($mail, $bid, $was, $meldung) = @$fall;
	$r = zpost($orga, '/BenutzerZugang', { Benutzer_ID => $bid, Email => $mail });
	is($r->{json}{reason} // '', $meldung, "Orga: $was → „$meldung“");
	unlike($r->{roh}, qr/\@|Duplicate|query|params/i, '… ohne Adresse, SQL-Fehler und Abfrage');
}
my %antworten;
foreach my $fall (
	['kein-at-zeichen', 4, 'ohne @'], ['a@b', 4, 'ohne Endung'], ['x y@example.org', 4, 'mit Leerzeichen'],
	["o'brien\@example.org", 4, 'mit Apostroph'], ['<z@example.org>', 4, 'in spitzen Klammern'], ['a,b@example.org', 4, 'mit Komma'],
	["m\x{fc}ller\@example.org", 4, 'mit Umlaut'], ['a..b@example.org', 4, 'zwei Punkte hintereinander'], ['', 4, 'leer'],
	[('a' x 65) . '@example.org', 4, 'über 64 Zeichen vor dem @'], ['a@' . join('.', ('b' x 60) x 5) . '.org', 4, 'über 254 Zeichen'],
) {
	my ($mail, $bid, $was) = @$fall;
	$r = zpost($orga, '/BenutzerZugang', { Benutzer_ID => $bid, Email => $mail });
	is($r->{json}{result}, 0, "Orga: $was → nicht gespeichert");
	$antworten{ kanonisch($r->{json}) }++;
	unlike($r->{roh}, qr/\@|Duplicate|example/i, '… Antwort ohne Adresse und SQL-Fehler');
}
is(scalar(keys %antworten), 1, 'ungültige Adressen bekommen alle dieselbe Meldung');
is((keys %antworten)[0], kanonisch({ result => 0, reason => 'Bitte eine gültige Mailadresse eingeben.' }), '… nämlich „Bitte eine gültige Mailadresse eingeben.“ (wie im Browser)');
is(anzahl_zugang(), $vorher, 'Dubletten und ungültige Adressen: nichts eingetragen');
$r = zpost($orga, '/BenutzerZugang', { Benutzer_ID => 999, Email => 'neu@example.org' });
is($r->{json}{reason} // '', 'Nicht gespeichert: Den Anteil Nr. 999 gibt es nicht.', 'Orga: Anteil, den es nicht gibt → „Den Anteil Nr. 999 gibt es nicht.“');
$r = zpost($orga, '/BenutzerZugang', { Email => 'neu@example.org' });
is($r->{json}{reason} // '', 'Nicht gespeichert: Kein Anteil angegeben.', 'Orga: ohne Anteil → „Kein Anteil angegeben.“');
$r = zpost($orga, '/benutzerzugang', { Benutzer_ID => 2, Email => 'kaputt' });
is($r->{json}{result}, 0, 'Kleinschreibung im Pfad umgeht die Prüfung nicht');
is(anzahl_zugang(), $vorher, '… nichts eingetragen');

$r = zpost($orga, "/BenutzerZugang/$zb", { Bezeichnung => 'Mit-Mitglied' });
is($r->{json}{result}, 1, 'Orga: nur die Bezeichnung geändert');
is(name_von(eigene($bert)), 'Bert Test', '… die Sitzung von Bert läuft weiter');
$r = zpost($orga, "/BenutzerZugang/$zb", { Bezeichnung => 'x' x 101 });
is($r->{json}{reason} // '', 'Nicht gespeichert: Die Bezeichnung ist zu lang (101 Zeichen, höchstens 100).', 'Bezeichnung über 100 Zeichen → Meldung mit Länge');
$r = zpost($orga, "/BenutzerZugang/$zb", { Email => 'Anna.Handy@example.org' });
is(kanonisch($r->{json}), kanonisch({ result => 0, type => 'update', reason => 'Nicht gespeichert: Diese Adresse ist schon beim Anteil „Anna Test“ (Nr. 1) eingetragen.' }), 'ändern auf eine Adresse, die bei Anna steht → Meldung nennt Annas Anteil');
is(zeilen('SELECT Email FROM BenutzerZugang WHERE ID = ?', $zb), 'bert@example.org', '… Adresse unverändert');
$r = zpost($orga, "/BenutzerZugang/$zb", {});
like($r->{json}{reason} // '', qr/Nichts geändert/, 'ändern ohne Felder → nichts geändert');
$r = zpost($orga, '/BenutzerZugang/99999', { Bezeichnung => 'x' });
is($r->{json}{reason} // '', 'Nicht gespeichert: Diese Adresse gibt es nicht mehr. Bitte „Mailadressen“ neu öffnen.', 'ändern, was es nicht gibt → „gibt es nicht mehr“');
$r = zpost($orga, "/BenutzerZugang/$zb", { Email => 'Bert.Neu@example.org' });
is($r->{json}{result}, 1, 'Orga: Adresse geändert');
like(eigene($bert)->{json}{reason} // '', qr/not authenticated/, '… die Sitzung über die alte Adresse endet');
is(login_web($WEB{bert})->{json}{result}, 'not logged in on website', '… die alte Adresse meldet nicht mehr an');
my $bn = cookie_aus(login_web($WEB{bertneu}), 'sessionid');
is(name_von(eigene($bn)), 'Bert Test', '… die neue schon');
$r = zpost($orga, "/BenutzerZugang/$zb", { Benutzer_ID => 4 });
is($r->{json}{result}, 1, 'Orga: Adresse zu einem anderen Anteil verschoben');
like(eigene($bn)->{json}{reason} // '', qr/not authenticated/, '… die Sitzung am alten Anteil endet');
my $dn = cookie_aus(login_web($WEB{bertneu}), 'sessionid');
is(name_von(eigene($dn)), 'Dora Test', '… die Adresse meldet jetzt bei Dora an');
$r = zdel($orga, "/BenutzerZugang/$zb");
is($r->{json}{result}, 1, 'Orga: Adresse entfernt');
is(zeilen('SELECT COUNT(*) FROM BenutzerZugang WHERE ID = ?', $zb), 0, '… die Zeile ist weg');
like(eigene($dn)->{json}{reason} // '', qr/not authenticated/, '… Geräte, die mit ihr angemeldet sind, sind abgemeldet');
is(login_web($WEB{bertneu})->{json}{result}, 'not logged in on website', '… und sie meldet nicht mehr an');
is(zdel($orga, "/BenutzerZugang/$zb")->{json}{reason} // '', 'Nicht entfernt: Diese Adresse gibt es nicht mehr. Bitte „Mailadressen“ neu öffnen.', 'noch einmal entfernen → „gibt es nicht mehr“');
is(zdel($orga, '/BenutzerZugang/Benutzer_ID/1/Bezeichnung/Hauptmitglied')->{json}{result}, 0, 'entfernen über Spalten statt ID → abgelehnt');
is(zeilen('SELECT COUNT(*) FROM BenutzerZugang WHERE Benutzer_ID = 1'), 2, '… die Adressen von Anna sind noch da');

$r = cgi(skript => 'resql', methode => 'POST', pfad => '/login', body => { name => 'Fritz Admin', password => 'fritz-klartext' });
my $admin = cookie_aus($r, 'sessionid');
$r = zpost($admin, '/BenutzerZugang', { Benutzer_ID => 5, Email => 'erik@example.org' });
is($r->{json}{result}, 1, 'Admin (Rolle 5): neue Adresse für Erik');
my $ze = $r->{json}{id} // 0;
$r = cgi(skript => 'resql', methode => 'POST', pfad => '/login', body => { name => 'Erik Depot', password => 'erik-klartext' });
my $depot = cookie_aus($r, 'sessionid');
is(name_von(eigene($depot)), 'Erik Depot', 'Depotverwaltung (Rolle 3) angemeldet');
is(adressen(zget($depot, '/BenutzerZugang/MY')), 'erik@example.org', 'Depotverwaltung: GET BenutzerZugang/MY → nur die eigene Adresse');
like(zget($depot, '/BenutzerZugang')->{json}{reason} // '', qr/no access right/, 'Depotverwaltung: GET BenutzerZugang (alle) gesperrt');
like(zget($depot, '/BenutzerZugang/Benutzer_ID/1')->{json}{reason} // '', qr/no access right/, 'Depotverwaltung: Adressen eines anderen Anteils gesperrt');
is(adressen(zget($orga, '/BenutzerZugang/Benutzer_ID/1')), 'anna.handy@example.org,anna.zugang@example.org', 'Orga: Adressen eines Anteils (so lädt sie members.htm)');
$vorher = anzahl_zugang();
my $mitglied = cookie_aus(login_web($WEB{anna}), 'sessionid');
is(name_von(eigene($mitglied)), 'Anna Test', 'Mitglied (Rolle 2) per Mail-Link angemeldet');
foreach my $wer ([$depot, 'Depotverwaltung'], [$mitglied, 'Mitglied']) {
	my ($sid, $rolle) = @$wer;
	my %a;
	foreach my $mail ('anna.zugang@example.org', 'gibt-es-noch-nicht@example.org') {
		$r = zpost($sid, '/BenutzerZugang', { Benutzer_ID => $sid eq $depot ? 5 : 1, Email => $mail });
		$a{ kanonisch($r->{json}) }++;
	}
	is(scalar(keys %a), 1, "$rolle: POST BenutzerZugang mit vorhandener und neuer Adresse → dieselbe Antwort");
	like((keys %a)[0], qr/no access right/, "… nämlich „no access right“");
	like(zpost($sid, "/BenutzerZugang/$ze", { Email => 'umgebogen@example.org' })->{json}{reason} // '', qr/no access right/, "$rolle: ändern gesperrt");
	like(zdel($sid, "/BenutzerZugang/$ze")->{json}{reason} // '', qr/no access right/, "$rolle: entfernen gesperrt");
	like(zdel($sid, '/BenutzerZugang/1')->{json}{reason} // '', qr/no access right/, "$rolle: entfernen einer fremden Adresse gesperrt");
}
is(anzahl_zugang(), $vorher, 'nichts eingetragen oder entfernt');
is(zeilen('SELECT Email FROM BenutzerZugang WHERE ID = ?', $ze), 'erik@example.org', '… und nichts geändert');

note('13 Einmal-Skript model/BenutzerZugangFuellen.pl');
# Adressprüfung: Was SolawiSitzung::email_normal (und damit members.htm und das Skript) annimmt, nimmt auch die Website an.
# Dazu dieselbe Funktion wie mg_email_normal() in mitglieder/_intern/tuer.php der Website.
require SolawiSitzung;
my @proben = ('Anna.Zugang@Example.org', ' a.b-c+tag@sub.example.co.uk ', 'x_y@xn--mller-kva.de', "o'brien\@example.org",
	'a..b@example.org', '.a@example.org', 'a.@example.org', 'a@b', 'a@b.c', 'a@-b.org', 'a@b-.org', 'a@b.123', 'a b@example.org',
	"m\x{fc}ller\@example.org", 'a@example.org.', '"a"@example.org', 'a@[127.0.0.1]', 'a@localhost', ('a' x 64) . '@example.org',
	('a' x 65) . '@example.org', 'a@' . ('b' x 63) . '.org', 'a@' . ('b' x 64) . '.org', 'a@' . join('.', ('b' x 60) x 4) . '.org',
	'ä@example.org', 'a@exämple.org', 'A@EXAMPLE.ORG', "a\@example.org\n", 'a=b@example.org', 'a#b@example.org', 'a{b}@example.org');
open(my $php_mg, '>', "$TMP/mg_email_normal.php") or die $!;
print $php_mg <<'PHP';
<?php
function mg_email_normal(string $roh): string
{
    $e = strtolower(trim($roh));
    if ($e === '' || strlen($e) > 254 || preg_match('/[\s<>"\'\\\\,;:()]/', $e) === 1) {
        return '';
    }
    return filter_var($e, FILTER_VALIDATE_EMAIL) !== false ? $e : '';
}
while (($z = fgets(STDIN)) !== false) {
    echo mg_email_normal(base64_decode(trim($z))), "\n";
}
PHP
close($php_mg);
require MIME::Base64;
my $pid_php = open3(my $php_ein, my $php_aus, undef, $PHP, "$TMP/mg_email_normal.php");
binmode($php_ein, ':raw');
print $php_ein MIME::Base64::encode_base64(Encode::encode('UTF-8', $_), '') . "\n" foreach @proben;
close($php_ein);
my @php_ergebnis = map { chomp; $_ } <$php_aus>;
waitpid($pid_php, 0);
my (@abweichend, $angenommen);
foreach my $i (0 .. $#proben) {
	my $perl = SolawiSitzung::email_normal($proben[$i]);
	$angenommen++ if $perl ne '';
	push(@abweichend, "$i: perl='$perl' php='" . ($php_ergebnis[$i] // '?') . "'") if $perl ne '' && $perl ne ($php_ergebnis[$i] // '');
}
is(scalar(@php_ergebnis), scalar(@proben), 'PHP hat alle Proben geprüft');
is(join('; ', @abweichend), '', "Jede Adresse, die das Bestellsystem annimmt, nimmt auch die Website an, gleich geschrieben ($angenommen von " . scalar(@proben) . ' Proben angenommen)');
is(SolawiSitzung::email_normal(' Anna.Zugang@Example.org '), 'anna.zugang@example.org', 'email_normal: getrimmt, Kleinbuchstaben');
is(SolawiSitzung::email_normal('a@' . join('.', ('b' x 60) x 4) . '.org'), 'a@' . join('.', ('b' x 60) x 4) . '.org', 'email_normal: 249 Zeichen gehen');

# Anteile und WordPress-Konten für das Skript (erfunden):
#   Gina  Depot „Geloescht“ (0), wpID 106                → übersprungen
#   Hans  wpID 107, Konto nicht freigeschaltet           → keine Adresse
#   Ida   wpID 108, Konto fehlt in WordPress             → keine Adresse
#   Jo    wpID 109, Adresse ungültig                     → keine Adresse
#   Kai   wpID 110 und wpMitID 111 mit derselben Adresse in anderer Schreibweise → eine Zeile, „Hauptmitglied“
#   Lena  wpID 112, wpMit2ID 113, wpMit3ID 114           → drei Zeilen, Mit-Mitglieder als „Mit-Mitglied“
#   WordPress 115 (Olaf) freigeschaltet, an keinem Anteil → gezählt („onlyWP“); 116 (Paul) an keinem Anteil, nicht freigeschaltet
#   → nicht gezählt (steht auch heute nicht in der Mitgliederliste der Website); Gina 106 freigeschaltet, nur am gelöschten Anteil
# Dazu von früher: Anna 101 (Hauptmitglied) und 102 (Mit-Mitglied), Bert 103, Dora 104 auch wpMit2ID bei Bert (mehrdeutig),
# Carla 105, Erik und Fritz ohne WordPress. Schon in BenutzerZugang: Annas Adresse aus WordPress (schon da) und Carlas Adresse
# aus WordPress, aber bei Dora (bleibt dort).
$db->do("SET SESSION sql_mode = 'NO_AUTO_VALUE_ON_ZERO'");
$db->do("INSERT INTO Depot (ID, Name) VALUES (0, 'Geloescht')");
$db->do("INSERT INTO Benutzer (ID, Name, Passwort, Cookie, Role_ID, Depot_ID, wpID, wpMitID) VALUES
	(7,'Gina Weg','','',2,0,106,NULL),(8,'Hans Inaktiv','','',2,1,107,NULL),(9,'Ida Ohne','','',2,1,108,NULL),(10,'Jo Kaputt','','',2,1,109,NULL),
	(11,'Kai Doppelt','','',2,1,110,111)");
$db->do("INSERT INTO Benutzer (ID, Name, Passwort, Cookie, Role_ID, Depot_ID, wpID, wpMitID, wpMit2ID, wpMit3ID) VALUES (12,'Lena Drei','','',2,1,112,NULL,113,114)");
$db->do("SET SESSION sql_mode = DEFAULT");
$wp->do("INSERT INTO wp_users (ID, user_login, user_pass, user_email) VALUES (106,'Gina','x','gina\@example.org'),(107,'Hans','x','hans\@example.org'),
	(109,'Jo','x','kaputt'),(110,'Kai','x','kai\@example.org'),(111,'Kai2','x','KAI\@Example.org '),(112,'Lena','x','lena\@example.org'),
	(113,'Lena2','x','lena-mit2\@example.org'),(114,'Lena3','x','lena-mit3\@example.org'),(115,'Olaf','x','olaf\@example.org'),(116,'Paul','x','paul\@example.org')");
$wp->do("INSERT INTO wp_usermeta (user_id, meta_key, meta_value) VALUES (106,'account_status','approved'),(107,'account_status','inactive'),
	(109,'account_status','approved'),(110,'account_status','approved'),(111,'account_status','approved'),(110,'first_name','Kai'),
	(112,'account_status','approved'),(113,'account_status','approved'),(114,'account_status','approved'),(115,'account_status','approved'),
	(116,'account_status','awaiting_admin_review')");
zugang_setzen([1, 1, 'anna@example.org', 'von Hand'], [2, 4, 'carla-wp@example.org', 'von Hand']);
my $CNF = "$TMP/mysql-test.cnf";
open(my $cnf, '>', $CNF) or die $!;
print $cnf "[client]\nuser=root\nsocket=$SOCK\n";
close($cnf);
sub fuellen {
	my (@arg) = @_;
	my $fehler = gensym;
	my $pid = open3(my $ein, my $aus, $fehler, $^X, "$REPO/model/BenutzerZugangFuellen.pl", @arg);
	close($ein);
	my $o = Encode::decode('UTF-8', do { local $/; <$aus> } // '');
	my $e = Encode::decode('UTF-8', do { local $/; <$fehler> } // '');
	waitpid($pid, 0);
	my %z;
	@z{qw(anteile geloescht)} = $o =~ /^Anteile:\s+(\d+)\s+\(dazu (\d+)/m;
	@z{qw(konten nicht_frei fehlen ungueltig)} = $o =~ /^WordPress-Konten verknüpft:\s+(\d+)\s+\(nicht freigeschaltet (\d+), fehlen in WordPress (\d+), ohne gültige Adresse (\d+)/m;
	($z{neu}) = $o =~ /^Adressen neu:\s+(\d+)/m;
	($z{eingetragen}) = $o =~ /eingetragen: (\d+)\)/;
	($z{schon_da}) = $o =~ /^Adressen schon da:\s+(\d+)/m;
	($z{anderswo}) = $o =~ /^Adressen bei anderem Anteil:\s+(\d+)/m;
	($z{mehrdeutig}) = $o =~ /^Adressen mehrdeutig:\s+(\d+)/m;
	($z{ohne}) = $o =~ /^Anteile ohne Adresse danach:\s+(\d+)/m;
	@z{qw(frei_ohne frei_ohne_anteil frei_nur_geloescht)} = $o =~ /^Freigeschaltet, ohne Anteil:\s+(\d+)\s+\(an keinem Anteil (\d+), in members.htm „onlyWP“; nur an Anteilen im Depot „Geloescht“ (\d+)\)/m;
	delete $z{eingetragen} unless defined $z{eingetragen};
	return { code => $? >> 8, aus => $o, fehler => $e, zahlen => \%z };
}
my @namen = map { $_->[0] } @{ $db->selectall_arrayref('SELECT Name FROM Benutzer') };
sub verraet { my ($t) = @_; return join(',', ($t =~ /(\S*\@\S*)/g), grep { index($t, $_) >= 0 || index($t, (split(/ /, $_))[0]) >= 0 } @namen); }
sub stand { return [sort { $a->[1] cmp $b->[1] } @{ $db->selectall_arrayref('SELECT Benutzer_ID, Email, Bezeichnung FROM BenutzerZugang') }]; }
my %erwartet = (anteile => 11, geloescht => 1, konten => 13, nicht_frei => 1, fehlen => 1, ungueltig => 1, neu => 6, schon_da => 1,
	anderswo => 1, mehrdeutig => 1, ohne => 6, frei_ohne => 2, frei_ohne_anteil => 1, frei_nur_geloescht => 1);

my $vorher_stand = stand();
my $f = fuellen('--bs-cnf', $CNF, '--wp-cnf', $CNF);
is($f->{code}, 0, 'Trockenlauf: läuft durch') or diag($f->{fehler});
note("  $_") foreach split(/\n/, $f->{aus});
like($f->{aus}, qr/Trockenlauf, es wird nichts geändert/, '… und sagt, dass es ein Trockenlauf ist');
is_deeply($f->{zahlen}, \%erwartet, '… Zahlen: 11 Anteile (1 gelöscht), 13 Konten (1 nicht frei, 1 fehlt, 1 ungültig), 6 neu, 1 schon da, 1 anderswo, 1 mehrdeutig, 6 Anteile ohne Adresse, 2 freigeschaltete Konten ohne Anteil (1 keiner, 1 nur gelöscht)');
is_deeply(stand(), $vorher_stand, '… BenutzerZugang unverändert');
is(verraet($f->{aus} . $f->{fehler}), '', '… keine Adresse und kein Name in der Ausgabe');

$f = fuellen('--bs-cnf', $CNF, '--wp-cnf', $CNF, '--echt');
is($f->{code}, 0, 'echter Lauf: läuft durch') or diag($f->{fehler});
is_deeply($f->{zahlen}, { %erwartet, eingetragen => 6 }, '… dieselben Zahlen, 6 eingetragen');
is_deeply(stand(), [[1, 'anna@example.org', 'von Hand'], [2, 'bert@example.org', 'Hauptmitglied'], [4, 'carla-wp@example.org', 'von Hand'],
	[11, 'kai@example.org', 'Hauptmitglied'], [12, 'lena-mit2@example.org', 'Mit-Mitglied'], [12, 'lena-mit3@example.org', 'Mit-Mitglied'],
	[12, 'lena@example.org', 'Hauptmitglied'], [1, 'mit-anna@example.org', 'Mit-Mitglied']],
	'… eingetragen: Bert, Kai (einmal, Hauptmitglied), Lena mit Mit-Mitgliedern aus wpMit2ID und wpMit3ID, Annas Mit-Mitglied (wpMitID); Dora (mehrdeutig), Gina, Hans, Ida, Jo, Olaf, Paul nicht; vorhandene Zeilen unverändert');
is(verraet($f->{aus} . $f->{fehler}), '', '… keine Adresse und kein Name in der Ausgabe');

$f = fuellen('--bs-cnf', $CNF, '--wp-cnf', $CNF, '--echt');
is_deeply($f->{zahlen}, { %erwartet, neu => 0, schon_da => 7, eingetragen => 0 }, 'zweiter echter Lauf: nichts neu, 7 schon da (idempotent)');
is(scalar(@{ stand() }), 8, '… keine Zeile doppelt, keine gelöscht');

$r = login_web($WEB{annawp});
is($r->{json}{user}, 'Anna Test', 'nach dem Füllen: Annas WordPress-Adresse meldet über BenutzerZugang an');
ok(zeilen('SELECT BenutzerZugang_ID IS NOT NULL FROM BenutzerSitzung WHERE IDHash = SHA2(?, 256)', cookie_aus($r, 'sessionid')), '… Sitzung mit Zugang');
is(login_web($WEB{mitanna})->{json}{user}, 'Anna Test', '… ebenso ihr Mit-Mitglied (wpMitID)');
is(login_web($WEB{lenamit3})->{json}{user}, 'Lena Drei', '… und Lenas Mit-Mitglied (wpMit3ID)');
is(login_web($WEB{dora})->{json}{result}, 'not logged in on website', '… die mehrdeutige Adresse nicht (die Mitgliederverwaltung trägt sie beim richtigen Anteil ein)');

$f = fuellen('--bs-cnf', "$TMP/gibt-es-nicht.cnf", '--wp-cnf', $CNF);
isnt($f->{code}, 0, 'Optionsdatei fehlt → Abbruch');
open($cnf, '>', "$TMP/falsch.cnf") or die $!;
print $cnf "[client]\nuser=niemand\npassword=falsch\nsocket=$SOCK\n";
close($cnf);
$f = fuellen('--bs-cnf', "$TMP/falsch.cnf", '--wp-cnf', $CNF, '--echt');
isnt($f->{code}, 0, 'falsche Zugangsdaten → Abbruch');
like($f->{fehler}, qr/Keine Verbindung zu db208674_361/, '… mit Hinweis, welche Datenbank');
is(scalar(@{ stand() }), 8, '… und nichts geändert');
zugang_setzen(@ZUGANG_START);

# =====================================================================================================================
if ($WEB) {
	note("14 Gegen die echte Brücke der Website ($WEB)");
	require Digest::SHA;
	my $www = "$TMP/web/mitglieder/_intern";
	system('mkdir', '-p', $www) == 0 or die;
	foreach my $f ('tuer.php', 'versand.php', 'bestellsystem.php') {
		system('cp', "$WEB/mitglieder/_intern/$f", "$www/$f") == 0 or BAIL_OUT("$WEB/mitglieder/_intern/$f fehlt");
	}
	my $daten = "$TMP/webdaten";
	mkdir($daten, 0700) or die;
	mkdir("$daten/mg-sitzungen", 0700) or die;
	open(my $o, '>', "$www/ort.php") or die;
	print $o "<?php\nreturn ['daten' => '$daten', 'dokumente' => '', 'vorschau' => false];\n";
	close($o);
	my $haupt = join('', map { sprintf('%02x', int(rand(256))) } 1 .. 32);
	open(my $s, '>', "$daten/schluessel") or die;
	print $s "$haupt\n";
	close($s);
	my $k = sub { Digest::SHA::hmac_sha256($_[0], pack('H*', $haupt)) };       # mg_schluessel($zweck)
	my $kennung = sub { Digest::SHA::hmac_sha256_hex($_[1], $k->($_[0])) };   # mg_kennung($zweck, $wert)
	my $mitglied = sub { Digest::SHA::hmac_sha256_hex(lc($_[0]), $k->('mitglied')) };
	my @adressen = ('anna.zugang@example.org', 'anna.handy@example.org', 'anna@example.org', 'dora@example.org', 'carla@example.org');
	open(my $l, '>', "$daten/mitglieder.txt") or die;
	print $l '#k:' . substr($kennung->('liste', 'mitglieder'), 0, 16) . "\n", map { $mitglied->($_) . "\n" } sort @adressen;
	close($l);
	my %echt;
	foreach my $wer (['anna', 'anna.zugang@example.org'], ['dora', 'dora@example.org'], ['raus', 'niemand@example.org']) {
		my $sid = join('', map { ('A' .. 'Z', 'a' .. 'z', 0 .. 9, '-', '_')[int(rand(64))] } 1 .. 43);
		open(my $f, '>', "$daten/mg-sitzungen/" . $kennung->('mg-sitzung', $sid) . '.json') or die;
		print $f encode_json({ m => $mitglied->($wer->[1]), bis => time() + 14 * 86400 });
		close($f);
		$echt{ $wer->[0] } = $sid;
	}
	my $B = "$www/bestellsystem.php";
	$r = login_web($echt{anna}, bruecke => $B);
	is($r->{json}{user}, 'Anna Test', 'echte Brücke: Anmeldung der Website → Anna');
	my $sidE = cookie_aus($r, 'sessionid');
	is(name_von(eigene($sidE)), 'Anna Test', 'echte Brücke: Sitzung gilt in resql.pl');
	is(login_web($echt{dora}, bruecke => $B)->{json}{result}, 'not logged in on website', 'echte Brücke: Adresse nur in WordPress, BenutzerZugang hat Einträge → keine Sitzung');
	zugang_setzen();
	is(login_web($echt{dora}, bruecke => $B)->{json}{result}, 'mehrdeutig', 'echte Brücke, BenutzerZugang leer (Übergang): mehrdeutig');
	zugang_setzen(@ZUGANG_START);
	$r = login_web($echt{anna}, bruecke => $B);
	$sidE = cookie_aus($r, 'sessionid');
	is(name_von(eigene($sidE)), 'Anna Test', 'echte Brücke: wieder angemeldet (Sitzungen über BenutzerZugang endeten beim Leeren)');
	is(login_web($echt{raus}, bruecke => $B)->{json}{result}, 'not logged in on website', 'echte Brücke: Adresse nicht in der Mitgliederliste → keine Sitzung');
	is(login_web(keks('unbekannt'), bruecke => $B)->{json}{result}, 'not logged in on website', 'echte Brücke: unbekanntes Cookie');
	my $vorher = () = glob("$daten/mg-sitzungen/*.json");
	$r = cgi(skript => 'wp', methode => 'POST', pfad => '/logout', body => {}, cookies => { sessionid => $sidE, mg_s => $echt{anna} }, bruecke => $B);
	my $nachher = () = glob("$daten/mg-sitzungen/*.json");
	is($nachher, $vorher - 1, 'echte Brücke: logout beendet die Anmeldung der Website (Sitzungsdatei weg)');
	is(login_web($echt{anna}, bruecke => $B)->{json}{result}, 'not logged in on website', 'echte Brücke: danach keine Übernahme mehr');
	my @alle = glob("$daten/mg-sitzungen/*.json");
	ok(!(grep { open(my $x, '<', $_); my $t = do { local $/; <$x> }; $t =~ /@/ } @alle), 'echte Brücke: keine Mailadresse im Datenordner');
}

done_testing();
