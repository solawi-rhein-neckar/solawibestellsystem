#!/usr/bin/perl
#
# BenutzerZugang einmal aus WordPress füllen (Webteam, 11/2026). Die AG führt es auf dem Server aus, von Hand, einmal nach dem
# Einspielen von model/BenutzerZugangSitzung.sql und den neuen cgi-bin-Dateien.
#
#   perl model/BenutzerZugangFuellen.pl            Trockenlauf: zählt nur, ändert nichts
#   perl model/BenutzerZugangFuellen.pl --echt     trägt die neuen Adressen ein
#
# Verbindung zu den beiden Datenbanken (Bestellsystem db208674_361, WordPress db208674_220), eins von beiden:
#   ohne Optionen       fragt die beiden Passwörter ab (ohne Echo), Benutzer = Name der Datenbank, Host --host (Standard mysql)
#   --bs-cnf <datei>    MySQL-Optionsdatei mit [client] user=… password=… host=… für das Bestellsystem
#   --wp-cnf <datei>    dasselbe für WordPress
# --cgi-bin <ordner>    wo SolawiSitzung.pm liegt (Standard: ../cgi-bin neben diesem Skript)
#
# Was es tut:
#   - Nimmt jeden Anteil (Zeile in Benutzer) außer denen im Depot „Geloescht“ (Depot_ID 0).
#   - Nimmt dessen WordPress-Konten aus wpID, wpMitID, wpMit2ID, wpMit3ID, davon nur die freigeschalteten (wp_usermeta
#     account_status = approved, wie die Mitgliederliste der Website heute), und deren Mailadresse (geprüft und geschrieben wie in
#     members.htm, SolawiSitzung::email_normal).
#   - Gehört eine Adresse zu genau einem Anteil und steht sie noch nicht in BenutzerZugang, wird sie eingetragen, mit der
#     Bezeichnung „Hauptmitglied“ (wpID) oder „Mit-Mitglied“ (wpMitID, wpMit2ID, wpMit3ID).
#   - Gehört sie zu mehreren Anteilen, wird sie nicht eingetragen, nur gezählt. Steht sie schon bei einem Anteil, bleibt sie dort.
#   - Mit-Mitglieder (wpMitID, wpMit2ID, wpMit3ID) werden genauso übernommen wie Hauptmitglieder (wpID).
#   - Zählt außerdem die freigeschalteten WordPress-Konten, die an keinem Anteil hängen (oder nur an Anteilen im Depot
#     „Geloescht“). Sie stehen heute in der Mitgliederliste der Website, aber nicht in BenutzerZugang. Die ohne Anteil stehen in
#     members.htm als Zeilen „onlyWP“, die Mitgliederverwaltung trägt die Adresse beim richtigen Anteil ein. Die an gelöschten
#     Anteilen sind meist ehemalige Mitglieder.
#   - Löscht nichts, ändert keine vorhandene Zeile. Ein zweiter Lauf trägt nichts doppelt ein.
#   - Gibt nur Zahlen aus, keine Adressen und keine Namen (auch nicht in Fehlermeldungen).
#
# Danach ordnet login/web nur noch über BenutzerZugang zu (SolawiSitzung::kandidaten). Die Anteile, die ohne Adresse bleiben, zeigt
# members.htm mit „!KEIN_ZUGANG!“ in der Spalte NOTES.
#
use strict;
use warnings;
use utf8;
use DBI;
use File::Basename qw(dirname);
use Getopt::Long;

binmode(STDOUT, ':encoding(UTF-8)');
binmode(STDERR, ':encoding(UTF-8)');

my $DB_BS = 'db208674_361';
my $DB_WP = 'db208674_220';
my %WP_SPALTE = (wpID => 'Hauptmitglied', wpMitID => 'Mit-Mitglied', wpMit2ID => 'Mit-Mitglied', wpMit3ID => 'Mit-Mitglied');

my ($echt, $bs_cnf, $wp_cnf, $host, $cgi_bin, $hilfe) = (0, undef, undef, 'mysql', dirname(__FILE__) . '/../cgi-bin', 0);
GetOptions('echt' => \$echt, 'bs-cnf=s' => \$bs_cnf, 'wp-cnf=s' => \$wp_cnf, 'host=s' => \$host, 'cgi-bin=s' => \$cgi_bin,
	'hilfe|help' => \$hilfe) or exit(2);
