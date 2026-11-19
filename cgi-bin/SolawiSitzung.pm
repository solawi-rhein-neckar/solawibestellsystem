package SolawiSitzung;
use strict;
use warnings;
use utf8; # Meldungen mit Umlauten (resql.pl gibt sie als JSON aus)

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
# - Mailadressen je Anteil stehen in BenutzerZugang. Orga und Admin pflegen sie in members.htm (resql.pl -> zugang_schreiben).
#   WordPress zählt für die Anmeldung nur noch, solange BenutzerZugang leer ist (kandidaten).
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

# Adressen, die das Bestellsystem kennt: [zugang_id, benutzer_id, email].
# Regel: Steht in BenutzerZugang mindestens eine Adresse, zählt nur BenutzerZugang. Wer dort entfernt wird, kommt auch über
# WordPress nicht mehr herein. Nur solange BenutzerZugang ganz leer ist (vor model/BenutzerZugangFuellen.pl), gilt der Übergang:
# die Adressen aus wp_users, zugeordnet über wpID/wpMitID/wpMit2ID/wpMit3ID (zugang_id 0), wenn $dbh_wp gesetzt ist.
sub kandidaten {
	my ($dbh, $dbh_wp) = @_;
	my @k;
	my $st = $dbh->prepare("SELECT `ID`, `Benutzer_ID`, `Email` FROM `$T_ZUGANG`");
	$st->execute();
	while (my $r = $st->fetchrow_arrayref) {
		push(@k, [$r->[0], $r->[1], $r->[2]]);
	}
	if ($dbh_wp && !@k) {
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
# Orga und Admin schreiben BenutzerZugang nur über zugang_schreiben (resql.pl leitet POST und DELETE dorthin, siehe zugang_pfad).
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

# Pfad zeigt auf BenutzerZugang (auch in anderer Schreibweise, MySQL kann Tabellennamen ohne Unterschied der Groß-/Kleinschreibung
# auflösen)?
sub zugang_pfad {
	my ($pfad) = @_;
	my ($tabelle) = ($pfad || '') =~ m{^/([a-zA-Z]+)};
	return defined $tabelle && lc($tabelle) eq lc($T_ZUGANG) ? 1 : 0;
}

# Mailadresse in der Form, in der sie in BenutzerZugang steht: getrimmt, Kleinbuchstaben, höchstens 254 Zeichen. '' = taugt nicht.
# Wie mg_email_normal() der Website (mitglieder/_intern/tuer.php), nur strenger: nur ASCII, Teile aus Punkt-Atomen, Domain mit
# Endung aus Buchstaben. Was hier durchgeht, nimmt auch die Website an (test/anmeldung/lauf.pl prüft das gegen PHP).
sub email_normal {
	my ($roh) = @_;
	return '' unless defined $roh && !ref($roh);
	my $e = lc("$roh");
	$e =~ s/^\s+|\s+$//g;
	return '' if $e eq '' || length($e) > 254;
	my $atom  = qr/[a-z0-9!#\$%&*+\/=?^_`{|}~-]+/;
	my $label = qr/[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?/;
	return '' unless $e =~ /^($atom(?:\.$atom)*)\@(?:$label\.)+[a-z]{2,63}$/;
	return '' if length($1) > 64;
	return $e;
}

# Meldungen für members.htm. Schreiben dürfen nur Orga und Admin, die alle Adressen ohnehin sehen; deshalb sagen die Meldungen
# genau, was los ist (auch, bei welchem Anteil eine Adresse schon steht). Rolle 1 bis 3 bekommen vor jeder Prüfung nur
# "no access right", gleich ob es die Adresse gibt oder nicht.
our %ZUGANG_MELDUNG = (
	ungueltig      => 'Bitte eine gültige Mailadresse eingeben.',
	hier_schon     => 'Nicht gespeichert: Diese Adresse ist bei diesem Anteil schon eingetragen.',
	kein_anteil    => 'Nicht gespeichert: Kein Anteil angegeben.',
	nichts         => 'Nichts geändert.',
	leer           => 'Nicht gespeichert: Die Anfrage enthielt keine Daten.',
	weg_speichern  => 'Nicht gespeichert: Diese Adresse gibt es nicht mehr. Bitte „Mailadressen“ neu öffnen.',
	weg_entfernen  => 'Nicht entfernt: Diese Adresse gibt es nicht mehr. Bitte „Mailadressen“ neu öffnen.',
	db_speichern   => 'Nicht gespeichert: Fehler in der Datenbank. Bitte noch einmal versuchen.',
	db_entfernen   => 'Nicht entfernt: Fehler in der Datenbank. Bitte noch einmal versuchen.',
);

# BenutzerZugang schreiben (resql.pl, nur Orga und Admin). Eigene Prüfung statt des allgemeinen Codes:
#   POST   /BenutzerZugang        neue Adresse   {Benutzer_ID, Email, Bezeichnung}
#   POST   /BenutzerZugang/<ID>   ändern         {Email, Bezeichnung, Benutzer_ID}, jedes Feld nur, wenn es sich ändern soll
#   DELETE /BenutzerZugang/<ID>   entfernen
# Eine Adresse gibt es nur einmal über alle Anteile. Die Antwort enthält keine SQL-Fehler und keine Abfragen. Ändern sich Adresse
# oder Anteil, oder wird die Adresse entfernt, enden die Sitzungen, die über diese Adresse angemeldet sind.
# Gibt den Hash für die JSON-Antwort zurück: {result => 1, type => insert|update|delete[, id]} oder {result => 0, reason => …}.
sub zugang_schreiben {
	my ($dbh, $user, $methode, $pfad, $body) = @_;
	my %M = %ZUGANG_MELDUNG;
	return { result => 0, reason => "no access right $pfad" } unless $user && $user->{Role_ID} >= 4;
	return { result => 0, reason => "unknown path $pfad" } unless ($pfad || '') =~ m{^/[a-zA-Z]+(?:/([0-9]{1,10}))?/?$};
	my $id = $1;

	if ($methode eq 'DELETE') {
		return { result => 0, reason => "unknown path $pfad" } unless $id;
		my $n = eval {
			# AenderBenutzer_ID vor dem Löschen setzen, damit das Audit weiß, wer es war (wie resql.pl bei DELETE)
			$dbh->prepare("UPDATE `$T_ZUGANG` SET `AenderBenutzer_ID` = ?, `AenderZeitpunkt` = NOW() WHERE `ID` = ?")->execute($user->{ID}, $id);
			my $d = $dbh->prepare("DELETE FROM `$T_ZUGANG` WHERE `ID` = ?");
			$d->execute($id);
			my $rows = $d->rows();
			$dbh->commit();
			$rows;
		};
		if (!defined $n) {
			eval { $dbh->rollback() };
			return { result => 0, type => 'delete', reason => $M{db_entfernen} };
		}
		return $n > 0 ? { result => 1, type => 'delete' } : { result => 0, type => 'delete', reason => $M{weg_entfernen} };
	}

	return { result => 0, reason => "supported request methods: POST, DELETE" } unless $methode eq 'POST';
	return { result => 0, reason => $M{leer} } unless ref($body) eq 'HASH';
	my %neu;
	if (exists $body->{Email} || !$id) {
		my $e = email_normal($body->{Email});
		return { result => 0, reason => $M{ungueltig} } if $e eq '';
		$neu{Email} = $e;
	}
	if (exists $body->{Bezeichnung}) {
		my $b = defined $body->{Bezeichnung} && !ref($body->{Bezeichnung}) ? "$body->{Bezeichnung}" : '';
		$b =~ s/[\x00-\x1f\x7f]+/ /g;
		$b =~ s/^\s+|\s+$//g;
		return { result => 0, reason => 'Nicht gespeichert: Die Bezeichnung ist zu lang (' . length($b) . ' Zeichen, höchstens 100).' } if length($b) > 100;
		$neu{Bezeichnung} = $b eq '' ? undef : $b;
	}
	if (exists $body->{Benutzer_ID} || !$id) {
		my $b = $body->{Benutzer_ID};
		return { result => 0, reason => $M{kein_anteil} } unless defined $b && !ref($b) && "$b" =~ /^[1-9][0-9]{0,9}$/;
		my ($gibt_es) = $dbh->selectrow_array("SELECT COUNT(*) FROM `Benutzer` WHERE `ID` = ?", undef, "$b");
		return { result => 0, reason => "Nicht gespeichert: Den Anteil Nr. $b gibt es nicht." } unless $gibt_es;
		$neu{Benutzer_ID} = "$b" + 0;
	}

	if (!$id) {
		if (my $dublette = _zugang_dublette($dbh, $neu{Email}, 0, $neu{Benutzer_ID})) {
			return { result => 0, type => 'insert', reason => $dublette };
		}
		my $neue_id = eval {
			my $st = $dbh->prepare("INSERT INTO `$T_ZUGANG` (`Benutzer_ID`, `Email`, `Bezeichnung`, `AenderBenutzer_ID`) VALUES (?, ?, ?, ?)");
			$st->execute($neu{Benutzer_ID}, $neu{Email}, $neu{Bezeichnung}, $user->{ID});
			my $i = $st->{mysql_insertid};
			$dbh->commit();
			$i;
		};
		if (!$neue_id) {
			eval { $dbh->rollback() };
			# z. B. dieselbe Adresse gleichzeitig von zwei Seiten eingetragen (eindeutiger Schlüssel)
			return { result => 0, type => 'insert', reason => _zugang_dublette($dbh, $neu{Email}, 0, $neu{Benutzer_ID}) || $M{db_speichern} };
		}
		return { result => 1, type => 'insert', id => $neue_id + 0 };
	}

	my $alt = $dbh->selectrow_hashref("SELECT `Benutzer_ID`, `Email` FROM `$T_ZUGANG` WHERE `ID` = ?", undef, $id);
	return { result => 0, type => 'update', reason => $M{weg_speichern} } unless $alt;
	return { result => 0, type => 'update', reason => $M{nichts} } unless %neu;
	if (defined $neu{Email}) {
		my $dublette = _zugang_dublette($dbh, $neu{Email}, $id, $neu{Benutzer_ID} // $alt->{Benutzer_ID});
		return { result => 0, type => 'update', reason => $dublette } if $dublette;
	}
	my @spalten = sort keys %neu;
	my $ok = eval {
		$dbh->prepare("UPDATE `$T_ZUGANG` SET " . join('', map { "`$_` = ?, " } @spalten) . "`AenderBenutzer_ID` = ?, `AenderZeitpunkt` = NOW() WHERE `ID` = ?")
			->execute((map { $neu{$_} } @spalten), $user->{ID}, $id);
		if ((defined $neu{Email} && lc($neu{Email}) ne lc($alt->{Email})) || (defined $neu{Benutzer_ID} && $neu{Benutzer_ID} != $alt->{Benutzer_ID})) {
			# andere Adresse oder anderer Anteil: Wer über die alte Zuordnung angemeldet ist, ist es nicht mehr
			$dbh->prepare("DELETE FROM `$T_SITZUNG` WHERE `BenutzerZugang_ID` = ?")->execute($id);
		}
		$dbh->commit();
		1;
	};
	if (!$ok) {
		eval { $dbh->rollback() };
		my $dublette = defined $neu{Email} ? _zugang_dublette($dbh, $neu{Email}, $id, $neu{Benutzer_ID} // $alt->{Benutzer_ID}) : undef;
		return { result => 0, type => 'update', reason => $dublette || $M{db_speichern} };
	}
	return { result => 1, type => 'update' };
}

# Steht diese Adresse schon in BenutzerZugang (außer in Zeile $ausser)? Dann die Meldung dazu: beim selben Anteil ($benutzer_id) oder
# bei welchem anderen (Name und Nr.). Sonst undef.
sub _zugang_dublette {
	my ($dbh, $email, $ausser, $benutzer_id) = @_;
	my $d = $dbh->selectrow_hashref("SELECT z.`Benutzer_ID` AS `Anteil`, b.`Name` AS `Name` FROM `$T_ZUGANG` z LEFT JOIN `Benutzer` b ON b.`ID` = z.`Benutzer_ID`"
		. " WHERE z.`Email` = ? AND z.`ID` <> ? LIMIT 1", undef, $email, $ausser || 0);
	return undef unless $d;
	return $ZUGANG_MELDUNG{hier_schon} if defined $benutzer_id && $d->{Anteil} == $benutzer_id;
	return 'Nicht gespeichert: Diese Adresse ist schon beim Anteil „' . ($d->{Name} // '?') . "“ (Nr. $d->{Anteil}) eingetragen.";
}

1;
