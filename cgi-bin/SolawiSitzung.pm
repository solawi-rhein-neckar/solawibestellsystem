package SolawiSitzung;
use strict;
use warnings;

#
# Sitzungen des Bestellsystems und Anmeldung über die Website (Mail-Link), Webteam 11.11.2026.
#
# - Eine Zeile in BenutzerSitzung je Gerät: Handy, Computer und Mit-Mitglied bleiben gleichzeitig angemeldet
#   (vorher überschrieb jeder Login Benutzer.Cookie und meldete die anderen ab).
# - Das Cookie "sessionid" trägt 32 Zufallsbytes aus /dev/urandom (statt rand()), in der Datenbank steht nur SHA2(ID, 256).
#   HttpOnly, Secure, SameSite=Lax, Path=/.
# - Anmeldung über die Website: Wer auf www.solawi-rhein-neckar.org/anmelden/ per Mail-Link angemeldet ist, hat das Cookie mg_s.
#   login_web() fragt per open2 die Website (mitglieder/_intern/bestellsystem.php, PHP), ob die Anmeldung gilt und zu welcher
#   der mitgeschickten Adressen sie gehört. Adressen und Cookie gehen über stdin, nichts über die Kommandozeile.
# - Übergang: Sitzungen aus dem Passwort-Login (Benutzer.Cookie, rand()) gelten weiter, bis der Passwort-Login abgeschaltet wird.
#
# Kein Modul außer Perl-Kern und DBI (Digest::SHA fehlt auf dem Server, deshalb rechnet MySQL die Prüfsummen).
#

use IPC::Open2;

# PHP auf dem Server und die Brücke der Website (liegt im Mitgliederbereich, ist über den Webserver gesperrt)
our $PHP    = '/usr/bin/php74';
our $BRUECKE = '/kunden/208674_69115/rp-hosting/0051/0062/www/solawi-rhein-neckar.org/mitglieder/_intern/bestellsystem.php';

our $COOKIE     = 'sessionid';
our $WEB_COOKIE = 'mg_s';
our $PW_TAGE    = 14;    # Lebensdauer einer Sitzung aus dem Passwort-Login (Mail-Link: so lange wie die Anmeldung der Website)

# Tabellen, die resql.pl nicht frei herausgibt (siehe tabelle_erlaubt)
our $T_SITZUNG = 'BenutzerSitzung';
our $T_ZUGANG  = 'BenutzerZugang';

# 64 Hex-Zeichen aus /dev/urandom
sub neue_id {
	open(my $fh, '<:raw', '/dev/urandom') or die "SolawiSitzung: /dev/urandom nicht lesbar\n";
	my $n = read($fh, my $bytes, 32);
	close($fh);
	die "SolawiSitzung: zu wenig Zufall\n" unless defined $n && $n == 32;
	return unpack('H*', $bytes);
}

# Wert eines Cookies aus der Anfrage (HTTP_COOKIE), ohne CGI-Modul: CGI::Simple::Cookie->fetch reicht auch, hier geht es auch ohne $q
sub cookie_wert {
	my ($name) = @_;
	my $roh = $ENV{HTTP_COOKIE};
	return undef unless defined $roh;
	foreach my $teil (split(/;\s*/, $roh)) {
		my ($k, $v) = split(/=/, $teil, 2);
		next unless defined $k && defined $v;
		$k =~ s/^\s+|\s+$//g;
		if ($k eq $name) {
			$v =~ s/%([0-9A-Fa-f]{2})/chr(hex($1))/ge;
			return $v;
		}
	}
	return undef;
}

# Set-Cookie-Zeile für sessionid; $sekunden < 0 löscht
sub cookie_kopf {
	my ($name, $wert, $sekunden, $pfad) = @_;
	$pfad = '/' unless defined $pfad;
	if ($sekunden < 0) {
		return "$name=deleted; Path=$pfad; Expires=Thu, 01 Jan 1970 00:00:01 GMT; Max-Age=0; Secure; HttpOnly; SameSite=Lax";
	}
	return "$name=$wert; Path=$pfad; Max-Age=$sekunden; Secure; HttpOnly; SameSite=Lax";
}

