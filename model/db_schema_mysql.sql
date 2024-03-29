-- phpMyAdmin SQL Dump
-- version 4.9.2
-- https://www.phpmyadmin.net/
--
-- Host: localhost
-- Erstellungszeit: 21. Jan 2020 um 22:22
-- Server-Version: 5.7.28-nmm1-log
-- PHP-Version: 7.2.24-nmm1

SET SQL_MODE = "NO_AUTO_VALUE_ON_ZERO";
SET AUTOCOMMIT = 0;
START TRANSACTION;
SET time_zone = "+00:00";

--
-- Datenbank: `d02dbcf8`
--
CREATE DATABASE IF NOT EXISTS `d02dbcf8` DEFAULT CHARACTER SET utf8 COLLATE utf8_german2_ci;
USE `d02dbcf8`;

DELIMITER $$
--
-- Prozeduren
--
CREATE DEFINER=`d02dbcf8`@`localhost` PROCEDURE `BenutzerBestellungen` (IN `pWoche` DECIMAL(6,2))  READS SQL DATA
BEGIN
DROP TEMPORARY TABLE IF EXISTS BenutzerBestellungenTemp;
CREATE TEMPORARY TABLE IF NOT EXISTS BenutzerBestellungenTemp ENGINE=MEMORY AS (SELECT
    `u`.`Benutzer_ID` AS `Benutzer_ID`,
    `d02dbcf8`.`Benutzer`.`Name` AS `Benutzer`,
    `d02dbcf8`.`Depot`.`ID` AS `Depot_ID`,
    `d02dbcf8`.`Depot`.`Name` AS `Depot`,
   `u`.`Produkt`,
   `u`.`Beschreibung`,
     `u`.`Einheit`,
    `u`.`Menge`,
    `u`.`Woche` AS `Woche`,
    CONVERT(GROUP_CONCAT(
        (
            CASE WHEN(TRIM(`u`.`Kommentar`) = '') THEN NULL ELSE `u`.`Kommentar`
        END
    ) SEPARATOR ', '
), char(255)) AS `Kommentar`,
    (
        CASE WHEN ISNULL(`d02dbcf8`.`BenutzerUrlaub`.`ID`) THEN SUM(`u`.`Anzahl`) ELSE 0
    END
) AS `Anzahl`,
SUM(
    (
        CASE WHEN(`u`.`Quelle` = 1) THEN `u`.`Anzahl` ELSE 0
    END
)
) AS `AnzahlModul`,
SUM(
    (
        CASE WHEN(`u`.`Quelle` = 2) THEN `u`.`Anzahl` ELSE 0
    END
)
) AS `AnzahlZusatz`,
(
    `d02dbcf8`.`BenutzerUrlaub`.`ID` IS NOT NULL
) AS `Urlaub`
                                                                                FROM
    (
        (
            (
                (
                    (
                        (
                        SELECT
                            1 AS `Quelle`,
                            `d02dbcf8`.`BenutzerModulAbo`.`Benutzer_ID` AS `Benutzer_ID`,
 `d02dbcf8`.`BenutzerModulAbo`.`Kommentar` AS `Kommentar`,
						    Replace(Replace(`d02dbcf8`.`Modul`.`Name`, 'Kräutermodul', 'Kräuter'), 'Quarkmodul' , 'Quark, 400g')  AS `Produkt`,
						    `d02dbcf8`.`Modul`.`Beschreibung` AS `Beschreibung`,
						    '' AS `Einheit`,
						    `d02dbcf8`.`Modul`.`AnzahlProAnteil` AS `Menge`,
						    (
                                `d02dbcf8`.`BenutzerModulAbo`.`Anzahl`
                            ) AS `Anzahl`,
                            pWoche AS `Woche`
                        FROM
                           `d02dbcf8`.`BenutzerModulAbo`
		                JOIN `d02dbcf8`.`Modul` ON
		                    (
		                        (
		                            `BenutzerModulAbo`.`Modul_ID` = `d02dbcf8`.`Modul`.`ID`
		                        )
		                    )                                   WHERE
                               (
                                            ISNULL(
                                                `d02dbcf8`.`BenutzerModulAbo`.`StartWoche`
                                            ) OR(
                                                 pWoche >= `d02dbcf8`.`BenutzerModulAbo`.`StartWoche`
                                            )
                                        ) AND(
                                            ISNULL(
                                                `d02dbcf8`.`BenutzerModulAbo`.`EndWoche`
                                            ) OR(
                                                pWoche <= `d02dbcf8`.`BenutzerModulAbo`.`EndWoche`
                                            )
                                        )
                                    )
                UNION ALL
                    (
                    SELECT
                        2 AS `Quelle`,
                        `d02dbcf8`.`BenutzerZusatzBestellung`.`Benutzer_ID` AS `Benutzer_ID`,
                        `d02dbcf8`.`BenutzerZusatzBestellung`.`Kommentar` AS `Kommentar`,
						    `d02dbcf8`.`Produkt`.`Name` AS `Produkt`,
						    `d02dbcf8`.`Produkt`.`Beschreibung` AS `Beschreibung`,
						    `d02dbcf8`.`Produkt`.`Einheit` AS `Einheit`,
						    `d02dbcf8`.`Produkt`.`Menge` AS `Menge`,
                            `d02dbcf8`.`BenutzerZusatzBestellung`.`Anzahl` AS `Anzahl`,
                        `d02dbcf8`.`BenutzerZusatzBestellung`.`Woche` AS `Woche`
                    FROM
                        `d02dbcf8`.`BenutzerZusatzBestellung`
		                JOIN `d02dbcf8`.`Produkt` ON
		                    (
		                        (
		                            `BenutzerZusatzBestellung`.`Produkt_ID` = `d02dbcf8`.`Produkt`.`ID`
		                        )
		                    )
		                  WHERE    `d02dbcf8`.`BenutzerZusatzBestellung`.`Woche` = pWoche
                    )
                ) `u`

                )
            JOIN `d02dbcf8`.`Benutzer` ON
                (
                    (
                        `u`.`Benutzer_ID` = `d02dbcf8`.`Benutzer`.`ID`
                    )
                )
            )
        JOIN `d02dbcf8`.`Depot` ON
            (
                (
                    `d02dbcf8`.`Benutzer`.`Depot_ID` = `d02dbcf8`.`Depot`.`ID`
                )
            )
        )
    LEFT JOIN `d02dbcf8`.`BenutzerUrlaub` ON
        (
            (
                (
                    `d02dbcf8`.`BenutzerUrlaub`.`Benutzer_ID` = `u`.`Benutzer_ID`
                ) AND(
                    `d02dbcf8`.`BenutzerUrlaub`.`Woche` = `u`.`Woche`
                )
            )
        )
    )
GROUP BY
    `u`.`Benutzer_ID`,
    `d02dbcf8`.`Benutzer`.`Name`,
    `d02dbcf8`.`Depot`.`ID`,
    `d02dbcf8`.`Depot`.`Name`,
    `u`.`Produkt`,
    `u`.`Beschreibung`,
    `u`.`Einheit`,
    `u`.`Menge`,
    `u`.`Woche`,
    `d02dbcf8`.`BenutzerUrlaub`.`ID`);
END$$

CREATE DEFINER=`d02dbcf8`@`localhost` PROCEDURE `CreateDefaultModulAbosForUsersCreatedAfter` (IN `pDate` DATETIME)  MODIFIES SQL DATA
INSERT INTO `BenutzerModulAbo`(`Benutzer_ID`, `Modul_ID`, `StartWoche`, `EndWoche`, `Anzahl`)
SELECT
   Benutzer.ID, Modul.ID, Benutzer.PunkteWoche, '9999.99', Case when Modul.ID = 2 then 3 * Benutzer.Anteile when Modul.ID = 4 then Modul.AnzahlProAnteil * Benutzer.FleischAnteile ELSE Modul.AnzahlProAnteil * Benutzer.Anteile end
FROM
   Benutzer JOIN Modul
WHERE
   Benutzer.ErstellZeitpunkt > pDate and (Modul.AnzahlProAnteil > 0 or Modul.ID = 2) and (Modul.ID != 4 or Benutzer.FleischAnteile > 0)$$

CREATE DEFINER=`d02dbcf8`@`localhost` PROCEDURE `PivotBestellung` (IN `pWoche` DECIMAL(6,2))  READS SQL DATA
    SQL SECURITY INVOKER
BEGIN

SET SESSION group_concat_max_len = 32000;

SET @query := (SELECT GROUP_CONCAT(DISTINCT CONCAT('MAX(IF(Produkt = \'', Name, '\', Anzahl, 0)) AS `', Name, '`' ))  FROM Produkt ORDER BY Nr);

