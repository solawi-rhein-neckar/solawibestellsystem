# Test: Anmeldung per Mail-Link und Sitzungen je Gerät

Prüft `cgi-bin/SolawiSitzung.pm`, die neuen Wege `POST wp.php/login/web` und `POST wp.php/logout`, die Sitzungsprüfung in `wp.pl`
und `resql.pl` und die Sperren für `BenutzerSitzung` und `BenutzerZugang`. Nur erfundene Mitglieder (`example.org`).

Der Test startet eine eigene, leere MySQL in einem Temp-Ordner, spielt das Schema, `model/BenutzerZugangSitzung.sql` und die
Testmitglieder ein, kopiert `cgi-bin/` daneben (nur die Verbindung zeigt auf die Test-MySQL) und ruft `wp.pl` und `resql.pl` als
CGI auf – so wie `cgi-bin/*.php` auf dem Server. Danach ist alles wieder weg. Die echte Datenbank fasst er nie an.

```bash
perl test/anmeldung/lauf.pl                       # mit test/anmeldung/schema-platzhalter.sql
perl test/anmeldung/lauf.pl --schema dump.sql     # mit dem Schema-Dump (mysqldump --no-data --routines --triggers)
perl test/anmeldung/lauf.pl --web <ordner>        # zusätzlich gegen die echte Brücke der Website
BEHALTEN=1 perl test/anmeldung/lauf.pl            # Temp-Ordner (Logs der Test-MySQL) bleibt liegen
```

Der Dump vom Server stammt aus MySQL 5.7. Der Test spielt eine angepasste Kopie ein: ohne den sql_mode `NO_AUTO_CREATE_USER`
(gibt es in MySQL 8 nicht mehr) und mit dem DEFINER der Trigger und Views als Benutzer der Test-MySQL. Anweisungen, die MySQL 8
trotzdem ablehnt (Stand 13.11.2026: drei Prozeduren, `BenutzerBestellungen`, `BenutzerBestellungenX`, `BenutzerBestellungXX`),
überspringt er und nennt sie am Anfang des Laufs. Die Anmeldung braucht keine davon.

## Was es braucht

- `mysqld` und `mysql` (MySQL 8.4 LTS; der Server hat 5.7, die neuen Tabellen nutzen nichts, was 5.7 nicht kann). Mac:
  `brew install mysql@8.4`, dann `PATH="/opt/homebrew/opt/mysql@8.4/bin:$PATH"` oder `MYSQLD=…`.
- `php` (Attrappe der Website-Brücke), `PHP=…` falls nicht im `PATH`.
- `DBD::mysql` für das Perl, mit dem der Test läuft. Mac mit dem System-Perl (der Pfad darf keine Leerzeichen haben):
  `cpanm --notest -L ~/.cache/solawi-bestellsystem-test/perl5 --configure-args="--mysql_config=/opt/homebrew/opt/mysql@8.4/bin/mysql_config" DBD::mysql`
  – der Test nimmt diesen Ordner von selbst dazu, sonst `PERL5LIB=…`.

## Die Brücke zur Website

Auf dem Server prüft `mitglieder/_intern/bestellsystem.php` der Website (PHP, liegt im Mitgliederbereich und ist über den
Webserver gesperrt), ob das Cookie `mg_s` zu einer gültigen Anmeldung gehört und zu welcher Adresse. Vertrag:

```
php bestellsystem.php pruefen    stdin: Cookie mg_s, dann je Zeile "<zugang_id>\t<benutzer_id>\t<email>"
                                 stdout: "OK <zugang_id> <benutzer_id> <bis>" | "NEIN" | "MEHRDEUTIG"
php bestellsystem.php abmelden   stdin: Cookie mg_s            stdout: "OK"
```

Im Test steht dafür `test/anmeldung/bruecke-attrappe.php` (gleicher Vertrag, Anmeldungen aus einer JSON-Datei). Mit `--web`
läuft ein zusätzlicher Teil gegen die echte Brücke: `<ordner>/mitglieder/_intern/` mit `tuer.php`, `versand.php` und
`bestellsystem.php` aus dem Paket der Website.