# Angemeldeten Benutzer zur Anfrage holen (Zeile aus Benutzer als Hashref) oder undef.
# Neue Sitzungen (64 Hex-Zeichen) über BenutzerSitzung, alte aus dem Passwort-Login über Benutzer.Cookie (Übergang).
sub benutzer {
	my ($dbh, $wert) = @_;
	$wert = cookie_wert($COOKIE) unless defined $wert;
	# nur echte IDs: 64 hex (BenutzerSitzung) oder das Format von rand() (Passwort-Login). Ein leerer Wert oder ein
	# Leerzeichen träfe sonst jedes leere Benutzer.Cookie (MySQL vergleicht ' ' und '' als gleich).
	return undef unless defined $wert && $wert =~ /^(?:[0-9a-f]{64}|[0-9][0-9.e-]{7,40})$/;
	if ($wert =~ /^[0-9a-f]{64}$/) {
		my $st = $dbh->prepare("SELECT `ID`, `Benutzer_ID`, (`ZuletztGesehen` < NOW() - INTERVAL 1 HOUR) AS `alt` FROM `$T_SITZUNG` WHERE `IDHash` = SHA2(?, 256) AND `GueltigBis` > NOW()");
		$st->execute($wert);
		my $s = $st->fetchrow_hashref;
		$st->finish;
		return undef unless $s;
		if ($s->{alt}) {
			$dbh->prepare("UPDATE `$T_SITZUNG` SET `ZuletztGesehen` = NOW() WHERE `ID` = ?")->execute($s->{ID});
			$dbh->commit();
		}
		my $sb = $dbh->prepare("SELECT * FROM `Benutzer` WHERE `ID` = ?");
		$sb->execute($s->{Benutzer_ID});
		my $user = $sb->fetchrow_hashref;
		$sb->finish;
		return $user;
	}
	# Übergang: Sitzung aus dem Passwort-Login (wp.pl/resql.pl schreiben Benutzer.Cookie wie bisher)
	my $st = $dbh->prepare("SELECT * FROM `Benutzer` WHERE `Cookie` = ?");
	$st->execute($wert);
	my $user = $st->fetchrow_hashref;
	$st->finish;
	return $user;
}

# Neue Sitzung anlegen, gibt die ID (für das Cookie) zurück. $bis = Unix-Zeit des Endes. Räumt abgelaufene Sitzungen ab.
sub anlegen {
	my ($dbh, $benutzer_id, $zugang_id, $bis) = @_;
	my $id = neue_id();
	$dbh->prepare("DELETE FROM `$T_SITZUNG` WHERE `GueltigBis` < NOW()")->execute();
	$dbh->prepare("INSERT INTO `$T_SITZUNG` (`Benutzer_ID`, `BenutzerZugang_ID`, `IDHash`, `Erstellt`, `ZuletztGesehen`, `GueltigBis`) VALUES (?, ?, SHA2(?, 256), NOW(), NOW(), FROM_UNIXTIME(?))")
		->execute($benutzer_id, ($zugang_id ? $zugang_id : undef), $id, $bis);
	$dbh->commit();
	return $id;
}

# Sitzung zur Anfrage beenden (neue: Zeile löschen, alte: Benutzer.Cookie leeren)
sub beenden {
	my ($dbh, $wert) = @_;
	$wert = cookie_wert($COOKIE) unless defined $wert;
	return unless defined $wert && $wert ne '';
	if ($wert =~ /^[0-9a-f]{64}$/) {
		$dbh->prepare("DELETE FROM `$T_SITZUNG` WHERE `IDHash` = SHA2(?, 256)")->execute($wert);
	} else {
		$dbh->prepare("UPDATE `Benutzer` SET `Cookie` = '' WHERE `Cookie` = ?")->execute($wert);
	}
	$dbh->commit();
}

# Adressen, die das Bestellsystem kennt: [zugang_id, benutzer_id, email], BenutzerZugang zuerst.
# Übergang ($dbh_wp gesetzt): dazu die Adressen aus wp_users, zugeordnet über wpID/wpMitID/wpMit2ID/wpMit3ID (zugang_id 0).
sub kandidaten {
	my ($dbh, $dbh_wp) = @_;
	my @k;
	my $st = $dbh->prepare("SELECT `ID`, `Benutzer_ID`, `Email` FROM `$T_ZUGANG`");
	$st->execute();
	while (my $r = $st->fetchrow_arrayref) {
		push(@k, [$r->[0], $r->[1], $r->[2]]);
	}
	if ($dbh_wp) {
		my %anteil;    # wp_users.ID -> [Benutzer.ID, ...]
		my $sb = $dbh->prepare("SELECT * FROM `Benutzer`");
		$sb->execute();
		while (my $b = $sb->fetchrow_hashref) {
			foreach my $spalte ('wpID', 'wpMitID', 'wpMit2ID', 'wpMit3ID') {
				my $wp = $b->{$spalte};
				push(@{ $anteil{$wp} }, $b->{ID}) if defined $wp && $wp =~ /^[1-9][0-9]*$/;
			}
		}
		my $sw = $dbh_wp->prepare("SELECT `ID`, `user_email` FROM `wp_users`");
		$sw->execute();
		while (my $w = $sw->fetchrow_arrayref) {
			next unless $anteil{$w->[0]} && defined $w->[1];
			push(@k, [0, $_, $w->[1]]) foreach @{ $anteil{$w->[0]} };
		}
	}
	return \@k;
}

