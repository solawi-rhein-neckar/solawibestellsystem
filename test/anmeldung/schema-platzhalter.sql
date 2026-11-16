-- PLATZHALTER für Läufe ohne den Schema-Dump vom Server: nur die Tabellen, die Login und Sitzung brauchen, nach
-- model/db_schema_mysql.sql (Stand 2020) plus den Spalten, die wp.pl auf dem Server nutzt (wpID, wpMitID, wpMit2ID, wpMit3ID).
-- Mit dem echten Dump (mysqldump --no-data --routines --triggers): test/anmeldung/lauf.pl --schema <dump.sql>.

CREATE TABLE `Role` (
  `ID` int(11) NOT NULL AUTO_INCREMENT,
  `Name` varchar(255) COLLATE utf8_german2_ci NOT NULL,
  `LeseRechtDefault` tinyint(1) NOT NULL DEFAULT '1',
  `SchreibRechtDefault` tinyint(1) NOT NULL DEFAULT '0',
  PRIMARY KEY (`ID`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_german2_ci;

CREATE TABLE `Depot` (
  `ID` int(11) NOT NULL AUTO_INCREMENT,
  `Name` varchar(255) COLLATE utf8_german2_ci NOT NULL,
  PRIMARY KEY (`ID`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_german2_ci;

CREATE TABLE `Benutzer` (
  `ID` int(11) NOT NULL AUTO_INCREMENT,
  `Name` varchar(255) COLLATE utf8_german2_ci NOT NULL,
  `MitName` varchar(255) COLLATE utf8_german2_ci DEFAULT NULL,
  `AltName` varchar(255) COLLATE utf8_german2_ci DEFAULT NULL,
  `Passwort` varchar(255) COLLATE utf8_german2_ci NOT NULL,
  `Cookie` varchar(255) COLLATE utf8_german2_ci NOT NULL,
  `Role_ID` int(11) NOT NULL DEFAULT '1',
  `Depot_ID` int(11) DEFAULT NULL,
  `Anteile` int(11) NOT NULL DEFAULT '1',
  `FleischAnteile` int(11) NOT NULL DEFAULT '1',
  `PunkteStand` int(11) NOT NULL DEFAULT '0',
  `PunkteWoche` decimal(6,2) NOT NULL DEFAULT '2019.01',
  `ErstellZeitpunkt` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `AenderZeitpunkt` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `AenderBenutzer_ID` int(11) DEFAULT NULL,
  `wpID` int(11) DEFAULT NULL,
  `wpMitID` int(11) DEFAULT NULL,
  `wpMit2ID` int(11) DEFAULT NULL,
  `wpMit3ID` int(11) DEFAULT NULL,
  PRIMARY KEY (`ID`),
  UNIQUE KEY `Name_Unique` (`Name`),
  KEY `Role_ID` (`Role_ID`),
  KEY `Depot_ID` (`Depot_ID`),
  CONSTRAINT `Benutzer_Depot` FOREIGN KEY (`Depot_ID`) REFERENCES `Depot` (`ID`),
  CONSTRAINT `Benutzer_Role` FOREIGN KEY (`Role_ID`) REFERENCES `Role` (`ID`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_german2_ci;
