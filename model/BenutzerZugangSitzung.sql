-- Anmeldung per Mail-Link über die Website (Webteam, 11.11.2026)
--
-- Zwei neue Tabellen, Benutzer bleibt unverändert. Einmal einspielen, z. B.:
--   mysql db208674_361 < model/BenutzerZugangSitzung.sql
--
-- BenutzerZugang:  Mailadressen je Anteil, gerne mehrere (Hauptmitglied, Mit-Mitglieder). Mit diesen Adressen meldet man sich
--                  auf der Website an (/anmelden/); wp.pl ordnet die Anmeldung über diese Tabelle dem Anteil zu.
--                  Erst leer: Im Übergang ordnet wp.pl auch über wp_users (wpID, wpMitID, wpMit2ID, wpMit3ID) zu.
-- BenutzerSitzung: eine Zeile je angemeldetem Gerät - Handy, Computer und Mit-Mitglied bleiben gleichzeitig angemeldet.
--                  Gespeichert wird nur SHA2(Sitzungs-ID, 256), nie die ID selbst. Abgelaufene Zeilen löscht wp.pl beim
--                  nächsten Login.
--
-- Beide Namen beginnen mit "Benutzer", damit die Regeln in resql.pl greifen (Mitglieder sehen nur eigene Zeilen). Zusätzlich
-- sperrt resql.pl BenutzerSitzung ganz und BenutzerZugang bis auf das Lesen der eigenen Zeilen (siehe SolawiSitzung::tabelle_erlaubt).
--
-- Typen und Zeichensatz wie Benutzer auf dem Server (Schema-Dump vom 13.11.2026 geprüft): Benutzer.ID int(11) mit Vorzeichen,
-- InnoDB, utf8 mit utf8_german2_ci. Die Fremdschlüssel passen damit; test/anmeldung/lauf.pl --schema <dump> spielt sie ein.
-- Keine Audit-Trigger für BenutzerSitzung: eine Zeile je Anmeldung, und die Prüfsumme gehört nicht ins Audit.

CREATE TABLE IF NOT EXISTS `BenutzerZugang` (
  `ID` int(11) NOT NULL AUTO_INCREMENT,
  `Benutzer_ID` int(11) NOT NULL,
  `Email` varchar(254) COLLATE utf8_german2_ci NOT NULL,
  `Bezeichnung` varchar(100) COLLATE utf8_german2_ci DEFAULT NULL,
  `ErstellZeitpunkt` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `AenderZeitpunkt` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `AenderBenutzer_ID` int(11) DEFAULT NULL,
  PRIMARY KEY (`ID`),
  UNIQUE KEY `BenutzerZugang_Email` (`Email`),
  KEY `BenutzerZugang_Benutzer` (`Benutzer_ID`),
  CONSTRAINT `BenutzerZugang_Benutzer` FOREIGN KEY (`Benutzer_ID`) REFERENCES `Benutzer` (`ID`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_german2_ci;

CREATE TABLE IF NOT EXISTS `BenutzerSitzung` (
  `ID` int(11) NOT NULL AUTO_INCREMENT,
  `Benutzer_ID` int(11) NOT NULL,
  `BenutzerZugang_ID` int(11) DEFAULT NULL,
  `IDHash` char(64) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  `Erstellt` datetime NOT NULL,
  `ZuletztGesehen` datetime NOT NULL,
  `GueltigBis` datetime NOT NULL,
  PRIMARY KEY (`ID`),
  UNIQUE KEY `BenutzerSitzung_IDHash` (`IDHash`),
  KEY `BenutzerSitzung_Benutzer` (`Benutzer_ID`),
  KEY `BenutzerSitzung_GueltigBis` (`GueltigBis`),
  CONSTRAINT `BenutzerSitzung_Benutzer` FOREIGN KEY (`Benutzer_ID`) REFERENCES `Benutzer` (`ID`) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT `BenutzerSitzung_Zugang` FOREIGN KEY (`BenutzerZugang_ID`) REFERENCES `BenutzerZugang` (`ID`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_german2_ci;