# Brücke der Website aufrufen: Befehl, Eingabezeilen -> erste Ausgabezeile (oder '' bei Fehlern)
sub bruecke {
	my ($befehl, @zeilen) = @_;
	return '' unless -x $PHP && -r $BRUECKE;
	local $SIG{PIPE} = 'IGNORE';
	my ($aus, $ein);
	my $pid = eval { open2($aus, $ein, $PHP, $BRUECKE, $befehl) };
	return '' unless $pid;
	binmode($ein, ':raw');
	print $ein $_, "\n" foreach @zeilen;    # Zeilen sind geprüft: Cookie in fester Form, Adressen ohne Tab/Zeilenumbruch
	close($ein);
	my $ergebnis = <$aus>;
	close($aus);
	waitpid($pid, 0);
	return '' unless defined $ergebnis;
	$ergebnis =~ s/\s+$//;
	return $ergebnis;
}

# Anmeldung der Website übernehmen. Gibt { benutzer => Hashref, id => Sitzungs-ID, sekunden => Lebensdauer } zurück,
# { fehler => 'mehrdeutig' } wenn die Adresse an mehreren Anteilen hängt, sonst undef.
sub login_web {
	my ($dbh, $dbh_wp) = @_;
	my $web = cookie_wert($WEB_COOKIE);
	return undef unless defined $web && $web =~ /^[A-Za-z0-9_-]{43}$/;
	my $k = kandidaten($dbh, $dbh_wp);
	my @zeilen = ($web);
	foreach my $r (@$k) {
		my ($zid, $bid, $email) = @$r;
		next unless defined $email && $email !~ /[\t\r\n]/;
		push(@zeilen, join("\t", $zid, $bid, $email));
	}
	my $antwort = bruecke('pruefen', @zeilen);
	return { fehler => 'mehrdeutig' } if $antwort eq 'MEHRDEUTIG';
	return undef unless $antwort =~ /^OK (\d+) (\d+) (\d+)$/;
	my ($zid, $bid, $bis) = ($1, $2, $3);
	my $sekunden = $bis - time();
	return undef if $sekunden < 60;
	my $sb = $dbh->prepare("SELECT * FROM `Benutzer` WHERE `ID` = ?");
	$sb->execute($bid);
	my $user = $sb->fetchrow_hashref;
	$sb->finish;
	return undef unless $user;
	my $id = anlegen($dbh, $bid, $zid, $bis);
	return { benutzer => $user, id => $id, sekunden => $sekunden };
}

# Abmelden auf der Website mitnehmen (sonst meldet login_web gleich wieder an)
sub logout_web {
	my $web = cookie_wert($WEB_COOKIE);
	return unless defined $web && $web =~ /^[A-Za-z0-9_-]{43}$/;
	bruecke('abmelden', $web);
}

# Anfrage kommt von dieser Seite? (gegen Login-/Logout-CSRF; SameSite=Lax schützt die Cookies ohnehin)
sub herkunft_ok {
	my $site = $ENV{HTTP_SEC_FETCH_SITE};
	return 0 if defined $site && $site ne 'same-origin';
	my $origin = $ENV{HTTP_ORIGIN};
	my $host = $ENV{HTTP_HOST} || '';
	return 0 if defined $origin && $origin ne "https://$host";
	return ($ENV{HTTP_X_REQUESTED_WITH} || '') eq 'XMLHttpRequest' ? 1 : 0;
}

# Darf resql.pl diese Tabelle für diesen Benutzer und diese Methode bedienen?
# BenutzerSitzung nie (Prüfsummen der Sitzungen); BenutzerZugang (Mailadressen) für Rollen unter Orga (4) nur die eigenen Zeilen lesen.
sub tabelle_erlaubt {
	my ($user, $methode, $pfad) = @_;
	my ($tabelle) = ($pfad || '') =~ m{^/([a-zA-Z]+)};
	return 1 unless defined $tabelle;
	return 0 if lc($tabelle) eq lc($T_SITZUNG);
	if (lc($tabelle) eq lc($T_ZUGANG) && $user->{Role_ID} < 4) {
		return ($methode eq 'GET' && $pfad =~ m{^/[a-zA-Z]+/(MY|OWN)$}) ? 1 : 0;
	}
	return 1;
}

1;