if ($hilfe) {
	print "Aufruf: perl model/BenutzerZugangFuellen.pl [--echt] [--bs-cnf datei --wp-cnf datei | --host name] [--cgi-bin ordner]\n";
	exit(0);
}
unshift(@INC, $cgi_bin);
eval { require SolawiSitzung; 1 } or do { print STDERR "SolawiSitzung.pm nicht gefunden in $cgi_bin (--cgi-bin angeben)\n"; exit(2); };

sub passwort {
	my ($wofuer) = @_;
	die "Kein Terminal für die Passwortabfrage: --bs-cnf und --wp-cnf angeben\n" unless -t STDIN;
	print STDERR "Passwort für $wofuer: ";
	system('stty', '-echo');
	my $p = <STDIN>;
	system('stty', 'echo');
	print STDERR "\n";
	chomp($p) if defined $p;
	return $p;
}

sub verbinden {
	my ($db, $cnf) = @_;
	my %opt = (RaiseError => 1, PrintError => 0, AutoCommit => 0, mysql_enable_utf8mb4 => 1);
	my $dbh;
	if ($cnf) {
		die "$cnf ist nicht lesbar\n" unless -r $cnf;
		$dbh = eval { DBI->connect("DBI:mysql:database=$db;mysql_read_default_file=$cnf;mysql_read_default_group=client", undef, undef, \%opt) };
	} else {
		my $pw = passwort($db);
		$dbh = eval { DBI->connect("DBI:mysql:database=$db;host=$host", $db, $pw, \%opt) };
	}
	die "Keine Verbindung zu $db (" . ($DBI::err || '?') . ")\n" unless $dbh;
	return $dbh;
}

my ($bs, $wp) = eval { (verbinden($DB_BS, $bs_cnf), verbinden($DB_WP, $wp_cnf)) };
if (!$bs || !$wp) {
	print STDERR $@ || "Keine Verbindung\n";
	exit(1);
}

my %z = map { $_ => 0 } qw(anteile geloescht konten fehlen nicht_frei ungueltig neu schon_da anderswo mehrdeutig ohne eingetragen
	frei_ohne_anteil frei_nur_geloescht);
