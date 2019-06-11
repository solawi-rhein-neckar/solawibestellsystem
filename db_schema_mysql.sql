-- phpMyAdmin SQL Dump
-- version 4.8.5
-- https://www.phpmyadmin.net/
--
-- Host: localhost
-- Erstellungszeit: 11. Jun 2019 um 23:04
-- Server-Version: 5.7.25-nmm2-log
-- PHP-Version: 7.2.14-nmm1

SET SQL_MODE = "NO_AUTO_VALUE_ON_ZERO";
SET AUTOCOMMIT = 0;
START TRANSACTION;
SET time_zone = "+00:00";

--
-- Datenbank: `d02dbcf8`
--

-- --------------------------------------------------------

--
-- Tabellenstruktur für Tabelle `Benutzer`
--

CREATE TABLE `Benutzer` (
  `ID` int(11) NOT NULL,
  `Name` varchar(255) COLLATE utf8_german2_ci NOT NULL,
  `Passwort` varchar(255) COLLATE utf8_german2_ci NOT NULL,
  `Cookie` varchar(255) COLLATE utf8_german2_ci NOT NULL,
  `Role_ID` int(11) NOT NULL DEFAULT '1',
  `Depot_ID` int(11) NOT NULL DEFAULT '1',
  `Anteile` int(11) NOT NULL DEFAULT '1',
  `PunkteStand` int(11) NOT NULL DEFAULT '0',
  `PunkteWoche` decimal(6,2) NOT NULL DEFAULT '2019.01',
  `ErstellZeitpunkt` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `AenderZeitpunkt` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `AenderBenutzer_ID` int(11) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_german2_ci;

-- --------------------------------------------------------

--
-- Stellvertreter-Struktur des Views `BenutzerBestellView`
-- (Siehe unten für die tatsächliche Ansicht)
--
CREATE TABLE `BenutzerBestellView` (
`Benutzer_ID` int(11)
,`Benutzer` varchar(255)
,`Depot_ID` int(11)
,`Depot` varchar(255)
,`Produkt_ID` int(11)
,`Produkt` varchar(255)
,`Beschreibung` varchar(2047)
,`Einheit` varchar(7)
,`Menge` decimal(8,2)
,`Woche` decimal(6,2)
,`Anzahl` decimal(42,0)
,`AnzahlModul` decimal(42,0)
,`AnzahlZusatz` decimal(42,0)
,`Urlaub` int(1)
);

-- --------------------------------------------------------

--
-- Stellvertreter-Struktur des Views `BenutzerBestellViewUnsorted`
-- (Siehe unten für die tatsächliche Ansicht)
--
CREATE TABLE `BenutzerBestellViewUnsorted` (
`Benutzer_ID` int(11)
,`Benutzer` varchar(255)
,`Depot_ID` int(11)
,`Depot` varchar(255)
,`Produkt_ID` int(11)
,`Produkt` varchar(255)
,`Beschreibung` varchar(2047)
,`Einheit` varchar(7)
,`Menge` decimal(8,2)
,`Woche` decimal(6,2)
,`Anzahl` decimal(42,0)
,`AnzahlModul` decimal(42,0)
,`AnzahlZusatz` decimal(42,0)
,`Urlaub` int(1)
);

-- --------------------------------------------------------

--
-- Tabellenstruktur für Tabelle `BenutzerModulAbo`
--

CREATE TABLE `BenutzerModulAbo` (
  `ID` int(11) NOT NULL,
  `Benutzer_ID` int(11) NOT NULL,
  `Modul_ID` int(11) NOT NULL,
  `StartWoche` decimal(6,2) NOT NULL DEFAULT '2019.01',
  `EndWoche` decimal(6,2) DEFAULT NULL,
  `Anzahl` int(11) NOT NULL DEFAULT '1',
  `Sorte` varchar(31) COLLATE utf8_german2_ci DEFAULT NULL,
  `ErstellZeitpunkt` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `AenderZeitpunkt` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `AenderBenutzer_ID` int(11) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_german2_ci;

-- --------------------------------------------------------

--
-- Tabellenstruktur für Tabelle `BenutzerUrlaub`
--

CREATE TABLE `BenutzerUrlaub` (
  `ID` int(11) NOT NULL,
  `Benutzer_ID` int(11) NOT NULL,
  `Woche` decimal(6,2) NOT NULL,
  `ErstellZeitpunkt` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `AenderZeitpunkt` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `AenderBenutzer_ID` int(11) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_german2_ci;

-- --------------------------------------------------------

--
-- Stellvertreter-Struktur des Views `BenutzerView`
-- (Siehe unten für die tatsächliche Ansicht)
--
CREATE TABLE `BenutzerView` (
`ID` int(11)
,`Name` varchar(255)
,`Passwort` varchar(255)
,`Cookie` varchar(255)
,`Role_ID` int(11)
,`Depot_ID` int(11)
,`Anteile` int(11)
,`PunkteStand` int(11)
,`PunkteWoche` decimal(6,2)
,`ErstellZeitpunkt` timestamp
,`AenderZeitpunkt` timestamp
,`AenderBenutzer_ID` int(11)
,`Depot` varchar(255)
,`Modul` text
,`Role` varchar(255)
);

-- --------------------------------------------------------

--
-- Tabellenstruktur für Tabelle `BenutzerZusatzBestellung`
--

CREATE TABLE `BenutzerZusatzBestellung` (
  `ID` int(11) NOT NULL,
  `Benutzer_ID` int(11) NOT NULL,
  `Produkt_ID` int(11) NOT NULL,
  `Woche` decimal(6,2) NOT NULL,
  `Anzahl` int(11) NOT NULL DEFAULT '1',
  `ErstellZeitpunkt` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `AenderZeitpunkt` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `AenderBenutzer_ID` int(11) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_german2_ci;

-- --------------------------------------------------------

--
-- Tabellenstruktur für Tabelle `Depot`
--

CREATE TABLE `Depot` (
  `ID` int(11) NOT NULL,
  `Name` varchar(255) COLLATE utf8_german2_ci NOT NULL,
  `KurzName` varchar(7) COLLATE utf8_german2_ci NOT NULL,
  `Beschreibung` varchar(2047) COLLATE utf8_german2_ci NOT NULL DEFAULT '',
  `VerantwortlicherBenutzer_ID` int(11) DEFAULT NULL,
  `StellvertreterBenutzer_ID` int(11) DEFAULT NULL,
  `ErstellZeitpunkt` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `AenderZeitpunkt` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `AenderBenutzer_ID` int(11) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_german2_ci;

-- --------------------------------------------------------

--
-- Stellvertreter-Struktur des Views `DepotBestellView`
-- (Siehe unten für die tatsächliche Ansicht)
--
CREATE TABLE `DepotBestellView` (
`Depot_ID` int(11)
,`Depot` varchar(255)
,`Produkt_ID` int(11)
,`Produkt` varchar(255)
,`Beschreibung` varchar(2047)
,`Einheit` varchar(7)
,`Menge` decimal(8,2)
,`Woche` decimal(6,2)
,`Anzahl` decimal(64,0)
,`AnzahlModul` decimal(64,0)
,`AnzahlZusatz` decimal(64,0)
,`Urlaub` decimal(32,0)
);

-- --------------------------------------------------------

--
-- Stellvertreter-Struktur des Views `DepotBestellViewUnsorted`
-- (Siehe unten für die tatsächliche Ansicht)
--
CREATE TABLE `DepotBestellViewUnsorted` (
`Depot_ID` int(11)
,`Depot` varchar(255)
,`Produkt_ID` int(11)
,`Produkt` varchar(255)
,`Beschreibung` varchar(2047)
,`Einheit` varchar(7)
,`Menge` decimal(8,2)
,`Woche` decimal(6,2)
,`Anzahl` decimal(64,0)
,`AnzahlModul` decimal(64,0)
,`AnzahlZusatz` decimal(64,0)
,`Urlaub` decimal(32,0)
);

-- --------------------------------------------------------

--
-- Stellvertreter-Struktur des Views `GesamtBestellView`
-- (Siehe unten für die tatsächliche Ansicht)
--
CREATE TABLE `GesamtBestellView` (
`Produkt_ID` int(11)
,`Produkt` varchar(255)
,`Beschreibung` varchar(2047)
,`Einheit` varchar(7)
,`Menge` decimal(8,2)
,`Woche` decimal(6,2)
,`Anzahl` decimal(64,0)
,`AnzahlModul` decimal(64,0)
,`AnzahlZusatz` decimal(64,0)
,`Urlaub` decimal(32,0)
);

-- --------------------------------------------------------

--
-- Stellvertreter-Struktur des Views `GesamtBestellViewUnsorted`
-- (Siehe unten für die tatsächliche Ansicht)
--
CREATE TABLE `GesamtBestellViewUnsorted` (
`Produkt_ID` int(11)
,`Produkt` varchar(255)
,`Beschreibung` varchar(2047)
,`Einheit` varchar(7)
,`Menge` decimal(8,2)
,`Woche` decimal(6,2)
,`Anzahl` decimal(64,0)
,`AnzahlModul` decimal(64,0)
,`AnzahlZusatz` decimal(64,0)
,`Urlaub` decimal(32,0)
);

-- --------------------------------------------------------

--
-- Tabellenstruktur für Tabelle `Modul`
--

CREATE TABLE `Modul` (
  `ID` int(11) NOT NULL,
  `Name` varchar(255) COLLATE utf8_german2_ci NOT NULL,
  `Beschreibung` varchar(2047) COLLATE utf8_german2_ci NOT NULL DEFAULT '',
  `AnzahlProAnteil` int(11) NOT NULL DEFAULT '0',
  `ErstellZeitpunkt` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `AenderZeitpunkt` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `AenderBenutzer_ID` int(11) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_german2_ci;

-- --------------------------------------------------------

--
-- Tabellenstruktur für Tabelle `ModulInhalt`
--

CREATE TABLE `ModulInhalt` (
  `ID` int(11) NOT NULL,
  `Modul_ID` int(11) NOT NULL,
  `Produkt_ID` int(11) NOT NULL,
  `Anzahl` int(11) NOT NULL DEFAULT '1',
  `MindestAnzahl` int(11) NOT NULL DEFAULT '0',
  `MaximalAnzahl` int(11) NOT NULL DEFAULT '99',
  `ErstellZeitpunkt` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `AenderZeitpunkt` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `AenderBenutzer_ID` int(11) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_german2_ci;

-- --------------------------------------------------------

--
-- Stellvertreter-Struktur des Views `ModulInhaltView`
-- (Siehe unten für die tatsächliche Ansicht)
--
CREATE TABLE `ModulInhaltView` (
`ID` int(11)
,`Modul_ID` int(11)
,`Produkt_ID` int(11)
,`Anzahl` int(11)
,`MindestAnzahl` int(11)
,`MaximalAnzahl` int(11)
,`ErstellZeitpunkt` timestamp
,`AenderZeitpunkt` timestamp
,`AenderBenutzer_ID` int(11)
,`Woche` decimal(6,2)
);

-- --------------------------------------------------------

--
-- Tabellenstruktur für Tabelle `ModulInhaltWoche`
--

CREATE TABLE `ModulInhaltWoche` (
  `ID` int(11) NOT NULL,
  `ModulInhalt_ID` int(11) NOT NULL,
  `Woche` decimal(6,2) NOT NULL,
  `ErstellZeitpunkt` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `AenderZeitpunkt` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `AenderBenutzer_ID` int(11) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_german2_ci;

-- --------------------------------------------------------

--
-- Tabellenstruktur für Tabelle `Produkt`
--

CREATE TABLE `Produkt` (
  `ID` int(11) NOT NULL,
  `Name` varchar(255) COLLATE utf8_german2_ci NOT NULL,
  `Beschreibung` varchar(2047) COLLATE utf8_german2_ci NOT NULL DEFAULT '',
  `Einheit` varchar(7) COLLATE utf8_german2_ci NOT NULL DEFAULT 'Stueck',
  `Menge` decimal(8,2) NOT NULL DEFAULT '1.00',
  `Punkte` int(11) NOT NULL DEFAULT '1',
  `AnzahlZusatzBestellungMax` int(11) NOT NULL DEFAULT '0',
  `ErstellZeitpunkt` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `AenderZeitpunkt` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `AenderBenutzer_ID` int(11) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_german2_ci;

-- --------------------------------------------------------

--
-- Tabellenstruktur für Tabelle `Recht`
--

CREATE TABLE `Recht` (
  `ID` int(11) NOT NULL,
  `Role_ID` int(11) NOT NULL,
  `Tabelle` varchar(255) COLLATE utf8_german2_ci DEFAULT NULL,
  `Spalte` varchar(255) COLLATE utf8_german2_ci DEFAULT NULL,
  `SpalteBenutzerID` varchar(255) COLLATE utf8_german2_ci DEFAULT NULL,
  `LeseAlle` tinyint(1) NOT NULL DEFAULT '1',
  `LeseEigene` tinyint(1) NOT NULL DEFAULT '1',
  `SchreibeAlle` tinyint(1) NOT NULL DEFAULT '0',
  `SchreibeEigene` tinyint(1) NOT NULL DEFAULT '1'
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_german2_ci;

-- --------------------------------------------------------

--
-- Tabellenstruktur für Tabelle `Role`
--

CREATE TABLE `Role` (
  `ID` int(11) NOT NULL,
  `Name` varchar(255) COLLATE utf8_german2_ci NOT NULL,
  `LeseRechtDefault` tinyint(1) NOT NULL DEFAULT '1',
  `SchreibRechtDefault` tinyint(1) NOT NULL DEFAULT '0'
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_german2_ci;

-- --------------------------------------------------------

--
-- Struktur des Views `BenutzerBestellView`
--
DROP TABLE IF EXISTS `BenutzerBestellView`;

CREATE ALGORITHM=UNDEFINED DEFINER=`d02dbcf8`@`localhost` SQL SECURITY DEFINER VIEW `BenutzerBestellView`  AS  select `BenutzerBestellViewUnsorted`.`Benutzer_ID` AS `Benutzer_ID`,`BenutzerBestellViewUnsorted`.`Benutzer` AS `Benutzer`,`BenutzerBestellViewUnsorted`.`Depot_ID` AS `Depot_ID`,`BenutzerBestellViewUnsorted`.`Depot` AS `Depot`,`BenutzerBestellViewUnsorted`.`Produkt_ID` AS `Produkt_ID`,`BenutzerBestellViewUnsorted`.`Produkt` AS `Produkt`,`BenutzerBestellViewUnsorted`.`Beschreibung` AS `Beschreibung`,`BenutzerBestellViewUnsorted`.`Einheit` AS `Einheit`,`BenutzerBestellViewUnsorted`.`Menge` AS `Menge`,`BenutzerBestellViewUnsorted`.`Woche` AS `Woche`,`BenutzerBestellViewUnsorted`.`Anzahl` AS `Anzahl`,`BenutzerBestellViewUnsorted`.`AnzahlModul` AS `AnzahlModul`,`BenutzerBestellViewUnsorted`.`AnzahlZusatz` AS `AnzahlZusatz`,`BenutzerBestellViewUnsorted`.`Urlaub` AS `Urlaub` from `BenutzerBestellViewUnsorted` order by `BenutzerBestellViewUnsorted`.`Depot`,`BenutzerBestellViewUnsorted`.`Benutzer`,`BenutzerBestellViewUnsorted`.`Produkt` ;

-- --------------------------------------------------------

--
-- Struktur des Views `BenutzerBestellViewUnsorted`
--
DROP TABLE IF EXISTS `BenutzerBestellViewUnsorted`;

CREATE ALGORITHM=UNDEFINED DEFINER=`d02dbcf8`@`localhost` SQL SECURITY DEFINER VIEW `BenutzerBestellViewUnsorted`  AS  select `u`.`Benutzer_ID` AS `Benutzer_ID`,`Benutzer`.`Name` AS `Benutzer`,`Depot`.`ID` AS `Depot_ID`,`Depot`.`Name` AS `Depot`,`u`.`Produkt_ID` AS `Produkt_ID`,`Produkt`.`Name` AS `Produkt`,`Produkt`.`Beschreibung` AS `Beschreibung`,`Produkt`.`Einheit` AS `Einheit`,`Produkt`.`Menge` AS `Menge`,`u`.`Woche` AS `Woche`,(case when isnull(`BenutzerUrlaub`.`ID`) then sum(`u`.`Anzahl`) else 0 end) AS `Anzahl`,sum((case when (`u`.`Quelle` = 1) then `u`.`Anzahl` else 0 end)) AS `AnzahlModul`,sum((case when (`u`.`Quelle` = 2) then `u`.`Anzahl` else 0 end)) AS `AnzahlZusatz`,(`BenutzerUrlaub`.`ID` is not null) AS `Urlaub` from ((((((select 1 AS `Quelle`,`BenutzerModulAbo`.`Benutzer_ID` AS `Benutzer_ID`,`ModulInhalt`.`Produkt_ID` AS `Produkt_ID`,(`ModulInhalt`.`Anzahl` * `BenutzerModulAbo`.`Anzahl`) AS `Anzahl`,`ModulInhaltWoche`.`Woche` AS `Woche` from ((`ModulInhalt` join `ModulInhaltWoche` on((`ModulInhaltWoche`.`ModulInhalt_ID` = `ModulInhalt`.`ID`))) join `BenutzerModulAbo` on(((`BenutzerModulAbo`.`Modul_ID` = `ModulInhalt`.`Modul_ID`) and (isnull(`BenutzerModulAbo`.`StartWoche`) or (`ModulInhaltWoche`.`Woche` >= `BenutzerModulAbo`.`StartWoche`)) and (isnull(`BenutzerModulAbo`.`EndWoche`) or (`ModulInhaltWoche`.`Woche` <= `BenutzerModulAbo`.`EndWoche`)))))) union all (select 2 AS `Quelle`,`BenutzerZusatzBestellung`.`Benutzer_ID` AS `Benutzer_ID`,`BenutzerZusatzBestellung`.`Produkt_ID` AS `Produkt_ID`,`BenutzerZusatzBestellung`.`Anzahl` AS `Anzahl`,`BenutzerZusatzBestellung`.`Woche` AS `Woche` from `BenutzerZusatzBestellung`)) `u` join `Produkt` on((`u`.`Produkt_ID` = `Produkt`.`ID`))) join `Benutzer` on((`u`.`Benutzer_ID` = `Benutzer`.`ID`))) join `Depot` on((`Benutzer`.`Depot_ID` = `Depot`.`ID`))) left join `BenutzerUrlaub` on(((`BenutzerUrlaub`.`Benutzer_ID` = `u`.`Benutzer_ID`) and (`BenutzerUrlaub`.`Woche` = `u`.`Woche`)))) group by `u`.`Benutzer_ID`,`Benutzer`.`Name`,`Depot`.`ID`,`Depot`.`Name`,`u`.`Produkt_ID`,`Produkt`.`Name`,`Produkt`.`Beschreibung`,`Produkt`.`Einheit`,`Produkt`.`Menge`,`u`.`Woche`,`BenutzerUrlaub`.`ID` ;

-- --------------------------------------------------------

--
-- Struktur des Views `BenutzerView`
--
DROP TABLE IF EXISTS `BenutzerView`;

CREATE ALGORITHM=UNDEFINED DEFINER=`d02dbcf8`@`localhost` SQL SECURITY DEFINER VIEW `BenutzerView`  AS  select `Benutzer`.`ID` AS `ID`,`Benutzer`.`Name` AS `Name`,`Benutzer`.`Passwort` AS `Passwort`,`Benutzer`.`Cookie` AS `Cookie`,`Benutzer`.`Role_ID` AS `Role_ID`,`Benutzer`.`Depot_ID` AS `Depot_ID`,`Benutzer`.`Anteile` AS `Anteile`,`Benutzer`.`PunkteStand` AS `PunkteStand`,`Benutzer`.`PunkteWoche` AS `PunkteWoche`,`Benutzer`.`ErstellZeitpunkt` AS `ErstellZeitpunkt`,`Benutzer`.`AenderZeitpunkt` AS `AenderZeitpunkt`,`Benutzer`.`AenderBenutzer_ID` AS `AenderBenutzer_ID`,`Depot`.`Name` AS `Depot`,group_concat(concat(convert(convert((case when (`BenutzerModulAbo`.`Anzahl` <> 1) then concat(`BenutzerModulAbo`.`Anzahl`,'x ') else '' end) using latin1) using utf8),`Modul`.`Name`,convert(convert((case when isnull(`BenutzerModulAbo`.`Sorte`) then '' else concat(' ',`BenutzerModulAbo`.`Sorte`) end) using latin1) using utf8)) order by `Modul`.`ID` ASC separator ', ') AS `Modul`,`Role`.`Name` AS `Role` from ((((`Benutzer` left join `Role` on((`Benutzer`.`Role_ID` = `Role`.`ID`))) left join `Depot` on((`Depot`.`ID` = `Benutzer`.`Depot_ID`))) left join `BenutzerModulAbo` on((`BenutzerModulAbo`.`Benutzer_ID` = `Benutzer`.`ID`))) left join `Modul` on((`Modul`.`ID` = `BenutzerModulAbo`.`Modul_ID`))) where ((isnull(`BenutzerModulAbo`.`StartWoche`) or ((`BenutzerModulAbo`.`StartWoche` * 100) <= yearweek((curdate() + interval 3 day),1))) and (isnull(`BenutzerModulAbo`.`EndWoche`) or ((`BenutzerModulAbo`.`EndWoche` * 100) >= yearweek((curdate() + interval 3 day),1)))) group by `Benutzer`.`ID` ;

-- --------------------------------------------------------

--
-- Struktur des Views `DepotBestellView`
--
DROP TABLE IF EXISTS `DepotBestellView`;

CREATE ALGORITHM=UNDEFINED DEFINER=`d02dbcf8`@`localhost` SQL SECURITY DEFINER VIEW `DepotBestellView`  AS  select `DepotBestellViewUnsorted`.`Depot_ID` AS `Depot_ID`,`DepotBestellViewUnsorted`.`Depot` AS `Depot`,`DepotBestellViewUnsorted`.`Produkt_ID` AS `Produkt_ID`,`DepotBestellViewUnsorted`.`Produkt` AS `Produkt`,`DepotBestellViewUnsorted`.`Beschreibung` AS `Beschreibung`,`DepotBestellViewUnsorted`.`Einheit` AS `Einheit`,`DepotBestellViewUnsorted`.`Menge` AS `Menge`,`DepotBestellViewUnsorted`.`Woche` AS `Woche`,`DepotBestellViewUnsorted`.`Anzahl` AS `Anzahl`,`DepotBestellViewUnsorted`.`AnzahlModul` AS `AnzahlModul`,`DepotBestellViewUnsorted`.`AnzahlZusatz` AS `AnzahlZusatz`,`DepotBestellViewUnsorted`.`Urlaub` AS `Urlaub` from `DepotBestellViewUnsorted` order by `DepotBestellViewUnsorted`.`Depot`,`DepotBestellViewUnsorted`.`Produkt` ;

-- --------------------------------------------------------

--
-- Struktur des Views `DepotBestellViewUnsorted`
--
DROP TABLE IF EXISTS `DepotBestellViewUnsorted`;

CREATE ALGORITHM=UNDEFINED DEFINER=`d02dbcf8`@`localhost` SQL SECURITY DEFINER VIEW `DepotBestellViewUnsorted`  AS  select `BenutzerBestellView`.`Depot_ID` AS `Depot_ID`,`BenutzerBestellView`.`Depot` AS `Depot`,`BenutzerBestellView`.`Produkt_ID` AS `Produkt_ID`,`BenutzerBestellView`.`Produkt` AS `Produkt`,`BenutzerBestellView`.`Beschreibung` AS `Beschreibung`,`BenutzerBestellView`.`Einheit` AS `Einheit`,`BenutzerBestellView`.`Menge` AS `Menge`,`BenutzerBestellView`.`Woche` AS `Woche`,sum(`BenutzerBestellView`.`Anzahl`) AS `Anzahl`,sum(`BenutzerBestellView`.`AnzahlModul`) AS `AnzahlModul`,sum(`BenutzerBestellView`.`AnzahlZusatz`) AS `AnzahlZusatz`,sum(`BenutzerBestellView`.`Urlaub`) AS `Urlaub` from `BenutzerBestellView` group by `BenutzerBestellView`.`Produkt_ID`,`BenutzerBestellView`.`Woche`,`BenutzerBestellView`.`Depot_ID` order by `BenutzerBestellView`.`Depot`,`BenutzerBestellView`.`Produkt` ;

-- --------------------------------------------------------

--
-- Struktur des Views `GesamtBestellView`
--
DROP TABLE IF EXISTS `GesamtBestellView`;

CREATE ALGORITHM=UNDEFINED DEFINER=`d02dbcf8`@`localhost` SQL SECURITY DEFINER VIEW `GesamtBestellView`  AS  select `GesamtBestellViewUnsorted`.`Produkt_ID` AS `Produkt_ID`,`GesamtBestellViewUnsorted`.`Produkt` AS `Produkt`,`GesamtBestellViewUnsorted`.`Beschreibung` AS `Beschreibung`,`GesamtBestellViewUnsorted`.`Einheit` AS `Einheit`,`GesamtBestellViewUnsorted`.`Menge` AS `Menge`,`GesamtBestellViewUnsorted`.`Woche` AS `Woche`,`GesamtBestellViewUnsorted`.`Anzahl` AS `Anzahl`,`GesamtBestellViewUnsorted`.`AnzahlModul` AS `AnzahlModul`,`GesamtBestellViewUnsorted`.`AnzahlZusatz` AS `AnzahlZusatz`,`GesamtBestellViewUnsorted`.`Urlaub` AS `Urlaub` from `GesamtBestellViewUnsorted` order by `GesamtBestellViewUnsorted`.`Produkt` ;

-- --------------------------------------------------------

--
-- Struktur des Views `GesamtBestellViewUnsorted`
--
DROP TABLE IF EXISTS `GesamtBestellViewUnsorted`;

CREATE ALGORITHM=UNDEFINED DEFINER=`d02dbcf8`@`localhost` SQL SECURITY DEFINER VIEW `GesamtBestellViewUnsorted`  AS  select `BenutzerBestellView`.`Produkt_ID` AS `Produkt_ID`,`BenutzerBestellView`.`Produkt` AS `Produkt`,`BenutzerBestellView`.`Beschreibung` AS `Beschreibung`,`BenutzerBestellView`.`Einheit` AS `Einheit`,`BenutzerBestellView`.`Menge` AS `Menge`,`BenutzerBestellView`.`Woche` AS `Woche`,sum(`BenutzerBestellView`.`Anzahl`) AS `Anzahl`,sum(`BenutzerBestellView`.`AnzahlModul`) AS `AnzahlModul`,sum(`BenutzerBestellView`.`AnzahlZusatz`) AS `AnzahlZusatz`,sum(`BenutzerBestellView`.`Urlaub`) AS `Urlaub` from `BenutzerBestellView` group by `BenutzerBestellView`.`Produkt_ID`,`BenutzerBestellView`.`Woche` ;

-- --------------------------------------------------------

--
-- Struktur des Views `ModulInhaltView`
--
DROP TABLE IF EXISTS `ModulInhaltView`;

CREATE ALGORITHM=UNDEFINED DEFINER=`d02dbcf8`@`localhost` SQL SECURITY DEFINER VIEW `ModulInhaltView`  AS  select `ModulInhalt`.`ID` AS `ID`,`ModulInhalt`.`Modul_ID` AS `Modul_ID`,`ModulInhalt`.`Produkt_ID` AS `Produkt_ID`,`ModulInhalt`.`Anzahl` AS `Anzahl`,`ModulInhalt`.`MindestAnzahl` AS `MindestAnzahl`,`ModulInhalt`.`MaximalAnzahl` AS `MaximalAnzahl`,`ModulInhalt`.`ErstellZeitpunkt` AS `ErstellZeitpunkt`,`ModulInhalt`.`AenderZeitpunkt` AS `AenderZeitpunkt`,`ModulInhalt`.`AenderBenutzer_ID` AS `AenderBenutzer_ID`,`ModulInhaltWoche`.`Woche` AS `Woche` from (`ModulInhalt` join `ModulInhaltWoche` on((`ModulInhaltWoche`.`ModulInhalt_ID` = `ModulInhalt`.`ID`))) ;

--
-- Indizes der exportierten Tabellen
--

--
-- Indizes für die Tabelle `Benutzer`
--
ALTER TABLE `Benutzer`
  ADD PRIMARY KEY (`ID`),
  ADD UNIQUE KEY `Name_Unique` (`Name`),
  ADD KEY `Role_ID` (`Role_ID`),
  ADD KEY `Depot_ID` (`Depot_ID`),
  ADD KEY `BenutzerAender_Benutzer` (`AenderBenutzer_ID`);

--
-- Indizes für die Tabelle `BenutzerModulAbo`
--
ALTER TABLE `BenutzerModulAbo`
  ADD PRIMARY KEY (`ID`),
  ADD KEY `BenutzerModulAboModul` (`Modul_ID`) USING BTREE,
  ADD KEY `BenutzerModulAboBenutzer` (`Benutzer_ID`) USING BTREE;

--
-- Indizes für die Tabelle `BenutzerUrlaub`
--
ALTER TABLE `BenutzerUrlaub`
  ADD PRIMARY KEY (`ID`),
  ADD KEY `BenutzerUrlaub_Benutzer` (`Benutzer_ID`),
  ADD KEY `BenutzerUrlaubAender_Benutzer` (`AenderBenutzer_ID`);

--
-- Indizes für die Tabelle `BenutzerZusatzBestellung`
--
ALTER TABLE `BenutzerZusatzBestellung`
  ADD PRIMARY KEY (`ID`),
  ADD KEY `Bestellung_Benutzer` (`Benutzer_ID`),
  ADD KEY `Bestellung_Produkt` (`Produkt_ID`),
  ADD KEY `Bestellung_AenderBenutzer` (`AenderBenutzer_ID`);

--
-- Indizes für die Tabelle `Depot`
--
ALTER TABLE `Depot`
  ADD PRIMARY KEY (`ID`),
  ADD KEY `DepotVerantwortlicherBenutzer` (`VerantwortlicherBenutzer_ID`),
  ADD KEY `DepotStellvertreterBenutzer` (`StellvertreterBenutzer_ID`),
  ADD KEY `DepotAenderBenutzer` (`AenderBenutzer_ID`);

--
-- Indizes für die Tabelle `Modul`
--
ALTER TABLE `Modul`
  ADD PRIMARY KEY (`ID`),
  ADD KEY `KorbAenderBenutzer` (`AenderBenutzer_ID`);

--
-- Indizes für die Tabelle `ModulInhalt`
--
ALTER TABLE `ModulInhalt`
  ADD PRIMARY KEY (`ID`),
  ADD KEY `ModulInhalt_Modul` (`Modul_ID`) USING BTREE,
  ADD KEY `ModulInhalt_Produkt` (`Produkt_ID`) USING BTREE,
  ADD KEY `ModulInhalt_Benutzer` (`AenderBenutzer_ID`) USING BTREE;

--
-- Indizes für die Tabelle `ModulInhaltWoche`
--
ALTER TABLE `ModulInhaltWoche`
  ADD PRIMARY KEY (`ID`),
  ADD UNIQUE KEY `Modulwocheuniqu` (`ModulInhalt_ID`,`Woche`) USING BTREE,
  ADD KEY `ModulInhaltWoche_AenderBenutzer` (`AenderBenutzer_ID`) USING BTREE;

--
-- Indizes für die Tabelle `Produkt`
--
ALTER TABLE `Produkt`
  ADD PRIMARY KEY (`ID`),
  ADD KEY `ProduktAenderBenutzer` (`AenderBenutzer_ID`);

--
-- Indizes für die Tabelle `Recht`
--
ALTER TABLE `Recht`
  ADD PRIMARY KEY (`ID`),
  ADD KEY `Role_ID` (`Role_ID`);

--
-- Indizes für die Tabelle `Role`
--
ALTER TABLE `Role`
  ADD PRIMARY KEY (`ID`);

--
-- AUTO_INCREMENT für exportierte Tabellen
--

--
-- AUTO_INCREMENT für Tabelle `Benutzer`
--
ALTER TABLE `Benutzer`
  MODIFY `ID` int(11) NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT für Tabelle `BenutzerModulAbo`
--
ALTER TABLE `BenutzerModulAbo`
  MODIFY `ID` int(11) NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT für Tabelle `BenutzerUrlaub`
--
ALTER TABLE `BenutzerUrlaub`
  MODIFY `ID` int(11) NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT für Tabelle `BenutzerZusatzBestellung`
--
ALTER TABLE `BenutzerZusatzBestellung`
  MODIFY `ID` int(11) NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT für Tabelle `Depot`
--
ALTER TABLE `Depot`
  MODIFY `ID` int(11) NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT für Tabelle `Modul`
--
ALTER TABLE `Modul`
  MODIFY `ID` int(11) NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT für Tabelle `ModulInhalt`
--
ALTER TABLE `ModulInhalt`
  MODIFY `ID` int(11) NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT für Tabelle `ModulInhaltWoche`
--
ALTER TABLE `ModulInhaltWoche`
  MODIFY `ID` int(11) NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT für Tabelle `Produkt`
--
ALTER TABLE `Produkt`
  MODIFY `ID` int(11) NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT für Tabelle `Recht`
--
ALTER TABLE `Recht`
  MODIFY `ID` int(11) NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT für Tabelle `Role`
--
ALTER TABLE `Role`
  MODIFY `ID` int(11) NOT NULL AUTO_INCREMENT;

--
-- Constraints der exportierten Tabellen
--

--
-- Constraints der Tabelle `Benutzer`
--
ALTER TABLE `Benutzer`
  ADD CONSTRAINT `Benutzer_Depot` FOREIGN KEY (`Depot_ID`) REFERENCES `Depot` (`ID`),
  ADD CONSTRAINT `Benutzer_Role` FOREIGN KEY (`Role_ID`) REFERENCES `Role` (`ID`);

--
-- Constraints der Tabelle `BenutzerModulAbo`
--
ALTER TABLE `BenutzerModulAbo`
  ADD CONSTRAINT `BenutzerKorbAboBenutzer` FOREIGN KEY (`Benutzer_ID`) REFERENCES `Benutzer` (`ID`),
  ADD CONSTRAINT `BenutzerKorbAboKorb` FOREIGN KEY (`Modul_ID`) REFERENCES `Modul` (`ID`);

--
-- Constraints der Tabelle `BenutzerUrlaub`
--
ALTER TABLE `BenutzerUrlaub`
  ADD CONSTRAINT `BenutzerUrlaub_Benutzer` FOREIGN KEY (`Benutzer_ID`) REFERENCES `Benutzer` (`ID`);

--
-- Constraints der Tabelle `BenutzerZusatzBestellung`
--
ALTER TABLE `BenutzerZusatzBestellung`
  ADD CONSTRAINT `Bestellung_Benutzer` FOREIGN KEY (`Benutzer_ID`) REFERENCES `Benutzer` (`ID`),
  ADD CONSTRAINT `Bestellung_Produkt` FOREIGN KEY (`Produkt_ID`) REFERENCES `Produkt` (`ID`);

--
-- Constraints der Tabelle `Depot`
--
ALTER TABLE `Depot`
  ADD CONSTRAINT `DepotStellvertreterBenutzer` FOREIGN KEY (`StellvertreterBenutzer_ID`) REFERENCES `Benutzer` (`ID`),
  ADD CONSTRAINT `DepotVerantwortlicherBenutzer` FOREIGN KEY (`VerantwortlicherBenutzer_ID`) REFERENCES `Benutzer` (`ID`);

--
-- Constraints der Tabelle `ModulInhalt`
--
ALTER TABLE `ModulInhalt`
  ADD CONSTRAINT `KorbInhalt_Korb` FOREIGN KEY (`Modul_ID`) REFERENCES `Modul` (`ID`),
  ADD CONSTRAINT `KorbInhalt_Produkt` FOREIGN KEY (`Produkt_ID`) REFERENCES `Produkt` (`ID`);

--
-- Constraints der Tabelle `ModulInhaltWoche`
--
ALTER TABLE `ModulInhaltWoche`
  ADD CONSTRAINT `KorbInhaltWoche_KorbInhalt` FOREIGN KEY (`ModulInhalt_ID`) REFERENCES `ModulInhalt` (`ID`);

--
-- Constraints der Tabelle `Recht`
--
ALTER TABLE `Recht`
  ADD CONSTRAINT `Recht_Role` FOREIGN KEY (`Role_ID`) REFERENCES `Role` (`ID`);
COMMIT;