SET @query = CONCAT('SELECT Depot, MAX(IF(Produkt = \'Milch, 0.5L\', Anzahl / 2, 0)) AS `Milch`,', @query, ' , MAX(Urlaub) as `Urlauber`,
(SELECT Sum(Anteile) FROM Benutzer where Benutzer.Depot_ID = `subq`.`Depot_ID`) as `Anteile`,GROUP_CONCAT(`subq`.Kommentar SEPARATOR \', \') as `Kommentar` FROM

(select `BenutzerBestellungenTemp`.`Depot_ID` AS `Depot_ID`,`BenutzerBestellungenTemp`.`Depot` AS `Depot`,`BenutzerBestellungenTemp`.`Produkt` AS `Produkt`,`BenutzerBestellungenTemp`.`Beschreibung` AS `Beschreibung`,`BenutzerBestellungenTemp`.`Einheit` AS `Einheit`,`BenutzerBestellungenTemp`.`Menge` AS `Menge`,`BenutzerBestellungenTemp`.`Woche` AS `Woche`,sum(`BenutzerBestellungenTemp`.`Anzahl`) AS `Anzahl`,sum(`BenutzerBestellungenTemp`.`AnzahlModul`) AS `AnzahlModul`,sum(`BenutzerBestellungenTemp`.`AnzahlZusatz`) AS `AnzahlZusatz`,sum(`BenutzerBestellungenTemp`.`Urlaub`) AS `Urlaub`,
 GROUP_CONCAT(
        (
             CASE WHEN(`BenutzerBestellungenTemp`.`Kommentar` is NULL or TRIM(`BenutzerBestellungenTemp`.`Kommentar`) = \'\' or TRIM(`BenutzerBestellungenTemp`.`Kommentar`) = \'-\' or TRIM(`BenutzerBestellungenTemp`.`Kommentar`) like \'Tausch\') THEN NULL ELSE concat((select name from Benutzer where Benutzer.ID = BenutzerBestellungenTemp.Benutzer_ID), case when Produkt is null or TRIM(Produkt) = \'\' or TRIM(Produkt) = \'-\' or TRIM(Produkt) = \'Kommentar\' THEN \'\' ELSE concat(\' \', Produkt) end, \': \', `BenutzerBestellungenTemp`.`Kommentar`)
        END
    ) SEPARATOR \', \'
) AS `Kommentar`                    from `d02dbcf8`.`BenutzerBestellungenTemp` group by `BenutzerBestellungenTemp`.`Produkt`,`BenutzerBestellungenTemp`.`Woche`,`BenutzerBestellungenTemp`.`Depot_ID` order by `BenutzerBestellungenTemp`.`Depot`,`BenutzerBestellungenTemp`.`Produkt`) subq

 WHERE Woche = ', pWoche ,' GROUP BY Depot_ID');

CALL BenutzerBestellungen(pWoche);

PREPARE stt FROM @query;

EXECUTE stt;

DEALLOCATE PREPARE stt;

END$$

CREATE DEFINER=`d02dbcf8`@`localhost` PROCEDURE `PivotBestellungen` (IN `pWoche` DECIMAL(6,2))  READS SQL DATA
BEGIN

SET SESSION group_concat_max_len = 32000;

SET @query := (SELECT GROUP_CONCAT(DISTINCT CONCAT('MAX(IF(Produkt = \'', Name, '\', Anzahl, 0)) AS `', IF(Nr < 10,'0', ''), Nr, '.', Name, '`' ))  FROM Produkt ORDER BY Nr);

SET @query = CONCAT('SELECT Depot as `00.',pWoche,'`, MAX(IF(Produkt = \'Milch, 0.5L\', Anzahl / 2, 0)) AS `06.Milch`,', @query, ' , MAX(Urlaub) as `99.',pWoche,' Urlauber`,
(SELECT Count(*) FROM Benutzer where Benutzer.Depot_ID = `subq`.`Depot_ID`) as `97.Mitglieder`,
(SELECT Sum(Anteile) FROM Benutzer where Benutzer.Depot_ID = `subq`.`Depot_ID`) as `98.Anteile`,
(SELECT Sum(FleischAnteile) FROM Benutzer where Benutzer.Depot_ID = `subq`.`Depot_ID`) as `98.FleischAnteileErlaubt`,
  GROUP_CONCAT(`subq`.Kommentar SEPARATOR \'; \') as `96.Kommentar`
 FROM

(select `BenutzerBestellungenTemp`.`Depot_ID` AS `Depot_ID`,`BenutzerBestellungenTemp`.`Depot` AS `Depot`,`BenutzerBestellungenTemp`.`Produkt` AS `Produkt`,`BenutzerBestellungenTemp`.`Beschreibung` AS `Beschreibung`,`BenutzerBestellungenTemp`.`Einheit` AS `Einheit`,`BenutzerBestellungenTemp`.`Menge` AS `Menge`,`BenutzerBestellungenTemp`.`Woche` AS `Woche`,sum(`BenutzerBestellungenTemp`.`Anzahl`) AS `Anzahl`,sum(`BenutzerBestellungenTemp`.`AnzahlModul`) AS `AnzahlModul`,sum(`BenutzerBestellungenTemp`.`AnzahlZusatz`) AS `AnzahlZusatz`,sum(`BenutzerBestellungenTemp`.`Urlaub`) AS `Urlaub`,GROUP_CONCAT(
        (
            CASE WHEN(`BenutzerBestellungenTemp`.`Kommentar` is NULL or TRIM(`BenutzerBestellungenTemp`.`Kommentar`) = \'\' or TRIM(`BenutzerBestellungenTemp`.`Kommentar`) = \'-\') THEN NULL ELSE concat((select name from Benutzer where Benutzer.ID = BenutzerBestellungenTemp.Benutzer_ID), case when Produkt is null or TRIM(Produkt) = \'\' or TRIM(Produkt) = \'-\' or TRIM(Produkt) = \'Kommentar\' THEN \'\' ELSE concat(\' \', Produkt) end, \': \', `BenutzerBestellungenTemp`.`Kommentar`)
        END
    ) SEPARATOR \', \'
) AS `Kommentar`

                    from `d02dbcf8`.`BenutzerBestellungenTemp` group by `BenutzerBestellungenTemp`.`Produkt`,`BenutzerBestellungenTemp`.`Woche`,`BenutzerBestellungenTemp`.`Depot_ID` order by `BenutzerBestellungenTemp`.`Depot`,`BenutzerBestellungenTemp`.`Produkt`) subq

 WHERE Woche = ', pWoche ,' GROUP BY Depot_ID');

CALL BenutzerBestellungen(pWoche);

PREPARE stt FROM @query;

EXECUTE stt;

DEALLOCATE PREPARE stt;

END$$

CREATE DEFINER=`d02dbcf8`@`localhost` PROCEDURE `PivotBestellungenAlt` (IN `pWoche` DECIMAL(6,2))  READS SQL DATA
    SQL SECURITY INVOKER
BEGIN

SET SESSION group_concat_max_len = 32000;

SET @query := (SELECT GROUP_CONCAT(DISTINCT CONCAT('MAX(IF(Produkt_ID = ', ID, ', Anzahl, 0)) AS `', IF(Nr < 10,'0', ''), Nr, '.', Name, '`' ))  FROM Produkt ORDER BY Nr);

SET @query = CONCAT('SELECT Depot as `00.',pWoche,'`, ', @query, ' , MAX(Urlaub) as `',pWoche,' Urlauber` FROM DepotBestellView WHERE Woche = ', pWoche ,' GROUP BY Depot_ID');

PREPARE stt FROM @query;

EXECUTE stt;

DEALLOCATE PREPARE stt;

END$$

CREATE DEFINER=`d02dbcf8`@`localhost` PROCEDURE `PivotDepot` (IN `pWoche` DECIMAL(6,2), IN `pDepot` INT)  READS SQL DATA
    SQL SECURITY INVOKER
BEGIN

SET SESSION group_concat_max_len = 32000;

SET @query := (SELECT GROUP_CONCAT(DISTINCT CONCAT('SUM(IF(Produkt = \'', Name, '\', Anzahl, 0)) AS `', IF(Nr < 10,'0', ''), Nr, '.', Name, '`' ))  FROM Produkt ORDER BY Nr);

SET @query = CONCAT('SELECT Benutzer as `00.',pWoche, ' ', (SELECT Name FROM Depot WHERE ID = pDepot),'`, SUM(IF(Produkt = \'Milch, 0.5L\', Anzahl / 2, 0)) AS `06.Milch`,', @query, ' , SUM(Urlaub) as `99.',pWoche, ' Urlaub` ,
GROUP_CONCAT(`subq`.Kommentar SEPARATOR \'; \') as `96.Kommentar`
 FROM


(select  `BenutzerBestellungenTemp`.`Benutzer` AS `Benutzer`, `BenutzerBestellungenTemp`.`Benutzer_ID` AS `Benutzer_ID`,`BenutzerBestellungenTemp`.`Depot_ID` AS `Depot_ID`,`BenutzerBestellungenTemp`.`Depot` AS `Depot`,`BenutzerBestellungenTemp`.`Produkt` AS `Produkt`,`BenutzerBestellungenTemp`.`Beschreibung` AS `Beschreibung`,`BenutzerBestellungenTemp`.`Einheit` AS `Einheit`,`BenutzerBestellungenTemp`.`Menge` AS `Menge`,`BenutzerBestellungenTemp`.`Woche` AS `Woche`,sum(`BenutzerBestellungenTemp`.`Anzahl`) AS `Anzahl`,sum(`BenutzerBestellungenTemp`.`AnzahlModul`) AS `AnzahlModul`,sum(`BenutzerBestellungenTemp`.`AnzahlZusatz`) AS `AnzahlZusatz`,sum(`BenutzerBestellungenTemp`.`Urlaub`) AS `Urlaub`,GROUP_CONCAT(
        (
            CASE WHEN(`BenutzerBestellungenTemp`.`Kommentar` is NULL or TRIM(`BenutzerBestellungenTemp`.`Kommentar`) = \'\' or TRIM(`BenutzerBestellungenTemp`.`Kommentar`) = \'-\') THEN NULL ELSE concat((select name from Benutzer where Benutzer.ID = BenutzerBestellungenTemp.Benutzer_ID), case when Produkt is null or TRIM(Produkt) = \'\' or TRIM(Produkt) = \'-\' or TRIM(Produkt) = \'Kommentar\' THEN \'\' ELSE concat(\' \', Produkt) end, \': \', `BenutzerBestellungenTemp`.`Kommentar`)
        END
    ) SEPARATOR \', \'
) AS `Kommentar`

                    from `d02dbcf8`.`BenutzerBestellungenTemp` group by `BenutzerBestellungenTemp`.`Produkt`,`BenutzerBestellungenTemp`.`Woche`,`BenutzerBestellungenTemp`.`Benutzer_ID`,`BenutzerBestellungenTemp`.`Depot_ID` order by `BenutzerBestellungenTemp`.`Benutzer_ID`,`BenutzerBestellungenTemp`.`Depot`,`BenutzerBestellungenTemp`.`Produkt`) subq

                    WHERE Woche = ', pWoche ,' AND Depot_ID = ',pDepot,' GROUP BY Benutzer WITH ROLLUP');

CALL BenutzerBestellungen(pWoche);

PREPARE stt FROM @query;

EXECUTE stt;

DEALLOCATE PREPARE stt;

END$$

CREATE DEFINER=`d02dbcf8`@`localhost` PROCEDURE `PivotDepotAlt` (IN `pWoche` DECIMAL(6,2), IN `pDepot` INT)  READS SQL DATA
BEGIN

SET SESSION group_concat_max_len = 32000;

SET @query := (SELECT GROUP_CONCAT(DISTINCT CONCAT('MAX(IF(Produkt_ID = ', ID, ', Anzahl, 0)) AS `', IF(Nr < 10,'0', ''), Nr, '.', Name, '`' ))  FROM Produkt ORDER BY Nr);

SET @query = CONCAT('SELECT Benutzer as `00.',pWoche, ' ', (SELECT Name FROM Depot WHERE ID = pDepot),'`, ', @query, ' , MAX(Urlaub) as `',pWoche, ' Urlaub` FROM BenutzerBestellView WHERE Woche = ', pWoche ,' AND Depot_ID = ',pDepot,' GROUP BY Benutzer_ID');

PREPARE stt FROM @query;

EXECUTE stt;

DEALLOCATE PREPARE stt;

END$$

CREATE DEFINER=`d02dbcf8`@`localhost` PROCEDURE `reCreate_Audit_Tables_And_Triggers` ()  READS SQL DATA
    SQL SECURITY INVOKER
SELECT concat("DROP TABLE IF EXISTS `", "d02dbcf8", "`.`", table_data.audit_table, "`;
",
          "CREATE TABLE `", "d02dbcf8", "`.`", table_data.audit_table, "`
",
          "(
",
          "  `auditAction` ENUM ('INSERT', 'UPDATE', 'DELETE'),
",
          "  `auditTimestamp` DATETIME DEFAULT CURRENT_TIMESTAMP,
",
          "  `auditId` INT(14) AUTO_INCREMENT,",
          column_defs, ",
"
          "  PRIMARY KEY (`auditId`),
",
          "  INDEX (`auditTimestamp`)
",
          ")
",
          "  ENGINE = InnoDB;

",
          "DROP TRIGGER IF EXISTS `", "d02dbcf8", "`.`", table_data.insert_trigger, "`;
",
          "CREATE TRIGGER `", "d02dbcf8", "`.`", table_data.insert_trigger, "`
",
          "  AFTER INSERT ON `", "d02dbcf8", "`.`", table_data.db_table, "`
",
          "  FOR EACH ROW INSERT INTO `", "d02dbcf8", "`.`", table_data.audit_table, "`
",
          "     (`auditAction`,", table_data.column_names, ")
",
          "  VALUES
",
          "     ('INSERT',", table_data.NEWcolumn_names, ");

",
          "DROP TRIGGER IF EXISTS `", "d02dbcf8", "`.`", table_data.update_trigger, "`;
",
          "CREATE TRIGGER `", "d02dbcf8", "`.`", table_data.update_trigger, "`
",
          "  AFTER UPDATE ON `", "d02dbcf8", "`.`", table_data.db_table, "`
",
          "  FOR EACH ROW INSERT INTO `", "d02dbcf8", "`.`", table_data.audit_table, "`
",
          "     (`auditAction`,", table_data.column_names, ")
",
          "  VALUES
",
          "     ('UPDATE',", table_data.NEWcolumn_names, ");

",
          "DROP TRIGGER IF EXISTS `", "d02dbcf8", "`.`", table_data.delete_trigger, "`;
",
          "CREATE TRIGGER `", "d02dbcf8", "`.`", table_data.delete_trigger, "`
",
          "  AFTER DELETE ON `", "d02dbcf8", "`.`", table_data.db_table, "`
",
          "  FOR EACH ROW INSERT INTO `", "d02dbcf8", "`.`", table_data.audit_table, "`
",
          "     (`auditAction`,", table_data.column_names, ")
",
          "  VALUES
",
          "     ('DELETE',", table_data.OLDcolumn_names, ");

"
)
FROM (
   # This select builds a derived table of table names with ordered and grouped column information in different
   # formats as needed for audit table definitions and trigger definitions.
   SELECT
     table_order_key,
     table_name                                                                      AS db_table,
     concat("audit_", table_name)                                                    AS audit_table,
     concat(table_name, "_inserts")                                                  AS insert_trigger,
     concat(table_name, "_updates")                                                  AS update_trigger,
     concat(table_name, "_deletes")                                                  AS delete_trigger,
     group_concat("
  `", column_name, "` ", column_type ORDER BY column_order_key) AS column_defs,
     group_concat("`", column_name, "`" ORDER BY column_order_key)                   AS column_names,
     group_concat("`NEW.", column_name, "`" ORDER BY column_order_key)               AS NEWcolumn_names,
     group_concat("`OLD.", column_name, "`" ORDER BY column_order_key)               AS OLDcolumn_names
   FROM
     (
       # This select builds a derived table of table names, column names and column types for
       # non-audit tables of the specified db, along with ordering keys for later order by.
       # The ordering must be done outside this select, as tables (including derived tables)
       # are by definition unordered.
       # We're only ordering so that the generated audit schema maintains a resemblance to the
       # main schema.
       SELECT
         information_schema.tables.table_name        AS table_name,
         information_schema.columns.column_name      AS column_name,
         information_schema.columns.column_type      AS column_type,
         information_schema.tables.create_time       AS table_order_key,
         information_schema.columns.ordinal_position AS column_order_key
       FROM information_schema.tables
         JOIN information_schema.columns
           ON information_schema.tables.table_name = information_schema.columns.table_name
       WHERE information_schema.tables.table_schema = "d02dbcf8"
         AND information_schema.tables.TABLE_TYPE = 'BASE TABLE'
             AND information_schema.columns.table_schema = "d02dbcf8"
             AND information_schema.tables.table_name NOT LIKE "audit\_%"
     ) table_column_ordering_info
   GROUP BY table_name
 ) table_data
ORDER BY table_order_key$$

CREATE DEFINER=`d02dbcf8`@`localhost` PROCEDURE `zsp_generate_audit` (IN `audit_schema_name` VARCHAR(255), IN `audit_table_name` VARCHAR(255), OUT `script` LONGTEXT, OUT `errors` LONGTEXT)  main_block: BEGIN

	DECLARE trg_insert, trg_update, trg_delete, vw_audit, vw_audit_meta, out_errors LONGTEXT;
	DECLARE stmt, header LONGTEXT;
	DECLARE at_id1, at_id2 LONGTEXT;
	DECLARE c INTEGER;

	-- Default max length of GROUP_CONCAT IS 1024
	SET SESSION group_concat_max_len = 100000;

	SET out_errors := '';

	-- Check to see if the specified table exists
	SET c := (SELECT COUNT(*) FROM information_schema.tables
			WHERE BINARY TABLE_SCHEMA = BINARY audit_schema_name
				AND BINARY table_name = BINARY audit_table_name);
	IF c <> 1 THEN
		SET out_errors := CONCAT( out_errors, '\n', 'The table you specified `', audit_schema_name, '`.`', audit_table_name, '` does not exists.' );
		LEAVE main_block;
	END IF;


	-- Check audit and meta table exists
	SET c := (SELECT COUNT(*) FROM information_schema.tables
			WHERE BINARY TABLE_SCHEMA = BINARY audit_schema_name
				AND (BINARY table_name = BINARY 'zaudit' OR BINARY table_name = BINARY 'zaudit_meta') );
	IF c <> 2 THEN
		SET out_errors := CONCAT( out_errors, '\n', 'Audit table structure do not exists, please check or run the audit setup script again.' );
	END IF;


	-- Check triggers exists
	SET c := ( SELECT GROUP_CONCAT( TRIGGER_NAME SEPARATOR ', ') FROM information_schema.triggers
			WHERE BINARY EVENT_OBJECT_SCHEMA = BINARY audit_schema_name
				AND BINARY EVENT_OBJECT_TABLE = BINARY audit_table_name
				AND BINARY ACTION_TIMING = BINARY 'AFTER' AND BINARY TRIGGER_NAME NOT LIKE BINARY CONCAT('z', audit_table_name, '_%') GROUP BY EVENT_OBJECT_TABLE );
	IF c IS NOT NULL AND LENGTH(c) > 0 THEN
		SET out_errors := CONCAT( out_errors, '\n', 'MySQL 5 only supports one trigger per insert/update/delete action. Currently there are these triggers (', c, ') already assigned to `', audit_schema_name, '`.`', audit_table_name, '`. You must remove them before the audit trigger can be applied' );
	END IF;



	-- Get the first primary key
	SET at_id1 := (SELECT COLUMN_NAME FROM information_schema.columns
			WHERE BINARY TABLE_SCHEMA = BINARY audit_schema_name
				AND BINARY table_name = BINARY audit_table_name
			AND column_key = 'PRI' LIMIT 1);

	-- Get the second primary key
	SET at_id2 := (SELECT COLUMN_NAME FROM information_schema.columns
			WHERE BINARY TABLE_SCHEMA = BINARY audit_schema_name
				AND BINARY table_name = BINARY audit_table_name
			AND column_key = 'PRI' LIMIT 1,1);

	-- Check at least one id exists
	IF at_id1 IS NULL AND at_id2 IS NULL THEN
		SET out_errors := CONCAT( out_errors, '\n', 'The table you specified `', audit_schema_name, '`.`', audit_table_name, '` does not have any primary key.' );
	END IF;



	SET header := CONCAT(
		'-- --------------------------------------------------------------------\n',
		'-- MySQL Audit Trigger\n',
		'-- Copyright (c) 2014 Du T. Dang. MIT License\n',
		'-- https://github.com/hotmit/mysql-sp-audit\n',
		'-- --------------------------------------------------------------------\n\n'
	);


	SET trg_insert := CONCAT( 'DROP TRIGGER IF EXISTS `', audit_schema_name, '`.`z', audit_table_name, '_AINS`\n$$\n',
						'CREATE TRIGGER `', audit_schema_name, '`.`z', audit_table_name, '_AINS` AFTER INSERT ON `', audit_schema_name, '`.`', audit_table_name, '` FOR EACH ROW \nBEGIN\n', header );
	SET trg_update := CONCAT( 'DROP TRIGGER IF EXISTS `', audit_schema_name, '`.`z', audit_table_name, '_AUPD`\n$$\n',
						'CREATE TRIGGER `', audit_schema_name, '`.`z', audit_table_name, '_AUPD` AFTER UPDATE ON `', audit_schema_name, '`.`', audit_table_name, '` FOR EACH ROW \nBEGIN\n', header );
	SET trg_delete := CONCAT( 'DROP TRIGGER IF EXISTS `', audit_schema_name, '`.`z', audit_table_name, '_ADEL`\n$$\n',
						'CREATE TRIGGER `', audit_schema_name, '`.`z', audit_table_name, '_ADEL` AFTER DELETE ON `', audit_schema_name, '`.`', audit_table_name, '` FOR EACH ROW \nBEGIN\n', header );

	SET stmt := 'DECLARE zaudit_last_inserted_id BIGINT(20);\n\n';
	SET trg_insert := CONCAT( trg_insert, stmt );
	SET trg_update := CONCAT( trg_update, stmt );
	SET trg_delete := CONCAT( trg_delete, stmt );


	-- ----------------------------------------------------------
	-- [ Create Insert Statement Into Audit & Audit Meta Tables ]
	-- ----------------------------------------------------------

	SET stmt := CONCAT( 'INSERT IGNORE INTO `', audit_schema_name, '`.zaudit (user, table_name, pk1, ', CASE WHEN at_id2 IS NULL THEN '' ELSE 'pk2, ' END , 'action)  VALUE ( IFNULL( @zaudit_user, USER() ), ',
		'''', audit_table_name, ''', ', 'NEW.`', at_id1, '`, ', IFNULL( CONCAT('NEW.`', at_id2, '`, ') , '') );

	SET trg_insert := CONCAT( trg_insert, stmt, '''INSERT''); \n\n');

	SET stmt := CONCAT( 'INSERT IGNORE INTO `', audit_schema_name, '`.zaudit (user, table_name, pk1, ', CASE WHEN at_id2 IS NULL THEN '' ELSE 'pk2, ' END , 'action)  VALUE ( IFNULL( @zaudit_user, USER() ), ',
		'''', audit_table_name, ''', ', 'OLD.`', at_id1, '`, ', IFNULL( CONCAT('OLD.`', at_id2, '`, ') , '') );

	SET trg_update := CONCAT( trg_update, stmt, '''UPDATE''); \n\n' );
	SET trg_delete := CONCAT( trg_delete, stmt, '''DELETE''); \n\n' );


	SET stmt := 'SET zaudit_last_inserted_id = LAST_INSERT_ID();\n';
	SET trg_insert := CONCAT( trg_insert, stmt );
	SET trg_update := CONCAT( trg_update, stmt );
	SET trg_delete := CONCAT( trg_delete, stmt );

	SET stmt := CONCAT( 'INSERT IGNORE INTO `', audit_schema_name, '`.zaudit_meta (audit_id, col_name, old_value, new_value) VALUES \n' );
	SET trg_insert := CONCAT( trg_insert, '\n', stmt );
	SET trg_update := CONCAT( trg_update, '\n', stmt );
	SET trg_delete := CONCAT( trg_delete, '\n', stmt );

	SET stmt := ( SELECT GROUP_CONCAT(' (zaudit_last_inserted_id, ''', COLUMN_NAME, ''', NULL, ',
						CASE WHEN INSTR( '|binary|varbinary|tinyblob|blob|mediumblob|longblob|', LOWER(DATA_TYPE) ) <> 0 THEN
							'''[UNSUPPORTED BINARY DATATYPE]'''
						ELSE
							CONCAT('NEW.`', COLUMN_NAME, '`')
						END,
						'),'
					SEPARATOR '\n')
					FROM information_schema.columns
						WHERE BINARY TABLE_SCHEMA = BINARY audit_schema_name
							AND BINARY TABLE_NAME = BINARY audit_table_name );

	SET stmt := CONCAT( TRIM( TRAILING ',' FROM stmt ), ';\n\nEND\n$$' );
	SET trg_insert := CONCAT( trg_insert, stmt );



	SET stmt := ( SELECT GROUP_CONCAT('   (zaudit_last_inserted_id, ''', COLUMN_NAME, ''', ',
						CASE WHEN INSTR( '|binary|varbinary|tinyblob|blob|mediumblob|longblob|', LOWER(DATA_TYPE) ) <> 0 THEN
							'''[SAME]'''
						ELSE
							CONCAT('OLD.`', COLUMN_NAME, '`')
						END,
						', ',
						CASE WHEN INSTR( '|binary|varbinary|tinyblob|blob|mediumblob|longblob|', LOWER(DATA_TYPE) ) <> 0 THEN
							CONCAT('CASE WHEN BINARY OLD.`', COLUMN_NAME, '` <=> BINARY NEW.`', COLUMN_NAME, '` THEN ''[SAME]'' ELSE ''[CHANGED]'' END')
						ELSE
							CONCAT('NEW.`', COLUMN_NAME, '`')
						END,
						'),'
					SEPARATOR '\n')
					FROM information_schema.columns
						WHERE BINARY TABLE_SCHEMA = BINARY audit_schema_name
							AND BINARY TABLE_NAME = BINARY audit_table_name );

	SET stmt := CONCAT( TRIM( TRAILING ',' FROM stmt ), ';\n\nEND\n$$' );
	SET trg_update := CONCAT( trg_update, stmt );



	SET stmt := ( SELECT GROUP_CONCAT('   (zaudit_last_inserted_id, ''', COLUMN_NAME, ''', ',
						CASE WHEN INSTR( '|binary|varbinary|tinyblob|blob|mediumblob|longblob|', LOWER(DATA_TYPE) ) <> 0 THEN
							'''[UNSUPPORTED BINARY DATATYPE]'''
						ELSE
							CONCAT('OLD.`', COLUMN_NAME, '`')
						END,
						', NULL ),'
					SEPARATOR '\n')
					FROM information_schema.columns
						WHERE BINARY TABLE_SCHEMA = BINARY audit_schema_name
							AND BINARY TABLE_NAME = BINARY audit_table_name );


	SET stmt := CONCAT( TRIM( TRAILING ',' FROM stmt ), ';\n\nEND\n$$' );
	SET trg_delete := CONCAT( trg_delete, stmt );

	-- -----------------------------------------------
	-- [ Generating Helper Views For The Audit Table ]
	-- -----------------------------------------------
	SET stmt := CONCAT( 'DROP VIEW IF EXISTS `', audit_schema_name, '`.`zvw_audit_', audit_table_name, '_meta`\n$$\n',
						'CREATE VIEW `', audit_schema_name, '`.`zvw_audit_', audit_table_name, '_meta` AS \n', header,
						'SELECT za.audit_id, zm.audit_meta_id, za.user, \n',
						'	za.pk1, za.pk2,\n',
						'	za.action, zm.col_name, zm.old_value, zm.new_value, za.timestamp\n',
						'FROM `', audit_schema_name, '`.zaudit za \n',
						'INNER JOIN `', audit_schema_name, '`.zaudit_meta zm ON za.audit_id = zm.audit_id \n',
						'WHERE za.table_name = ''', audit_table_name, '''');

	SET vw_audit_meta := CONCAT( stmt, '$$' );


	SET stmt := ( SELECT GROUP_CONCAT( 	'		MAX((CASE WHEN zm.col_name = ''', COLUMN_NAME, ''' THEN zm.old_value ELSE NULL END)) AS `', COLUMN_NAME, '_old`, \n',
										'		MAX((CASE WHEN zm.col_name = ''', COLUMN_NAME, ''' THEN zm.new_value ELSE NULL END)) AS `', COLUMN_NAME, '_new`, \n'
						SEPARATOR '\n')
					FROM information_schema.columns
						WHERE BINARY TABLE_SCHEMA = BINARY audit_schema_name
							AND BINARY TABLE_NAME = BINARY audit_table_name
				);
	SET stmt := TRIM( TRAILING ', \n' FROM stmt );
	SET stmt := ( SELECT CONCAT( 	'DROP VIEW IF EXISTS `', audit_schema_name, '`.`zvw_audit_', audit_table_name, '`\n$$\n',
									'CREATE VIEW `', audit_schema_name, '`.`zvw_audit_', audit_table_name, '` AS \n', header,
									'SELECT za.audit_id, za.user, za.pk1, za.pk2,\n',
									'za.action, za.timestamp, \n',
									stmt , '\n',
									'	FROM `', audit_schema_name, '`.zaudit za \n',
									'	INNER JOIN `', audit_schema_name, '`.zaudit_meta zm ON za.audit_id = zm.audit_id \n'
									'WHERE za.table_name = ''', audit_table_name, '''\n',
									'GROUP BY zm.audit_id') );

	SET vw_audit := CONCAT( stmt, '\n$$' );


	-- SELECT trg_insert, trg_update, trg_delete, vw_audit, vw_audit_meta;

	SET stmt = CONCAT(
		'-- ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^\n',
		'-- --------------------------------------------------------------------\n',
		'-- Audit Script For `',audit_schema_name, '`.`', audit_table_name, '`\n',
		'-- Date Generated: ', NOW(), '\n',
		'-- Generated By: ', CURRENT_USER(), '\n',
		'-- BEGIN\n',
		'-- --------------------------------------------------------------------\n\n'
		'DELIMITER $$',
		'\n\n-- [ `',audit_schema_name, '`.`', audit_table_name, '` After Insert Trigger Code ]\n',
		'-- -----------------------------------------------------------\n',
		trg_insert,
		'\n\n-- [ `',audit_schema_name, '`.`', audit_table_name, '` After Update Trigger Code ]\n',
		'-- -----------------------------------------------------------\n',
		trg_update,
		'\n\n-- [ `',audit_schema_name, '`.`', audit_table_name, '` After Delete Trigger Code ]\n',
		'-- -----------------------------------------------------------\n',
		trg_delete,
		'\n\n-- [ `',audit_schema_name, '`.`', audit_table_name, '` Audit Meta View ]\n',
		'-- -----------------------------------------------------------\n',
		vw_audit_meta,
		'\n\n-- [ `',audit_schema_name, '`.`', audit_table_name, '` Audit View ]\n',
		'-- -----------------------------------------------------------\n',
		vw_audit,
		'\n\n',
		'-- --------------------------------------------------------------------\n',
		'-- END\n',
		'-- Audit Script For `',audit_schema_name, '`.`', audit_table_name, '`\n',
		'-- --------------------------------------------------------------------\n\n',
		'-- $$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$\n'
		);

	-- SELECT stmt AS `Audit Script`, out_errors AS `ERRORS`;

	SET script := stmt;
	SET errors := out_errors;
END$$

CREATE DEFINER=`d02dbcf8`@`localhost` PROCEDURE `zsp_generate_batch_audit` (IN `audit_schema_name` VARCHAR(255), IN `audit_table_names` VARCHAR(255), OUT `out_script` LONGTEXT, OUT `out_error_msgs` LONGTEXT)  main_block: BEGIN

	DECLARE s, e, scripts, error_msgs LONGTEXT;
	DECLARE audit_table_name VARCHAR(255);
	DECLARE done INT DEFAULT FALSE;
	DECLARE cursor_table_list CURSOR FOR SELECT TABLE_NAME FROM INFORMATION_SCHEMA.TABLES
		WHERE BINARY TABLE_TYPE = BINARY 'BASE TABLE'
			AND BINARY TABLE_SCHEMA = BINARY audit_schema_name
			AND LOCATE( BINARY CONCAT(TABLE_NAME, ','), BINARY CONCAT(audit_table_names, ',') ) > 0;

	DECLARE CONTINUE HANDLER
		FOR NOT FOUND SET done = TRUE;

	SET scripts := '';
	SET error_msgs := '';

	OPEN cursor_table_list;

	cur_loop: LOOP
		FETCH cursor_table_list INTO audit_table_name;

		IF done THEN
			LEAVE cur_loop;
		END IF;

		CALL zsp_generate_audit(audit_schema_name, audit_table_name, s, e);

		SET scripts := CONCAT( scripts, '\n\n', IFNULL(s, '') );
		SET error_msgs := CONCAT( error_msgs, '\n\n', IFNULL(e, '') );

	END LOOP;

	CLOSE cursor_table_list;

	SET out_script := scripts;
	SET out_error_msgs := error_msgs;
END$$

CREATE DEFINER=`d02dbcf8`@`localhost` PROCEDURE `zsp_generate_batch_remove_audit` (IN `audit_schema_name` VARCHAR(255), IN `audit_table_names` VARCHAR(255), OUT `out_script` LONGTEXT)  main_block: BEGIN

	DECLARE s, scripts LONGTEXT;
	DECLARE audit_table_name VARCHAR(255);
	DECLARE done INT DEFAULT FALSE;
	DECLARE cursor_table_list CURSOR FOR SELECT TABLE_NAME FROM INFORMATION_SCHEMA.TABLES
		WHERE BINARY TABLE_TYPE = BINARY 'BASE TABLE'
			AND BINARY TABLE_SCHEMA = BINARY audit_schema_name
			AND LOCATE( BINARY CONCAT(TABLE_NAME, ','), BINARY CONCAT(audit_table_names, ',') ) > 0;

	DECLARE CONTINUE HANDLER
		FOR NOT FOUND SET done = TRUE;

	SET scripts := '';

	OPEN cursor_table_list;

	cur_loop: LOOP
		FETCH cursor_table_list INTO audit_table_name;

		IF done THEN
			LEAVE cur_loop;
		END IF;

		CALL zsp_generate_remove_audit(audit_schema_name, audit_table_name, s);

		SET scripts := CONCAT( scripts, '\n\n', IFNULL(s, '') );

	END LOOP;

	CLOSE cursor_table_list;

	SET out_script := scripts;
END$$

CREATE DEFINER=`d02dbcf8`@`localhost` PROCEDURE `zsp_generate_remove_audit` (IN `audit_schema_name` VARCHAR(255), IN `audit_table_name` VARCHAR(255), OUT `script` LONGTEXT)  main_block: BEGIN

	SET script := CONCAT(
		'-- ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^\n',
		'-- --------------------------------------------------------------------\n',
		'-- Audit Removal Script For `',audit_schema_name, '`.`', audit_table_name, '` \n',
		'-- Date Generated: ', NOW(), '\n',
		'-- Generated By: ', CURRENT_USER(), '\n',
		'-- BEGIN\n',
		'-- --------------------------------------------------------------------\n\n',
		'DELIMITER $$\n\n',

		'DROP TRIGGER IF EXISTS `', audit_schema_name, '`.`z', audit_table_name, '_AINS`\n$$\n',
		'DROP TRIGGER IF EXISTS `', audit_schema_name, '`.`z', audit_table_name, '_AUPD`\n$$\n',
		'DROP TRIGGER IF EXISTS `', audit_schema_name, '`.`z', audit_table_name, '_ADEL`\n$$\n',

		'DROP VIEW IF EXISTS `', audit_schema_name, '`.`zvw_audit_', audit_table_name, '_meta`\n$$\n',
		'DROP VIEW IF EXISTS `', audit_schema_name, '`.`zvw_audit_', audit_table_name, '`\n$$\n',

		'\n\n',
		'-- --------------------------------------------------------------------\n',
		'-- END\n',
		'-- Audit Removal Script For `',audit_schema_name, '`.`', audit_table_name, '`\n',
		'-- --------------------------------------------------------------------\n\n',
		'-- $$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$\n'
	);

END$$

DELIMITER ;

-- --------------------------------------------------------

--
-- Tabellenstruktur für Tabelle `Benutzer`
--

CREATE TABLE IF NOT EXISTS `Benutzer` (
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
  PRIMARY KEY (`ID`),
  UNIQUE KEY `Name_Unique` (`Name`),
  KEY `Role_ID` (`Role_ID`),
  KEY `Depot_ID` (`Depot_ID`),
  KEY `BenutzerAender_Benutzer` (`AenderBenutzer_ID`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_german2_ci;

-- --------------------------------------------------------

--
-- Stellvertreter-Struktur des Views `BenutzerBestellView`
-- (Siehe unten für die tatsächliche Ansicht)
--
CREATE TABLE IF NOT EXISTS `BenutzerBestellView` (
`Benutzer_ID` int(11)
,`Benutzer` varchar(255)
,`Depot_ID` int(11)
,`Depot` varchar(255)
,`Produkt_ID` int(11)
,`Produkt` varchar(511)
,`Beschreibung` varchar(255)
,`Einheit` varchar(7)
,`Menge` decimal(8,2)
,`Woche` decimal(6,2)
,`Anzahl` decimal(42,0)
,`AnzahlModul` decimal(42,0)
,`AnzahlZusatz` decimal(42,0)
,`Urlaub` int(1)
,`Kommentar` mediumtext
);

-- --------------------------------------------------------

--
-- Stellvertreter-Struktur des Views `BenutzerBestellViewUnsorted`
-- (Siehe unten für die tatsächliche Ansicht)
--
CREATE TABLE IF NOT EXISTS `BenutzerBestellViewUnsorted` (
`Benutzer_ID` int(11)
,`Benutzer` varchar(255)
,`Depot_ID` int(11)
,`Depot` varchar(255)
,`Produkt_ID` int(11)
,`Produkt` varchar(511)
,`Beschreibung` varchar(255)
,`Einheit` varchar(7)
,`Menge` decimal(8,2)
,`Kommentar` mediumtext
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

CREATE TABLE IF NOT EXISTS `BenutzerModulAbo` (
  `ID` int(11) NOT NULL AUTO_INCREMENT,
  `Benutzer_ID` int(11) NOT NULL,
  `Modul_ID` int(11) NOT NULL,
  `StartWoche` decimal(6,2) NOT NULL DEFAULT '2019.01',
  `EndWoche` decimal(6,2) DEFAULT NULL,
  `Anzahl` int(11) NOT NULL DEFAULT '1',
  `Kommentar` varchar(31) COLLATE utf8_german2_ci DEFAULT NULL,
  `ErstellZeitpunkt` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `AenderZeitpunkt` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `AenderBenutzer_ID` int(11) DEFAULT NULL,
  PRIMARY KEY (`ID`),
  KEY `BenutzerModulAboModul` (`Modul_ID`) USING BTREE,
  KEY `BenutzerModulAboBenutzer` (`Benutzer_ID`) USING BTREE
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_german2_ci;

-- --------------------------------------------------------

--
-- Tabellenstruktur für Tabelle `BenutzerUrlaub`
--

CREATE TABLE IF NOT EXISTS `BenutzerUrlaub` (
  `ID` int(11) NOT NULL AUTO_INCREMENT,
  `Benutzer_ID` int(11) NOT NULL,
  `Woche` decimal(6,2) NOT NULL,
  `ErstellZeitpunkt` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `AenderZeitpunkt` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `AenderBenutzer_ID` int(11) DEFAULT NULL,
  PRIMARY KEY (`ID`),
  KEY `BenutzerUrlaubAender_Benutzer` (`AenderBenutzer_ID`),
  KEY `BenutzerUrlaub_Benutzer` (`Benutzer_ID`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_german2_ci;

-- --------------------------------------------------------

--
-- Stellvertreter-Struktur des Views `BenutzerView`
-- (Siehe unten für die tatsächliche Ansicht)
--
CREATE TABLE IF NOT EXISTS `BenutzerView` (
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
,`Modul` mediumtext
,`Role` varchar(255)
);

-- --------------------------------------------------------

--
-- Tabellenstruktur für Tabelle `BenutzerZusatzBestellung`
--

CREATE TABLE IF NOT EXISTS `BenutzerZusatzBestellung` (
  `ID` int(11) NOT NULL AUTO_INCREMENT,
  `Benutzer_ID` int(11) NOT NULL,
  `Produkt_ID` int(11) NOT NULL,
  `Woche` decimal(6,2) NOT NULL,
  `Anzahl` int(11) NOT NULL DEFAULT '1',
  `Kommentar` varchar(255) COLLATE utf8_german2_ci DEFAULT NULL,
  `ErstellZeitpunkt` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `AenderZeitpunkt` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `AenderBenutzer_ID` int(11) DEFAULT NULL,
  PRIMARY KEY (`ID`),
  KEY `Bestellung_Produkt` (`Produkt_ID`),
  KEY `Bestellung_AenderBenutzer` (`AenderBenutzer_ID`),
  KEY `Bestellung_Benutzer` (`Benutzer_ID`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_german2_ci;

-- --------------------------------------------------------

--
-- Tabellenstruktur für Tabelle `Depot`
--

CREATE TABLE IF NOT EXISTS `Depot` (
  `ID` int(11) NOT NULL AUTO_INCREMENT,
  `Name` varchar(255) COLLATE utf8_german2_ci NOT NULL,
  `KurzName` varchar(7) COLLATE utf8_german2_ci NOT NULL,
  `Beschreibung` varchar(2047) COLLATE utf8_german2_ci NOT NULL DEFAULT '',
  `VerwalterBenutzer_ID` int(11) DEFAULT NULL,
  `BestellerBenutzer_ID` int(11) DEFAULT NULL,
  `ErstellZeitpunkt` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `AenderZeitpunkt` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `AenderBenutzer_ID` int(11) DEFAULT NULL,
  PRIMARY KEY (`ID`),
  KEY `DepotAenderBenutzer` (`AenderBenutzer_ID`),
  KEY `DepotBestellerBenutzer` (`BestellerBenutzer_ID`) USING BTREE,
  KEY `DepotVerwalterBenutzer` (`VerwalterBenutzer_ID`) USING BTREE
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_german2_ci;

-- --------------------------------------------------------

--
-- Stellvertreter-Struktur des Views `DepotBestellView`
-- (Siehe unten für die tatsächliche Ansicht)
--
CREATE TABLE IF NOT EXISTS `DepotBestellView` (
`Depot_ID` int(11)
,`Depot` varchar(255)
,`Produkt_ID` int(11)
,`Produkt` varchar(511)
,`Beschreibung` varchar(255)
,`Einheit` varchar(7)
,`Menge` decimal(8,2)
,`Woche` decimal(6,2)
,`Anzahl` decimal(64,0)
,`AnzahlModul` decimal(64,0)
,`AnzahlZusatz` decimal(64,0)
,`Kommentar` mediumtext
,`Urlaub` decimal(32,0)
);

-- --------------------------------------------------------

--
-- Stellvertreter-Struktur des Views `DepotBestellViewUnsorted`
-- (Siehe unten für die tatsächliche Ansicht)
--
CREATE TABLE IF NOT EXISTS `DepotBestellViewUnsorted` (
`Depot_ID` int(11)
,`Depot` varchar(255)
,`Produkt_ID` int(11)
,`Produkt` varchar(511)
,`Beschreibung` varchar(255)
,`Einheit` varchar(7)
,`Menge` decimal(8,2)
,`Woche` decimal(6,2)
,`Kommentar` mediumtext
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
CREATE TABLE IF NOT EXISTS `GesamtBestellView` (
`Produkt_ID` int(11)
,`Produkt` varchar(511)
,`Beschreibung` varchar(255)
,`Einheit` varchar(7)
,`Menge` decimal(8,2)
,`Woche` decimal(6,2)
,`Anzahl` decimal(64,0)
,`AnzahlModul` decimal(64,0)
,`AnzahlZusatz` decimal(64,0)
,`Kommentar` mediumtext
,`Urlaub` decimal(32,0)
);

-- --------------------------------------------------------

--
-- Stellvertreter-Struktur des Views `GesamtBestellViewUnsorted`
-- (Siehe unten für die tatsächliche Ansicht)
--
CREATE TABLE IF NOT EXISTS `GesamtBestellViewUnsorted` (
`Produkt_ID` int(11)
,`Produkt` varchar(511)
,`Beschreibung` varchar(255)
,`Einheit` varchar(7)
,`Menge` decimal(8,2)
,`Woche` decimal(6,2)
,`Kommentar` mediumtext
,`Anzahl` decimal(64,0)
,`AnzahlModul` decimal(64,0)
,`AnzahlZusatz` decimal(64,0)
,`Urlaub` decimal(32,0)
);

-- --------------------------------------------------------

--
-- Tabellenstruktur für Tabelle `Modul`
--

CREATE TABLE IF NOT EXISTS `Modul` (
  `ID` int(11) NOT NULL AUTO_INCREMENT,
  `Name` varchar(255) COLLATE utf8_german2_ci NOT NULL,
  `Beschreibung` varchar(255) COLLATE utf8_german2_ci NOT NULL DEFAULT '',
  `AnzahlProAnteil` int(11) NOT NULL DEFAULT '0',
  `WechselWochen` varchar(255) COLLATE utf8_german2_ci NOT NULL,
  `ErstellZeitpunkt` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `AenderZeitpunkt` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `AenderBenutzer_ID` int(11) DEFAULT NULL,
  PRIMARY KEY (`ID`),
  KEY `KorbAenderBenutzer` (`AenderBenutzer_ID`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_german2_ci;

-- --------------------------------------------------------

--
-- Tabellenstruktur für Tabelle `ModulInhalt`
--

CREATE TABLE IF NOT EXISTS `ModulInhalt` (
  `ID` int(11) NOT NULL AUTO_INCREMENT,
  `Modul_ID` int(11) NOT NULL,
  `Produkt_ID` int(11) NOT NULL,
  `Anzahl` int(11) NOT NULL DEFAULT '1',
  `MindestAnzahl` int(11) NOT NULL DEFAULT '0',
  `MaximalAnzahl` int(11) NOT NULL DEFAULT '99',
  `ErstellZeitpunkt` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `AenderZeitpunkt` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `AenderBenutzer_ID` int(11) DEFAULT NULL,
  PRIMARY KEY (`ID`),
  KEY `ModulInhalt_Modul` (`Modul_ID`) USING BTREE,
  KEY `ModulInhalt_Produkt` (`Produkt_ID`) USING BTREE,
  KEY `ModulInhalt_Benutzer` (`AenderBenutzer_ID`) USING BTREE
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_german2_ci;

-- --------------------------------------------------------

--
-- Stellvertreter-Struktur des Views `ModulInhaltView`
-- (Siehe unten für die tatsächliche Ansicht)
--
CREATE TABLE IF NOT EXISTS `ModulInhaltView` (
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

CREATE TABLE IF NOT EXISTS `ModulInhaltWoche` (
  `ID` int(11) NOT NULL AUTO_INCREMENT,
  `ModulInhalt_ID` int(11) NOT NULL,
  `Woche` decimal(6,2) NOT NULL,
  `ErstellZeitpunkt` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `AenderZeitpunkt` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `AenderBenutzer_ID` int(11) DEFAULT NULL,
  PRIMARY KEY (`ID`),
  UNIQUE KEY `Modulwocheuniqu` (`ModulInhalt_ID`,`Woche`) USING BTREE,
  KEY `ModulInhaltWoche_AenderBenutzer` (`AenderBenutzer_ID`) USING BTREE
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_german2_ci;

-- --------------------------------------------------------

--
-- Tabellenstruktur für Tabelle `Produkt`
--

CREATE TABLE IF NOT EXISTS `Produkt` (
  `ID` int(11) NOT NULL AUTO_INCREMENT,
  `Name` varchar(511) COLLATE utf8_german2_ci GENERATED ALWAYS AS (if((`Menge` <> 1.00),concat(`Produkt`,', ',(trim(`Menge`) + 0),`Einheit`),`Produkt`)) VIRTUAL,
  `Produkt` varchar(255) COLLATE utf8_german2_ci NOT NULL,
  `Beschreibung` varchar(255) COLLATE utf8_german2_ci NOT NULL DEFAULT '',
  `Einheit` varchar(7) COLLATE utf8_german2_ci NOT NULL DEFAULT 'Stueck',
  `Menge` decimal(8,2) NOT NULL DEFAULT '1.00',
  `Punkte` int(11) NOT NULL DEFAULT '1',
  `Nr` int(11) NOT NULL DEFAULT '1',
  `AnzahlZusatzBestellungMax` int(11) NOT NULL DEFAULT '0',
  `ErstellZeitpunkt` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `AenderZeitpunkt` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `AenderBenutzer_ID` int(11) DEFAULT NULL,
  PRIMARY KEY (`ID`),
  KEY `ProduktAenderBenutzer` (`AenderBenutzer_ID`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_german2_ci;

-- --------------------------------------------------------

--
-- Tabellenstruktur für Tabelle `Recht`
--

CREATE TABLE IF NOT EXISTS `Recht` (
  `ID` int(11) NOT NULL AUTO_INCREMENT,
  `Role_ID` int(11) NOT NULL,
  `Tabelle` varchar(255) COLLATE utf8_german2_ci DEFAULT NULL,
  `Spalte` varchar(255) COLLATE utf8_german2_ci DEFAULT NULL,
  `SpalteBenutzerID` varchar(255) COLLATE utf8_german2_ci DEFAULT NULL,
  `LeseAlle` tinyint(1) NOT NULL DEFAULT '1',
  `LeseEigene` tinyint(1) NOT NULL DEFAULT '1',
  `SchreibeAlle` tinyint(1) NOT NULL DEFAULT '0',
  `SchreibeEigene` tinyint(1) NOT NULL DEFAULT '1',
  PRIMARY KEY (`ID`),
  KEY `Role_ID` (`Role_ID`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_german2_ci;

-- --------------------------------------------------------

--
-- Tabellenstruktur für Tabelle `Role`
--

CREATE TABLE IF NOT EXISTS `Role` (
  `ID` int(11) NOT NULL AUTO_INCREMENT,
  `Name` varchar(255) COLLATE utf8_german2_ci NOT NULL,
  `LeseRechtDefault` tinyint(1) NOT NULL DEFAULT '1',
  `SchreibRechtDefault` tinyint(1) NOT NULL DEFAULT '0',
  PRIMARY KEY (`ID`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_german2_ci;

-- --------------------------------------------------------

--
-- Tabellenstruktur für Tabelle `Solawi`
--

CREATE TABLE IF NOT EXISTS `Solawi` (
  `ID` int(11) NOT NULL AUTO_INCREMENT,
  `Name` varchar(255) COLLATE utf8_german2_ci NOT NULL,
  `Wert` varchar(255) COLLATE utf8_german2_ci NOT NULL,
  `ErstellZeitpunkt` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `AenderZeitpunkt` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `AenderBenutzer_ID` int(11) DEFAULT NULL,
  PRIMARY KEY (`ID`)
) ENGINE=MyISAM DEFAULT CHARSET=utf8 COLLATE=utf8_german2_ci;

-- --------------------------------------------------------

--
-- Tabellenstruktur für Tabelle `Woche`
--

CREATE TABLE `Woche` (
  `ID` int(11) NOT NULL,
  `Woche` decimal(6,2) NOT NULL,
  `Jahr` int(11) NOT NULL,
  `Kalenderwoche` int(11) NOT NULL,
  `Donnerstag` int(11) NOT NULL,
  `DonnerstagMonat` int(11) NOT NULL,
  `DonnerstagDesMonats` int(11) NOT NULL,
  `AenderZeitpunkt` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `ErstellZeitpunkt` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `AenderBenutzer_ID` int(11) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_german2_ci;

--
-- Indizes der exportierten Tabellen
--

--
-- Indizes für die Tabelle `Woche`
--
ALTER TABLE `Woche`
  ADD PRIMARY KEY (`ID`);

--
-- AUTO_INCREMENT für exportierte Tabellen
--

--
-- AUTO_INCREMENT für Tabelle `Woche`
--
ALTER TABLE `Woche`
  MODIFY `ID` int(11) NOT NULL AUTO_INCREMENT;
COMMIT;

--
-- Struktur des Views `BenutzerBestellView`
--
DROP TABLE IF EXISTS `BenutzerBestellView`;

CREATE ALGORITHM=UNDEFINED DEFINER=`d02dbcf8`@`localhost` SQL SECURITY DEFINER VIEW `BenutzerBestellView`  AS  select `BenutzerBestellViewUnsorted`.`Benutzer_ID` AS `Benutzer_ID`,`BenutzerBestellViewUnsorted`.`Benutzer` AS `Benutzer`,`BenutzerBestellViewUnsorted`.`Depot_ID` AS `Depot_ID`,`BenutzerBestellViewUnsorted`.`Depot` AS `Depot`,`BenutzerBestellViewUnsorted`.`Produkt_ID` AS `Produkt_ID`,`BenutzerBestellViewUnsorted`.`Produkt` AS `Produkt`,`BenutzerBestellViewUnsorted`.`Beschreibung` AS `Beschreibung`,`BenutzerBestellViewUnsorted`.`Einheit` AS `Einheit`,`BenutzerBestellViewUnsorted`.`Menge` AS `Menge`,`BenutzerBestellViewUnsorted`.`Woche` AS `Woche`,`BenutzerBestellViewUnsorted`.`Anzahl` AS `Anzahl`,`BenutzerBestellViewUnsorted`.`AnzahlModul` AS `AnzahlModul`,`BenutzerBestellViewUnsorted`.`AnzahlZusatz` AS `AnzahlZusatz`,`BenutzerBestellViewUnsorted`.`Urlaub` AS `Urlaub`,`BenutzerBestellViewUnsorted`.`Kommentar` AS `Kommentar` from `BenutzerBestellViewUnsorted` order by `BenutzerBestellViewUnsorted`.`Depot`,`BenutzerBestellViewUnsorted`.`Benutzer`,`BenutzerBestellViewUnsorted`.`Produkt` ;

-- --------------------------------------------------------

--
-- Struktur des Views `BenutzerBestellViewUnsorted`
--
DROP TABLE IF EXISTS `BenutzerBestellViewUnsorted`;

CREATE ALGORITHM=UNDEFINED DEFINER=`d02dbcf8`@`localhost` SQL SECURITY DEFINER VIEW `BenutzerBestellViewUnsorted`  AS  select `u`.`Benutzer_ID` AS `Benutzer_ID`,`Benutzer`.`Name` AS `Benutzer`,`Depot`.`ID` AS `Depot_ID`,`Depot`.`Name` AS `Depot`,`u`.`Produkt_ID` AS `Produkt_ID`,`Produkt`.`Name` AS `Produkt`,`Produkt`.`Beschreibung` AS `Beschreibung`,`Produkt`.`Einheit` AS `Einheit`,`Produkt`.`Menge` AS `Menge`,group_concat((case when ((trim(`u`.`Kommentar`) = '') or (trim(`u`.`Kommentar`) = '-')) then NULL else `u`.`Kommentar` end) separator ', ') AS `Kommentar`,`u`.`Woche` AS `Woche`,(case when isnull(`BenutzerUrlaub`.`ID`) then sum(`u`.`Anzahl`) else 0 end) AS `Anzahl`,sum((case when (`u`.`Quelle` = 1) then `u`.`Anzahl` else 0 end)) AS `AnzahlModul`,sum((case when (`u`.`Quelle` = 2) then `u`.`Anzahl` else 0 end)) AS `AnzahlZusatz`,(`BenutzerUrlaub`.`ID` is not null) AS `Urlaub` from ((((((select 1 AS `Quelle`,`BenutzerModulAbo`.`Benutzer_ID` AS `Benutzer_ID`,`ModulInhalt`.`Produkt_ID` AS `Produkt_ID`,(`ModulInhalt`.`Anzahl` * `BenutzerModulAbo`.`Anzahl`) AS `Anzahl`,`ModulInhaltWoche`.`Woche` AS `Woche`,`BenutzerModulAbo`.`Kommentar` AS `Kommentar` from ((`ModulInhalt` join `ModulInhaltWoche` on((`ModulInhaltWoche`.`ModulInhalt_ID` = `ModulInhalt`.`ID`))) join `BenutzerModulAbo` on(((`BenutzerModulAbo`.`Modul_ID` = `ModulInhalt`.`Modul_ID`) and (isnull(`BenutzerModulAbo`.`StartWoche`) or (`ModulInhaltWoche`.`Woche` >= `BenutzerModulAbo`.`StartWoche`)) and (isnull(`BenutzerModulAbo`.`EndWoche`) or (`ModulInhaltWoche`.`Woche` <= `BenutzerModulAbo`.`EndWoche`)))))) union all (select 2 AS `Quelle`,`BenutzerZusatzBestellung`.`Benutzer_ID` AS `Benutzer_ID`,`BenutzerZusatzBestellung`.`Produkt_ID` AS `Produkt_ID`,`BenutzerZusatzBestellung`.`Anzahl` AS `Anzahl`,`BenutzerZusatzBestellung`.`Woche` AS `Woche`,`BenutzerZusatzBestellung`.`Kommentar` AS `Kommentar` from `BenutzerZusatzBestellung`)) `u` join `Produkt` on((`u`.`Produkt_ID` = `Produkt`.`ID`))) join `Benutzer` on((`u`.`Benutzer_ID` = `Benutzer`.`ID`))) join `Depot` on((`Benutzer`.`Depot_ID` = `Depot`.`ID`))) left join `BenutzerUrlaub` on(((`BenutzerUrlaub`.`Benutzer_ID` = `u`.`Benutzer_ID`) and (`BenutzerUrlaub`.`Woche` = `u`.`Woche`)))) group by `u`.`Benutzer_ID`,`Benutzer`.`Name`,`Depot`.`ID`,`Depot`.`Name`,`u`.`Produkt_ID`,`Produkt`.`Name`,`Produkt`.`Beschreibung`,`Produkt`.`Einheit`,`Produkt`.`Menge`,`u`.`Woche`,`BenutzerUrlaub`.`ID` ;

-- --------------------------------------------------------

--
-- Struktur des Views `BenutzerView`
--
DROP TABLE IF EXISTS `BenutzerView`;

CREATE ALGORITHM=UNDEFINED DEFINER=`d02dbcf8`@`localhost` SQL SECURITY DEFINER VIEW `BenutzerView`  AS  select `Benutzer`.`ID` AS `ID`,`Benutzer`.`Name` AS `Name`,`Benutzer`.`Passwort` AS `Passwort`,`Benutzer`.`Cookie` AS `Cookie`,`Benutzer`.`Role_ID` AS `Role_ID`,`Benutzer`.`Depot_ID` AS `Depot_ID`,`Benutzer`.`Anteile` AS `Anteile`,`Benutzer`.`PunkteStand` AS `PunkteStand`,`Benutzer`.`PunkteWoche` AS `PunkteWoche`,`Benutzer`.`ErstellZeitpunkt` AS `ErstellZeitpunkt`,`Benutzer`.`AenderZeitpunkt` AS `AenderZeitpunkt`,`Benutzer`.`AenderBenutzer_ID` AS `AenderBenutzer_ID`,`Depot`.`Name` AS `Depot`,group_concat(concat(convert(convert((case when (`BenutzerModulAbo`.`Anzahl` <> 1) then concat(`BenutzerModulAbo`.`Anzahl`,'x ') else '' end) using latin1) using utf8),`Modul`.`Name`,convert(convert((case when (isnull(`BenutzerModulAbo`.`Kommentar`) or (`BenutzerModulAbo`.`Kommentar` = '')) then '' else concat(' ',`BenutzerModulAbo`.`Kommentar`) end) using latin1) using utf8)) order by `Modul`.`ID` ASC separator '; ') AS `Modul`,`Role`.`Name` AS `Role` from ((((`Benutzer` left join `Role` on((`Benutzer`.`Role_ID` = `Role`.`ID`))) left join `Depot` on((`Depot`.`ID` = `Benutzer`.`Depot_ID`))) left join `BenutzerModulAbo` on((`BenutzerModulAbo`.`Benutzer_ID` = `Benutzer`.`ID`))) left join `Modul` on((`Modul`.`ID` = `BenutzerModulAbo`.`Modul_ID`))) where ((isnull(`BenutzerModulAbo`.`StartWoche`) or ((`BenutzerModulAbo`.`StartWoche` * 100) <= yearweek((curdate() + interval 3 day),1))) and (isnull(`BenutzerModulAbo`.`EndWoche`) or ((`BenutzerModulAbo`.`EndWoche` * 100) >= yearweek((curdate() + interval 3 day),1)))) group by `Benutzer`.`ID` ;

-- --------------------------------------------------------

--
-- Struktur des Views `DepotBestellView`
--
DROP TABLE IF EXISTS `DepotBestellView`;

CREATE ALGORITHM=UNDEFINED DEFINER=`d02dbcf8`@`localhost` SQL SECURITY DEFINER VIEW `DepotBestellView`  AS  select `DepotBestellViewUnsorted`.`Depot_ID` AS `Depot_ID`,`DepotBestellViewUnsorted`.`Depot` AS `Depot`,`DepotBestellViewUnsorted`.`Produkt_ID` AS `Produkt_ID`,`DepotBestellViewUnsorted`.`Produkt` AS `Produkt`,`DepotBestellViewUnsorted`.`Beschreibung` AS `Beschreibung`,`DepotBestellViewUnsorted`.`Einheit` AS `Einheit`,`DepotBestellViewUnsorted`.`Menge` AS `Menge`,`DepotBestellViewUnsorted`.`Woche` AS `Woche`,`DepotBestellViewUnsorted`.`Anzahl` AS `Anzahl`,`DepotBestellViewUnsorted`.`AnzahlModul` AS `AnzahlModul`,`DepotBestellViewUnsorted`.`AnzahlZusatz` AS `AnzahlZusatz`,`DepotBestellViewUnsorted`.`Kommentar` AS `Kommentar`,`DepotBestellViewUnsorted`.`Urlaub` AS `Urlaub` from `DepotBestellViewUnsorted` order by `DepotBestellViewUnsorted`.`Depot`,`DepotBestellViewUnsorted`.`Produkt` ;

-- --------------------------------------------------------

--
-- Struktur des Views `DepotBestellViewUnsorted`
--
DROP TABLE IF EXISTS `DepotBestellViewUnsorted`;

CREATE ALGORITHM=UNDEFINED DEFINER=`d02dbcf8`@`localhost` SQL SECURITY DEFINER VIEW `DepotBestellViewUnsorted`  AS  select `BenutzerBestellView`.`Depot_ID` AS `Depot_ID`,`BenutzerBestellView`.`Depot` AS `Depot`,`BenutzerBestellView`.`Produkt_ID` AS `Produkt_ID`,`BenutzerBestellView`.`Produkt` AS `Produkt`,`BenutzerBestellView`.`Beschreibung` AS `Beschreibung`,`BenutzerBestellView`.`Einheit` AS `Einheit`,`BenutzerBestellView`.`Menge` AS `Menge`,`BenutzerBestellView`.`Woche` AS `Woche`,group_concat((case when (trim(`BenutzerBestellView`.`Kommentar`) = '') then NULL else `BenutzerBestellView`.`Kommentar` end) separator ', ') AS `Kommentar`,sum(`BenutzerBestellView`.`Anzahl`) AS `Anzahl`,sum(`BenutzerBestellView`.`AnzahlModul`) AS `AnzahlModul`,sum(`BenutzerBestellView`.`AnzahlZusatz`) AS `AnzahlZusatz`,sum(`BenutzerBestellView`.`Urlaub`) AS `Urlaub` from `BenutzerBestellView` group by `BenutzerBestellView`.`Produkt_ID`,`BenutzerBestellView`.`Woche`,`BenutzerBestellView`.`Depot_ID` order by `BenutzerBestellView`.`Depot`,`BenutzerBestellView`.`Produkt` ;

-- --------------------------------------------------------

--
-- Struktur des Views `GesamtBestellView`
--
DROP TABLE IF EXISTS `GesamtBestellView`;

CREATE ALGORITHM=UNDEFINED DEFINER=`d02dbcf8`@`localhost` SQL SECURITY DEFINER VIEW `GesamtBestellView`  AS  select `GesamtBestellViewUnsorted`.`Produkt_ID` AS `Produkt_ID`,`GesamtBestellViewUnsorted`.`Produkt` AS `Produkt`,`GesamtBestellViewUnsorted`.`Beschreibung` AS `Beschreibung`,`GesamtBestellViewUnsorted`.`Einheit` AS `Einheit`,`GesamtBestellViewUnsorted`.`Menge` AS `Menge`,`GesamtBestellViewUnsorted`.`Woche` AS `Woche`,`GesamtBestellViewUnsorted`.`Anzahl` AS `Anzahl`,`GesamtBestellViewUnsorted`.`AnzahlModul` AS `AnzahlModul`,`GesamtBestellViewUnsorted`.`AnzahlZusatz` AS `AnzahlZusatz`,`GesamtBestellViewUnsorted`.`Kommentar` AS `Kommentar`,`GesamtBestellViewUnsorted`.`Urlaub` AS `Urlaub` from `GesamtBestellViewUnsorted` order by `GesamtBestellViewUnsorted`.`Produkt` ;

-- --------------------------------------------------------

--
-- Struktur des Views `GesamtBestellViewUnsorted`
--
DROP TABLE IF EXISTS `GesamtBestellViewUnsorted`;

CREATE ALGORITHM=UNDEFINED DEFINER=`d02dbcf8`@`localhost` SQL SECURITY DEFINER VIEW `GesamtBestellViewUnsorted`  AS  select `BenutzerBestellView`.`Produkt_ID` AS `Produkt_ID`,`BenutzerBestellView`.`Produkt` AS `Produkt`,`BenutzerBestellView`.`Beschreibung` AS `Beschreibung`,`BenutzerBestellView`.`Einheit` AS `Einheit`,`BenutzerBestellView`.`Menge` AS `Menge`,`BenutzerBestellView`.`Woche` AS `Woche`,group_concat((case when (trim(`BenutzerBestellView`.`Kommentar`) = '') then NULL else `BenutzerBestellView`.`Kommentar` end) separator ', ') AS `Kommentar`,sum(`BenutzerBestellView`.`Anzahl`) AS `Anzahl`,sum(`BenutzerBestellView`.`AnzahlModul`) AS `AnzahlModul`,sum(`BenutzerBestellView`.`AnzahlZusatz`) AS `AnzahlZusatz`,sum(`BenutzerBestellView`.`Urlaub`) AS `Urlaub` from `BenutzerBestellView` group by `BenutzerBestellView`.`Produkt_ID`,`BenutzerBestellView`.`Woche` ;

-- --------------------------------------------------------

--
-- Struktur des Views `ModulInhaltView`
--
DROP TABLE IF EXISTS `ModulInhaltView`;

CREATE ALGORITHM=UNDEFINED DEFINER=`d02dbcf8`@`localhost` SQL SECURITY DEFINER VIEW `ModulInhaltView`  AS  select `ModulInhalt`.`ID` AS `ID`,`ModulInhalt`.`Modul_ID` AS `Modul_ID`,`ModulInhalt`.`Produkt_ID` AS `Produkt_ID`,`ModulInhalt`.`Anzahl` AS `Anzahl`,`ModulInhalt`.`MindestAnzahl` AS `MindestAnzahl`,`ModulInhalt`.`MaximalAnzahl` AS `MaximalAnzahl`,`ModulInhalt`.`ErstellZeitpunkt` AS `ErstellZeitpunkt`,`ModulInhalt`.`AenderZeitpunkt` AS `AenderZeitpunkt`,`ModulInhalt`.`AenderBenutzer_ID` AS `AenderBenutzer_ID`,`ModulInhaltWoche`.`Woche` AS `Woche` from (`ModulInhalt` join `ModulInhaltWoche` on((`ModulInhaltWoche`.`ModulInhalt_ID` = `ModulInhalt`.`ID`))) ;

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
  ADD CONSTRAINT `BenutzerKorbAboBenutzer` FOREIGN KEY (`Benutzer_ID`) REFERENCES `Benutzer` (`ID`) ON UPDATE CASCADE,
  ADD CONSTRAINT `BenutzerKorbAboKorb` FOREIGN KEY (`Modul_ID`) REFERENCES `Modul` (`ID`);

--
-- Constraints der Tabelle `BenutzerUrlaub`
--
ALTER TABLE `BenutzerUrlaub`
  ADD CONSTRAINT `BenutzerUrlaub_Benutzer` FOREIGN KEY (`Benutzer_ID`) REFERENCES `Benutzer` (`ID`) ON UPDATE CASCADE;

--
-- Constraints der Tabelle `BenutzerZusatzBestellung`
--
ALTER TABLE `BenutzerZusatzBestellung`
  ADD CONSTRAINT `Bestellung_Benutzer` FOREIGN KEY (`Benutzer_ID`) REFERENCES `Benutzer` (`ID`) ON UPDATE CASCADE,
  ADD CONSTRAINT `Bestellung_Produkt` FOREIGN KEY (`Produkt_ID`) REFERENCES `Produkt` (`ID`);

--
-- Constraints der Tabelle `Depot`
--
ALTER TABLE `Depot`
  ADD CONSTRAINT `DepotStellvertreterBenutzer` FOREIGN KEY (`BestellerBenutzer_ID`) REFERENCES `Benutzer` (`ID`),
  ADD CONSTRAINT `DepotVerantwortlicherBenutzer` FOREIGN KEY (`VerwalterBenutzer_ID`) REFERENCES `Benutzer` (`ID`);

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
