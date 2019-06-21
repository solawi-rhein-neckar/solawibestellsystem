-- phpMyAdmin SQL Dump
-- version 4.8.5
-- https://www.phpmyadmin.net/
--
-- Host: localhost
-- Erstellungszeit: 21. Jun 2019 um 23:45
-- Server-Version: 5.7.26-nmm1-log
-- PHP-Version: 7.2.19-nmm1

SET SQL_MODE = "NO_AUTO_VALUE_ON_ZERO";
SET AUTOCOMMIT = 0;
START TRANSACTION;
SET time_zone = "+00:00";

--
-- Datenbank: `d02dbcf8`
--

DELIMITER $$
--
-- Prozeduren
--
CREATE DEFINER=`d02dbcf8`@`localhost` PROCEDURE `PivotBestellungen` (IN `pWoche` DECIMAL(6,2))  READS SQL DATA
    SQL SECURITY INVOKER
BEGIN

SET @query := (SELECT GROUP_CONCAT(DISTINCT CONCAT('MAX(IF(Produkt_ID = ', ID, ', Anzahl, 0)) AS `', IF(Nr < 10,'0', ''), Nr, '.', Name, '`' ))  FROM Produkt ORDER BY Nr);

SET @query = CONCAT('SELECT Depot_ID, ', @query, ' , MAX(Urlaub) as `',pWoche,' Urlauber` FROM DepotBestellView WHERE Woche = ', pWoche ,' GROUP BY Depot_ID');

PREPARE stt FROM @query;

EXECUTE stt;

DEALLOCATE PREPARE stt;

END$$

CREATE DEFINER=`d02dbcf8`@`localhost` PROCEDURE `PivotDepot` (IN `pWoche` DECIMAL(6,2), IN `pDepot` INT)  READS SQL DATA
    SQL SECURITY INVOKER
BEGIN

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
,`Produkt` varchar(511)
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
,`Produkt` varchar(511)
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
,`Produkt` varchar(511)
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
,`Produkt` varchar(511)
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
,`Produkt` varchar(511)
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
,`Produkt` varchar(511)
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
  `WechselWochen` varchar(255) COLLATE utf8_german2_ci NOT NULL,
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
  `Name` varchar(511) COLLATE utf8_german2_ci GENERATED ALWAYS AS (concat(`Produkt`,' [',`Menge`,' ',`Einheit`,']')) VIRTUAL,
  `Produkt` varchar(255) COLLATE utf8_german2_ci NOT NULL,
  `Beschreibung` varchar(2047) COLLATE utf8_german2_ci NOT NULL DEFAULT '',
  `Einheit` varchar(7) COLLATE utf8_german2_ci NOT NULL DEFAULT 'Stueck',
  `Menge` decimal(8,2) NOT NULL DEFAULT '1.00',
  `Punkte` int(11) NOT NULL DEFAULT '1',
  `Nr` int(11) NOT NULL DEFAULT '1',
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
  ADD KEY `BenutzerUrlaubAender_Benutzer` (`AenderBenutzer_ID`),
  ADD KEY `BenutzerUrlaub_Benutzer` (`Benutzer_ID`);

--
-- Indizes für die Tabelle `BenutzerZusatzBestellung`
--
ALTER TABLE `BenutzerZusatzBestellung`
  ADD PRIMARY KEY (`ID`),
  ADD KEY `Bestellung_Produkt` (`Produkt_ID`),
  ADD KEY `Bestellung_AenderBenutzer` (`AenderBenutzer_ID`),
  ADD KEY `Bestellung_Benutzer` (`Benutzer_ID`);

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
