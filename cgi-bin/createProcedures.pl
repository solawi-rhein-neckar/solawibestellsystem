#!/usr/bin/perl
use strict;
use warnings;

use CGI::Simple; # https://metacpan.org/pod/CGI::Simple  -  http header output and parsing
use CGI::Simple::Cookie;
use DBI;         # https://metacpan.org/pod/DBI          -  connect to sql database
use JSON;        # https://metacpan.org/pod/JSON         -  convert objects to json and vice versa
use Time::Local;
use POSIX qw(strftime);

use CGI::Carp qw(warningsToBrowser fatalsToBrowser); # use only while debugging!!: displays (non-syntax) errors and warning in html

my $q = CGI::Simple->new;

# get database handle
my $dbh = DBI->connect("DBI:mysql:database=db208674_361;host=mysql", "db208674_361", "",  { RaiseError => 1, AutoCommit => 0, mysql_enable_utf8mb4 => 1 });

if ( $q->request_method() =~ /^OPTIONS/ ) {
	print $q->header({"content-type" => "application/json", "access_control_allow_origin" => $q->referer() ? "http://solawi.fairtrademap.de" : "null", "Access-Control-Allow-Methods" => "POST, GET, OPTIONS, DELETE", "Access-Control-Allow-Headers" => "content-type,x-requested-with", "Access-Control-Allow-Credentials" => "true"});

} elsif ( $q->path_info =~  /^[a-zA-Z0-9\/._ -]*$/) {
	# print http header
	print $q->header({"content-type" => "application/json", "access_control_allow_origin" => $q->referer() ? "http://solawi.fairtrademap.de" : "null", "Access-Control-Allow-Credentials" => "true"});

	# check if logged in (sessionid cookie)
	my %cookies = CGI::Simple::Cookie->fetch;
	my $bc = $cookies{'sessionid'} ? $cookies{'sessionid'}->value : undef;
	my $stbc = $dbh->prepare("SELECT * FROM `Benutzer` WHERE `Cookie` = ?");
	$stbc->execute($bc);
	if ( my $user = $stbc->fetchrow_hashref ) { # is logged in: sessionid cookie verified

		if ( $q->request_method() =~ /^GET$/ ) {

			my $sth;

			if ( $q->path_info =~ /^\/RECREATEPROCEDURES$/ ) {
				$dbh->prepare("SET NAMES utf8mb4;")->execute();
				$dbh->prepare("DROP PROCEDURE IF EXISTS `BenutzerBestellung`")->execute();
				$dbh->prepare("
CREATE PROCEDURE `BenutzerBestellung` (
   IN `pWoche` DECIMAL(6,2),
   IN `pInhalt` BOOLEAN
)
READS SQL DATA
SQL SECURITY INVOKER
BEGIN
DROP TEMPORARY TABLE IF EXISTS BenutzerBestellungenTemp;
CREATE TEMPORARY TABLE IF NOT EXISTS BenutzerBestellungenTemp ENGINE=MEMORY CHARACTER SET utf8mb4
COLLATE utf8mb4_general_ci AS (
   SELECT
   `u`.`Benutzer_ID` AS `Benutzer_ID`,
   `Benutzer`.`Name` AS `Benutzer`,
   `Depot`.`ID` AS `Depot_ID`,
   `Depot`.`Name` AS `Depot`,
   `u`.Modul AS Modul,
   `Produkt`.`ID` as Produkt_ID,
   `Produkt`.`Produkt` as Produktname,
   `Produkt`.`Name` as Produkt,
   `Produkt`.`Beschreibung`,
   `Produkt`.`Einheit`,
   `Produkt`.`Menge`,
   `u`.`Woche` AS `Woche`,
   `u`.`Kommentar` AS `Kommentar`,
   ( CASE WHEN NOT ISNULL(`BenutzerUrlaub`.`ID`) THEN 0 WHEN pInhalt = TRUE THEN `u`.`Lieferzahl` ELSE `u`.`Anzahl` END ) AS `Anzahl`,
   CASE WHEN(`u`.`Quelle` = 1) THEN `u`.`Anzahl` ELSE 0 END AS `AnzahlModul`,
   CASE WHEN(`u`.`Quelle` = 2) THEN `u`.`Anzahl` ELSE 0 END AS `AnzahlZusatz`,
   case when (`u`.`BezahltesModul` = 0) then (`u`.`Lieferzahl` * `Produkt`.`Punkte`) else 0 end AS `Punkte`,
   `u`.`Gutschrift` * `Produkt`.`Punkte` AS Gutschrift,
   ( `BenutzerUrlaub`.`ID` IS NOT NULL ) AS `Urlaub`
   FROM (
           (SELECT
                 1 AS `Quelle`,
                 `Benutzer`.`ID` AS `Benutzer_ID`,
                 `BenutzerModulAbo`.`Kommentar` AS `Kommentar`,
                  Replace(Replace(`Modul`.`Name`, 'utermodul', 'uter'), 'Quarkmodul' , 'Quark') AS Modul,
                 ModulInhalt.Produkt_ID,
                 ( IFNULL(`BenutzerModulAbo`.`Anzahl`,0) ) AS `Anzahl`,
                 IFNULL(`BenutzerModulAbo`.`Anzahl`,0) * IF(ISNULL(ModulInhaltWoche.Anzahl) AND ISNULL(ModulInhaltDepot.Anzahl), NULL, IFNULL(ModulInhaltWoche.Anzahl,0) + IFNULL(ModulInhaltDepot.Anzahl, 0))  * ModulInhalt.Anzahl AS Lieferzahl,
                 IF(Modul.ID = 4 and ModulInhalt.HauptProdukt, IFNULL(`BenutzerModulAbo`.`BezahltesModul`,0) - IFNULL(`BenutzerModulAbo`.`Anzahl`,0), 0) +
                 	(IF(ISNULL(ModulInhaltWoche.Anzahl) AND ISNULL(ModulInhaltDepot.Anzahl), NULL, IFNULL(ModulInhaltWoche.Anzahl,0) + IFNULL(ModulInhaltDepot.Anzahl, 0))
                 	* ModulInhalt.Anzahl * IF(Modul.ID = 4, 0, Benutzer.Anteile)
             		* Modul.AnzahlProAnteil)
                 AS Gutschrift,
                 `BenutzerModulAbo`.BezahltesModul OR Modul.ID = 4 as BezahltesModul,
                 pWoche AS `Woche`
             FROM `Modul`
             JOIN Benutzer
             LEFT JOIN `BenutzerModulAbo`
                 ON `BenutzerModulAbo`.`Modul_ID` = `Modul`.`ID`
                 AND BenutzerModulAbo.Benutzer_ID = Benutzer.ID
                 AND ( ISNULL(`BenutzerModulAbo`.`StartWoche`) OR ( pWoche >= `BenutzerModulAbo`.`StartWoche` ) )
                 AND (  ISNULL(`BenutzerModulAbo`.`EndWoche`)  OR ( pWoche <= `BenutzerModulAbo`.`EndWoche` ) )
             LEFT JOIN ModulInhalt ON pInhalt = TRUE AND ModulInhalt.Modul_ID = Modul.ID
             LEFT JOIN ModulInhaltWoche
             	ON ModulInhaltWoche.Woche = pWoche
             	AND ModulInhaltWoche.ModulInhalt_ID = ModulInhalt.ID
             	AND (ModulInhaltWoche.Anzahl IS NOT NULL)
             	AND ( ISNULL(ModulInhaltWoche.Depot_ID) OR ModulInhaltWoche.Depot_ID = 0 )
             LEFT JOIN ModulInhaltWoche AS ModulInhaltDepot
             	ON ModulInhaltDepot.Woche = pWoche
             	AND ModulInhaltDepot.ModulInhalt_ID = ModulInhalt.ID
             	AND (ModulInhaltDepot.Anzahl IS NOT NULL)
             	AND ( ModulInhaltDepot.Depot_ID = Benutzer.Depot_ID )
             WHERE
                    (( `BenutzerModulAbo`.ID IS NOT NULL )
                 OR ( Modul.ID <> 4 AND ((Modul.AnzahlProAnteil * Benutzer.Anteile) > 0) )
                 OR ( Modul.ID = 2 /*Milch*/ AND Benutzer.Anteile > 0 ))
                 AND (ModulInhalt.ID is null or ModulInhalt.HauptProdukt or ModulInhaltWoche.Anzahl > 0 or ModulInhaltDepot.Anzahl > 0)
           )
           UNION ALL
           (SELECT
                 2 AS `Quelle`,
                 `BenutzerZusatzBestellung`.`Benutzer_ID` AS `Benutzer_ID`,
                 `BenutzerZusatzBestellung`.`Kommentar` AS `Kommentar`,
                 NULL as Modul,
                 `BenutzerZusatzBestellung`.`Produkt_ID`,
                 `BenutzerZusatzBestellung`.`Anzahl` AS `Anzahl`,
                 `BenutzerZusatzBestellung`.`Anzahl` AS `Lieferzahl`,
                 0 as Gutschrift,
                 0 as BezahltesModul,
                 `BenutzerZusatzBestellung`.`Woche` AS `Woche`
             FROM `BenutzerZusatzBestellung`
             WHERE `BenutzerZusatzBestellung`.`Woche` = pWoche
           )
        ) `u`
        JOIN `Benutzer` ON ( ( `u`.`Benutzer_ID` = `Benutzer`.`ID` ) )
        JOIN `Depot` ON ( ( `Benutzer`.`Depot_ID` = `Depot`.`ID` ) )
	    LEFT JOIN `BenutzerUrlaub`
	       	ON `BenutzerUrlaub`.`Benutzer_ID` = `u`.`Benutzer_ID`
            AND  `BenutzerUrlaub`.`Woche` = `u`.`Woche`
      	LEFT JOIN Produkt on u.Produkt_ID = Produkt.ID
      	WHERE Benutzer.Depot_ID <> 0
);
END")->execute();

$dbh->prepare("DROP PROCEDURE IF EXISTS `BenutzerBestellungView`")->execute();
$dbh->prepare("CREATE  PROCEDURE `BenutzerBestellungView` (
	IN `pWoche` DECIMAL(6,2),
	IN `pBenutzer` INT,
	IN `pDepot` INT
)
    READS SQL DATA
    SQL SECURITY INVOKER
BEGIN
CALL BenutzerBestellung(pWoche, TRUE);

SELECT

   `Benutzer_ID`,
   `Benutzer`,
   `Depot_ID`,
   `Depot`,
   MAX(Modul) AS Modul,
   `Produktname`,
   Produkt,
   Produkt_ID,
   `Beschreibung`,
   `Einheit`,
   `Menge`,
   `Woche`,
   CONVERT(GROUP_CONCAT( ( CASE WHEN(TRIM(`Kommentar`) = '') THEN NULL ELSE `Kommentar` END ) SEPARATOR ', ' ),char(255)) AS `Kommentar`,
  GREATEST(0, SUM(`Anzahl`)) AS Anzahl,
   SUM( AnzahlModul ) AS `AnzahlModul`,
   SUM( `AnzahlZusatz` ) AS `AnzahlZusatz`,
   GREATEST(0, sum(Punkte)) AS `Punkte`,
   MAX(IFNULL(Gutschrift,0)) as `Gutschrift`,
    `Urlaub`

FROM `BenutzerBestellungenTemp`

WHERE ((pBenutzer is null) or (Benutzer_ID = pBenutzer))
AND ((pDepot is null) or (Depot_ID = pDepot))

GROUP BY `Benutzer_ID`,
   `Benutzer`,
   `Depot_ID`,
   `Depot`,
   IFNuLL(Produkt,Modul),
   `Woche`,
   `Urlaub`
order by benutzer_ID, modul, produkt;
END")->execute();

$dbh->prepare("DROP PROCEDURE IF EXISTS `PivotDepotBestellung`")->execute();
$dbh->prepare("CREATE PROCEDURE `PivotDepotBestellung`(
	IN `pWoche` DECIMAL(6,2),
	IN `pDepot` INT
)
    READS SQL DATA
    SQL SECURITY INVOKER
BEGIN

SET SESSION group_concat_max_len = 32000;

SET \@query := (SELECT GROUP_CONCAT(DISTINCT CONCAT('SUM(IF(Produkt = \\'', Name, '\\', IF(AnzahlZusatz is not null, Anzahl + (AnzahlZusatz * 0.0001), Anzahl), 0)) AS `', IF(Nr < 10,'0', ''), Nr, '.', Name, '`' ))  FROM Produkt WHERE Nr <= 900 ORDER BY Nr);

SET \@query = CONCAT('
	SELECT Benutzer as `00.',
		   pWoche, ' ',
		   (SELECT Name FROM Depot WHERE ID = pDepot),'`,
		   SUM( IF(Produkt = \\'Milch, 0.5L\\', cast(IF(AnzahlZusatz is not null, Anzahl/2 + (AnzahlZusatz/2 * 0.0001), Anzahl/2) as decimal(10,5)), 0) ) AS `06.Milch`,',
		   \@query, ',
		   SUM(Urlaub) as `99.',pWoche, ' Urlaub`,
		   GROUP_CONCAT(`subq`.Kommentar SEPARATOR \\'; \\') as `96.Kommentar`
	FROM
		(Select `BenutzerBestellungenTemp`.`Benutzer` AS `Benutzer`,
		     `BenutzerBestellungenTemp`.`Benutzer_ID` AS `Benutzer_ID`,
		     `BenutzerBestellungenTemp`.`Depot_ID` AS `Depot_ID`,
		     `BenutzerBestellungenTemp`.`Depot` AS `Depot`,
		     IFNULL(BenutzerBestellungenTemp.Modul,`BenutzerBestellungenTemp`.`Produkt`) AS `Produkt`,
		     `BenutzerBestellungenTemp`.`Beschreibung` AS `Beschreibung`,
		     `BenutzerBestellungenTemp`.`Einheit` AS `Einheit`,
		     `BenutzerBestellungenTemp`.`Menge` AS `Menge`,
		     `BenutzerBestellungenTemp`.`Woche` AS `Woche`,
			 GREATEST(0, sum(`BenutzerBestellungenTemp`.`Anzahl`)) AS `Anzahl`,
		     sum(`BenutzerBestellungenTemp`.`AnzahlModul`) AS `AnzahlModul`,
		     sum(`BenutzerBestellungenTemp`.`AnzahlZusatz`) AS `AnzahlZusatz`,
		     sum(`BenutzerBestellungenTemp`.`Urlaub`) AS `Urlaub`,
		     GROUP_CONCAT( (
		        CASE WHEN(`BenutzerBestellungenTemp`.`Kommentar` is NULL
						or TRIM(`BenutzerBestellungenTemp`.`Kommentar`) = \\'\\'
						or TRIM(`BenutzerBestellungenTemp`.`Kommentar`) = \\'-\\'
					    or TRIM(`BenutzerBestellungenTemp`.`Kommentar`) like \\'Tausch\\') THEN NULL
				ELSE concat((select name from Benutzer where Benutzer.ID = BenutzerBestellungenTemp.Benutzer_ID),
		            		case when Produkt is null
									or TRIM(Produkt) = \\'\\'
									or TRIM(Produkt) = \\'-\\'
									or TRIM(Produkt) = \\'Kommentar\\'
							then \\'\\'
							else concat(\\' \\',Produkt) end, \\': \\', `BenutzerBestellungenTemp`.`Kommentar`)
		         END
		      ) SEPARATOR \\', \\' ) AS `Kommentar`
		From `BenutzerBestellungenTemp`
		Group By
		    IFNULL(BenutzerBestellungenTemp.Modul,`BenutzerBestellungenTemp`.`Produkt`),
		    `BenutzerBestellungenTemp`.`Woche`,
		    `BenutzerBestellungenTemp`.`Benutzer_ID`,
		    `BenutzerBestellungenTemp`.`Depot_ID`
		Order By
		    `BenutzerBestellungenTemp`.`Benutzer_ID`, `BenutzerBestellungenTemp`.`Depot`, IFNULL(BenutzerBestellungenTemp.Modul,`BenutzerBestellungenTemp`.`Produkt`)
	) subq
	WHERE Woche = ', pWoche ,'
	AND Depot_ID = ',pDepot,'
	GROUP BY Benutzer WITH ROLLUP
');

CALL BenutzerBestellung(pWoche, FALSE);

PREPARE stt FROM \@query;

EXECUTE stt;

DEALLOCATE PREPARE stt;

END")->execute();

$dbh->prepare("DROP PROCEDURE IF EXISTS `PivotExportBestellung`")->execute();
$dbh->prepare("CREATE PROCEDURE `PivotExportBestellung` (
	IN `pWoche` DECIMAL(6,2)
)
    READS SQL DATA
    SQL SECURITY INVOKER
BEGIN

SET SESSION group_concat_max_len = 32000;

SET \@query := (SELECT GROUP_CONCAT(DISTINCT CONCAT('SUM(IF(Produkt = \\'', Produkt, '\\', Anzahl, 0)) AS `', Produkt, '`' ))  FROM Produkt ORDER BY Nr);

SET \@query = CONCAT('
	SELECT Depot,
		   SUM( IF(Produkt = \\'Milch, 0.5L\\', Anzahl/2, 0) ) AS `Milch`,',
		   \@query, ' ,
		   SUM(IF(NOT (Produkt LIKE \\'Gem_se\\'),0, Urlaub)) as Urlauber,

		  MAX((SELECT Sum(Anteile) FROM Benutzer where Benutzer.Depot_ID = `subq`.`Depot_ID`)) as `Anteile`,

		  GROUP_CONCAT(`subq`.Kommentar SEPARATOR \\', \\') as `Kommentar`
	FROM
		(Select `BenutzerBestellungenTemp`.`Depot_ID` AS `Depot_ID`,
			 `BenutzerBestellungenTemp`.`Depot` AS `Depot`,
			 IFNULL(BenutzerBestellungenTemp.Modul,`BenutzerBestellungenTemp`.`Produktname`) AS `Produkt`,
			 `BenutzerBestellungenTemp`.`Beschreibung` AS `Beschreibung`,
			 `BenutzerBestellungenTemp`.`Einheit` AS `Einheit`,
			 `BenutzerBestellungenTemp`.`Menge` AS `Menge`,
			 `BenutzerBestellungenTemp`.`Woche` AS `Woche`,
			 GREATEST(0, sum(`BenutzerBestellungenTemp`.`Anzahl`)) AS `Anzahl`,
			 sum(`BenutzerBestellungenTemp`.`AnzahlModul`) AS `AnzahlModul`,
			 sum(`BenutzerBestellungenTemp`.`AnzahlZusatz`) AS `AnzahlZusatz`,
			 sum(`BenutzerBestellungenTemp`.`Urlaub`) AS `Urlaub`,
 			 GROUP_CONCAT( (
             	CASE WHEN(`BenutzerBestellungenTemp`.`Kommentar` is NULL
						or TRIM(`BenutzerBestellungenTemp`.`Kommentar`) = \\'\\'
                        or TRIM(`BenutzerBestellungenTemp`.`Kommentar`) = \\'-\\'
                        or TRIM(`BenutzerBestellungenTemp`.`Kommentar`) like \\'Tausch\\') THEN NULL
 				ELSE concat((select name from Benutzer where Benutzer.ID = BenutzerBestellungenTemp.Benutzer_ID),
			 				case when Produkt is null
								   or TRIM(Produkt) = \\'\\'
								   or TRIM(Produkt) = \\'-\\'
								   or TRIM(Produkt) = \\'Kommentar\\'
							then \\'\\'
							else concat(\\' \\', Produkt) end, \\': \\', `BenutzerBestellungenTemp`.`Kommentar`)
        		END
 			 ) SEPARATOR \\', \\') AS `Kommentar`
		From `BenutzerBestellungenTemp`
		Group By
			IFNULL(BenutzerBestellungenTemp.Modul,`BenutzerBestellungenTemp`.`Produktname`),
			`BenutzerBestellungenTemp`.`Woche`,
			`BenutzerBestellungenTemp`.`Depot_ID`,
			`BenutzerBestellungenTemp`.`Benutzer_ID`
		Order By
			`BenutzerBestellungenTemp`.`Depot`, `BenutzerBestellungenTemp`.`Produkt`
	) subq
	WHERE Woche = ', pWoche ,'
	GROUP BY Depot_ID'
);

CALL BenutzerBestellung(pWoche, FALSE);

PREPARE stt FROM \@query;

EXECUTE stt;

DEALLOCATE PREPARE stt;

END")->execute();
$dbh->prepare("DROP PROCEDURE IF EXISTS `PivotSolawiBestellung`")->execute();
$dbh->prepare("CREATE PROCEDURE `PivotSolawiBestellung`(
	IN `pWoche` DECIMAL(6,2)
)
    READS SQL DATA
    SQL SECURITY INVOKER
BEGIN

SET SESSION group_concat_max_len = 32000;

SET \@query := (SELECT GROUP_CONCAT(DISTINCT CONCAT('SUM(IF(Produkt = \\'', Name, '\\', Anzahl, 0)) AS `', IF(Nr < 10,'0', ''), Nr, '.', Name, '`' ))  FROM Produkt WHERE Nr <= 900 ORDER BY Nr);

SET \@query = CONCAT('
	SELECT Depot as `00.',pWoche,'`,
		   SUM( IF(Produkt = \\'Milch, 0.5L\\', cast(Anzahl/2 as decimal(5,1)), 0) ) AS `06.Milch`,',
		   \@query, ',
		   SUM(IF(NOT (Produkt LIKE \\'Gem_se\\'),0, Urlaub)) as `99.', pWoche,' Urlauber`,
		  SUM(IF((NOT (Produkt LIKE \\'Gem_se\\')) OR BenutzerId <> (SELECT Min(ID) FROM Benutzer Where Benutzer.Depot_ID = subq.Depot_ID),0, (SELECT Count(*) FROM Benutzer where Benutzer.Depot_ID = `subq`.`Depot_ID`))) as `97.Mitglieder`,
		  SUM(IF((NOT (Produkt LIKE \\'Gem_se\\')) OR BenutzerId <> (SELECT Min(ID) FROM Benutzer Where Benutzer.Depot_ID = subq.Depot_ID),0, (SELECT Sum(Anteile) FROM Benutzer where Benutzer.Depot_ID = `subq`.`Depot_ID`))) as `98.Anteile`,
		  GROUP_CONCAT(`subq`.Kommentar SEPARATOR \\', \\') as `96.Kommentar`
	FROM
		(Select `BenutzerBestellungenTemp`.`Depot_ID` AS `Depot_ID`,
			 `BenutzerBestellungenTemp`.`Depot` AS `Depot`,
			 IFNULL(BenutzerBestellungenTemp.Modul,`BenutzerBestellungenTemp`.`Produkt`) AS `Produkt`,
			 `BenutzerBestellungenTemp`.`Beschreibung` AS `Beschreibung`,
			 `BenutzerBestellungenTemp`.`Einheit` AS `Einheit`,
			 `BenutzerBestellungenTemp`.`Menge` AS `Menge`,
			 `BenutzerBestellungenTemp`.`Woche` AS `Woche`,
			 GREATEST(0, sum(`BenutzerBestellungenTemp`.`Anzahl`)) AS `Anzahl`,
			 sum(`BenutzerBestellungenTemp`.`AnzahlModul`) AS `AnzahlModul`,
			 sum(`BenutzerBestellungenTemp`.`AnzahlZusatz`) AS `AnzahlZusatz`,
			 sum(`BenutzerBestellungenTemp`.`Urlaub`) AS `Urlaub`,
			 BenutzerBestellungenTemp.Benutzer_ID as BenutzerId,
 			 GROUP_CONCAT( (
	         	CASE WHEN(`BenutzerBestellungenTemp`.`Kommentar` is NULL
						or TRIM(`BenutzerBestellungenTemp`.`Kommentar`) = \\'\\'
						or TRIM(`BenutzerBestellungenTemp`.`Kommentar`) = \\'-\\'
					    or TRIM(`BenutzerBestellungenTemp`.`Kommentar`) like \\'Tausch\\') THEN NULL
				ELSE concat((select name from Benutzer where Benutzer.ID = BenutzerBestellungenTemp.Benutzer_ID),
	            			case when Produkt is null
								   or TRIM(Produkt) = \\'\\'
								   or TRIM(Produkt) = \\'-\\'
								   or TRIM(Produkt) = \\'Kommentar\\'
							then \\'\\'
							else concat(\\' \\', Produkt) end, \\': \\', `BenutzerBestellungenTemp`.`Kommentar`)
	         	END
	      	 ) SEPARATOR \\', \\') AS `Kommentar`
	    From `BenutzerBestellungenTemp`
	    Group By
			IFNULL(BenutzerBestellungenTemp.Modul,`BenutzerBestellungenTemp`.`Produkt`),
	   		`BenutzerBestellungenTemp`.`Woche`,
	   		`BenutzerBestellungenTemp`.`Depot_ID`,
	   		BenutzerId
	    Order By
			`BenutzerBestellungenTemp`.`Depot`, IFNULL(BenutzerBestellungenTemp.Modul,`BenutzerBestellungenTemp`.`Produkt`)
	) subq
	WHERE Woche = ', pWoche ,'
	GROUP BY Depot WITH ROLLUP
');

CALL BenutzerBestellung(pWoche, FALSE);

PREPARE stt FROM \@query;

EXECUTE stt;

DEALLOCATE PREPARE stt;

END")->execute();

$dbh->prepare("DROP PROCEDURE IF EXISTS `PivotModulInhalt`;")->execute();
$dbh->prepare("CREATE PROCEDURE `PivotModulInhalt`(
	IN `pWoche` DECIMAL(6,2)
)
    READS SQL DATA
    SQL SECURITY INVOKER
BEGIN

SET SESSION group_concat_max_len = 32000;

SET \@query := (SELECT GROUP_CONCAT(DISTINCT CONCAT('(SELECT ModulInhaltWoche.Anzahl From ModulInhaltWoche WHERE ModulInhaltWoche.ModulInhalt_ID = ModulInhalt.ID AND ModulInhaltWoche.Depot_ID = ', sub.ID, ' AND ModulInhaltWoche.WOCHE = ', pWoche, ') AS `', sub.KurzName, '_ID_', sub.ID  , '`' ))  FROM (Select * From Depot Where ID <> 0 ORDER BY Name) as sub);

SET \@query = CONCAT('
	SELECT ModulInhalt.ID AS `_ID`, ', pWoche, ' AS `:Date`,
		   Modul.Name AS `:Modul`,
		   ModulInhalt.Anzahl AS `:P#`,
           Produkt.Name AS `:Produkt`,
		   (SELECT Anzahl From ModulInhaltWoche WHERE ModulInhaltWoche.ModulInhalt_ID = ModulInhalt.ID AND ((ModulInhaltWoche.Depot_ID IS NULL) OR ModulInhaltWoche.Depot_ID = 0) AND ModulInhaltWoche.WOCHE = ', pWoche, ') AS `ALLE_ID_0`, ',
		   \@query, '
	FROM
		ModulInhalt
		Join Modul on ModulInhalt.Modul_ID = Modul.ID
		join Produkt on ModulInhalt.Produkt_ID = Produkt.ID ORDER BY Modul.Name, Produkt.Nr');

PREPARE stt FROM \@query;

EXECUTE stt;

DEALLOCATE PREPARE stt;

END")->execute();

$dbh->prepare("DROP PROCEDURE IF EXISTS `BenutzerPunkteBerechnung`;")->execute();
$dbh->prepare("CREATE PROCEDURE `BenutzerPunkteBerechnung` (
   IN `pBenutzer` int,
   IN `pYear` int,
   OUT `pWoche` decimal(6,2)
)
READS SQL DATA
SQL SECURITY INVOKER
BEGIN
  DECLARE day DATETIME DEFAULT DATE_ADD(MAKEDATE(pYear - IF(month(curdate()) < 11 or (day(curdate()) < 7 and month(curdate()) < 12), 1, 0) , 7), INTERVAL 10 MONTH);

  DROP TEMPORARY TABLE IF EXISTS BenutzerPunkteTemp;
  DROP TEMPORARY TABLE IF EXISTS BenutzerPunkteTemp2;

  CREATE TEMPORARY TABLE BenutzerPunkteTemp(
   Woche decimal(6,2),
   Benutzer_ID int,
   Benutzer varchar(255),
   Abzug int,
   Gutschrift int,
   Subtotal int,
   Total int);

  CREATE TEMPORARY TABLE BenutzerPunkteTemp2(
   Woche decimal(6,2),
   Benutzer_ID int,
   Benutzer varchar(255),
   Abzug int,
   Gutschrift int,
   Subtotal int,
   Total int);

  WHILE day <= (curdate() + interval 4 day) DO
  	SET pWoche = cast(yearweek((day - interval 4 day),1)/100 as decimal(6,2));
  	CALL BenutzerBestellung( pWoche, TRUE);
  	INSERT INTO BenutzerPunkteTemp SELECT pWoche,
  	   b.Benutzer_ID,
  	   b.Benutzer,
       GREATEST(0, sum(b.Punkte)),
       sum(IFNULL(b.Gutschrift,0)),
       sum(IFNULL(b.Gutschrift,0)) - GREATEST(0, sum(b.Punkte)),
       IF(pWoche < Benutzer.AnteileStartWoche AND pWoche >= Benutzer.AnteileStartWoche - \'0.01\', 0, sum(IFNULL(b.Gutschrift,0)) - GREATEST(0, sum(b.Punkte)))
       + IF(pWoche <= Benutzer.AnteileStartWoche AND pWoche >= Benutzer.AnteileStartWoche - \'0.01\', Benutzer.PunkteStart,
            IFNULL((Select t.Total FROM BenutzerPunkteTemp2 as t Where t.Benutzer_ID = b.Benutzer_ID),0)  )
     FROM (SELECT Benutzer_ID, Benutzer, GREATEST(0, sum(Punkte)) as Punkte, max(IFNULL(Gutschrift,0)) as Gutschrift FROM `BenutzerBestellungenTemp` GROUP BY `Benutzer_ID`,`Benutzer`,IFNuLL(Produkt,Modul)) as b
     JOIN Benutzer ON Benutzer.ID = Benutzer_ID
     WHERE `pBenutzer` IS NULL OR `pBenutzer` = b.Benutzer_ID
     Group by b.Benutzer_ID;

	TRUNCATE BenutzerPunkteTemp2;
	INSERT INTO BenutzerPunkteTemp2 SELECT * FROM BenutzerPunkteTemp WHERE Woche = pWoche;
    SET day = date_add(day, interval 7 day);

  END WHILE;
END;")->execute();

$dbh->prepare("DROP PROCEDURE IF EXISTS `BenutzerPunkteView`;")->execute();
$dbh->prepare("CREATE PROCEDURE `BenutzerPunkteView` (
   IN `pBenutzer` int,
   IN `pYear` int
)
READS SQL DATA
SQL SECURITY INVOKER
BEGIN
  DECLARE pWoche decimal(6,2);

  CALL BenutzerPunkteBerechnung(pBenutzer, pYear, pWoche);

  SELECT * FROM BenutzerPunkteTemp;
END;")->execute();

$dbh->prepare("DROP PROCEDURE IF EXISTS `BenutzerPunkte`;")->execute();
$dbh->prepare("CREATE PROCEDURE `BenutzerPunkte` (
   IN `pBenutzer` int
)
MODIFIES SQL DATA
SQL SECURITY INVOKER
BEGIN
  DECLARE pWoche decimal(6,2);

  CALL BenutzerPunkteBerechnung(pBenutzer, year(curdate()), pWoche);

  UPDATE Benutzer SET PunkteStand = (Select Total FROM BenutzerPunkteTemp Where Woche = pWoche And BenutzerPunkteTemp.Benutzer_ID = Benutzer.ID),
                      PunkteWoche = pWoche
          WHERE (Select Total FROM BenutzerPunkteTemp2 Where Woche = pWoche And BenutzerPunkteTemp2.Benutzer_ID = Benutzer.ID) IS NOT NULL;

  SELECT * FROM BenutzerPunkteTemp;
END;")->execute();
			}

		} else {
			print encode_json({result => 0, reason => "supported request methods: GET, POST, DELETE."});
		}

	} else {
		print encode_json({result => 0, reason => "not authenticated, please login."});
	}

} else {
	print $q->header({"content-type" => "application/json", "access_control_allow_origin" => $q->referer() ? "http://solawi.fairtrademap.de" : "null", "Access-Control-Allow-Credentials" => "true"});
	print encode_json({result v 0, reason => "path contains forbidden characters"});
}


# close database handle
$dbh->disconnect