my %verweise;    # wp_users.ID -> [[Benutzer.ID, Bezeichnung], ...]
my %verweise_geloescht;    # wp_users.ID -> 1, für Anteile im Depot „Geloescht“
my @aktiv;
my $ok = eval {
	# Anteile und ihre WordPress-Konten
	my $sb = $bs->prepare("SELECT `ID`, `Depot_ID`, `wpID`, `wpMitID`, `wpMit2ID`, `wpMit3ID` FROM `Benutzer`");
	$sb->execute();
	while (my $b = $sb->fetchrow_hashref) {
		if (defined $b->{Depot_ID} && $b->{Depot_ID} == 0) {
			$z{geloescht}++;
			foreach my $spalte (qw(wpID wpMitID wpMit2ID wpMit3ID)) {
				$verweise_geloescht{ $b->{$spalte} } = 1 if defined $b->{$spalte} && $b->{$spalte} =~ /^[1-9][0-9]*$/;
			}
			next;
		}
		push(@aktiv, $b->{ID});
		foreach my $spalte (qw(wpID wpMitID wpMit2ID wpMit3ID)) {
			my $w = $b->{$spalte};
			push(@{ $verweise{$w} }, [$b->{ID}, $WP_SPALTE{$spalte}]) if defined $w && $w =~ /^[1-9][0-9]*$/;
		}
	}
	$z{anteile} = scalar(@aktiv);
	$z{konten} = scalar(keys %verweise);

	# freigeschaltete WordPress-Konten und ihre Adressen
	my %frei;
	my $sf = $wp->prepare("SELECT `user_id` FROM `wp_usermeta` WHERE `meta_key` = 'account_status' AND `meta_value` = 'approved'");
	$sf->execute();
	while (my ($u) = $sf->fetchrow_array) { $frei{$u} = 1; }
	my %adresse;     # email -> {Benutzer.ID -> Bezeichnung}
	my %gefunden;
	my $sw = $wp->prepare("SELECT `ID`, `user_email` FROM `wp_users`");
	$sw->execute();
	while (my ($wid, $mail) = $sw->fetchrow_array) {
		if (!$verweise{$wid}) {
			# freigeschaltet, aber an keinem aktiven Anteil: steht heute in der Mitgliederliste der Website
			$z{ $verweise_geloescht{$wid} ? 'frei_nur_geloescht' : 'frei_ohne_anteil' }++ if $frei{$wid};
			next;
		}
		$gefunden{$wid} = 1;
		if (!$frei{$wid}) {
			$z{nicht_frei}++;
			next;
		}
		my $e = SolawiSitzung::email_normal($mail);
		if ($e eq '') {
			$z{ungueltig}++;
			next;
		}
		foreach my $v (@{ $verweise{$wid} }) {
			my ($bid, $bez) = @$v;
			# Hauptmitglied vor Mit-Mitglied, wenn dieselbe Adresse an einem Anteil zweimal hängt
			$adresse{$e}{$bid} = $bez unless defined $adresse{$e}{$bid} && $adresse{$e}{$bid} eq 'Hauptmitglied';
		}
	}
	$z{fehlen} = scalar(grep { !$gefunden{$_} } keys %verweise);

	# was schon in BenutzerZugang steht
	my %vorhanden;    # email -> Benutzer.ID
	my %hat;          # Benutzer.ID -> 1
	my $sz = $bs->prepare("SELECT `Benutzer_ID`, `Email` FROM `BenutzerZugang`");
	$sz->execute();
	while (my ($bid, $mail) = $sz->fetchrow_array) {
		$vorhanden{lc($mail)} = $bid;
		$hat{$bid} = 1;
	}

	my @neu;
	foreach my $e (sort keys %adresse) {
		my @anteile = sort { $a <=> $b } keys %{ $adresse{$e} };
		if (@anteile > 1) {
			$z{mehrdeutig}++;
		} elsif (exists $vorhanden{$e}) {
			$z{ $vorhanden{$e} == $anteile[0] ? 'schon_da' : 'anderswo' }++;
		} else {
			$z{neu}++;
			push(@neu, [$anteile[0], $e, $adresse{$e}{ $anteile[0] }]);
			$hat{ $anteile[0] } = 1;
		}
	}
	$z{ohne} = scalar(grep { !$hat{$_} } @aktiv);

	if ($echt && @neu) {
		$bs->do("SET \@zaudit_user = 'BenutzerZugangFuellen'");    # für die Audit-Trigger, falls es welche gibt
		my $st = $bs->prepare("INSERT INTO `BenutzerZugang` (`Benutzer_ID`, `Email`, `Bezeichnung`, `AenderBenutzer_ID`) VALUES (?, ?, ?, NULL)");
		$st->execute(@$_) foreach @neu;
		$bs->commit();
		$z{eingetragen} = scalar(@neu);
	} else {
		$bs->rollback();
	}
	1;
};
if (!$ok) {
	# Fehlermeldungen von MySQL können Adressen enthalten (z. B. "Duplicate entry …"): nur den Fehlercode ausgeben
	my $code = $DBI::err || '?';
	eval { $bs->rollback() };
	print STDERR "Abgebrochen, nichts geändert (MySQL-Fehler $code).\n";
	exit(1);
}
$bs->disconnect();
$wp->disconnect();

printf("BenutzerZugang aus WordPress füllen – %s\n", $echt ? 'ECHTER LAUF' : 'Trockenlauf, es wird nichts geändert');
printf("Anteile:                      %5d  (dazu %d im Depot „Geloescht“, übersprungen)\n", $z{anteile}, $z{geloescht});
printf("WordPress-Konten verknüpft:   %5d  (nicht freigeschaltet %d, fehlen in WordPress %d, ohne gültige Adresse %d)\n",
	$z{konten}, $z{nicht_frei}, $z{fehlen}, $z{ungueltig});
printf("Adressen neu:                 %5d  %s\n", $z{neu}, $echt ? "(eingetragen: $z{eingetragen})" : '(würden eingetragen)');
printf("Adressen schon da:            %5d\n", $z{schon_da});
printf("Adressen bei anderem Anteil:  %5d  (stehen schon bei einem anderen Anteil, bleiben dort)\n", $z{anderswo});
printf("Adressen mehrdeutig:          %5d  (gehören zu mehreren Anteilen, nicht eingetragen)\n", $z{mehrdeutig});
printf("Anteile ohne Adresse danach:  %5d  (in members.htm „!KEIN_ZUGANG!“)\n", $z{ohne});
printf("Freigeschaltet, ohne Anteil:  %5d  (an keinem Anteil %d, in members.htm „onlyWP“; nur an Anteilen im Depot „Geloescht“ %d)\n",
	$z{frei_ohne_anteil} + $z{frei_nur_geloescht}, $z{frei_ohne_anteil}, $z{frei_nur_geloescht});
print "Für den echten Lauf: --echt\n" unless $echt;
exit(0);
