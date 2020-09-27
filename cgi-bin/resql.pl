#!/usr/bin/perl
use strict;
use warnings;

#
# This is a minimal bridge between a javascript REST Client and a MySQL Database
#
# https://github.com/solawi-rhein-neckar/solawibestellsystem/wiki/REST-API-Dokumentation
#
# Features:
#
# Login: Expects table with name "Benutzer" and columns "ID", "Name", "Passwort", "Cookie" and Role_ID
# -- POST resql.pl/login
#   body {name: 'Admin', password: 'Qwerty123'}  # sic! table-column german, json english, because Table-Column-Names will be visible in Frontend, json will not
#
# --> will set a random sessionid cookie and write its value into Benutzer.Cookie column
#
# Basic access control:
#
# Users with Benutzer.Role_ID == 1 can read all Tables that have NOT 'Benutzer' in their name, Users with Role_ID != 1 can read all Tables.
# Users with Benutzer.Role_ID <= 1 can read and update/insert rows of tables with 'Benutzer' in their name, if and only
# IF the row has a column 'Benutzer_ID' with value of the logged in users Benutzer.ID
# (further restrictions apply, i.e. only editing if "Woche" is in Future)
#
# Users with Benutzer.Role_ID == 3 can update/insert/delete all rows in all Tables, that have 'Benutzer' in their name (= Depotverwalter etc)
# Users with Benutzer.Role_ID == 1 can update all other Tables (Produkte, Deliveries etc = Packteam)
#
# Users with Benutzer.Role_ID == 2 can do everything (=Admin).
#
#
# - Query with
# -- GET resql.pl/TableName
# -- GET resql.pl/TableName/$id  # expects column with name ID
# -- GET resql.pl/TableName/ColumnName/$COLUMN_VALUE  # characters allowed for value: a-zA-Z0-9._-
# -- GET resql.pl/TableName/MY  # translated to WHERE Benutzer_ID = $loggedInUsersId
#
# - Update with
# -- POST resql.pl/TableName/$id # expects column with name ID
#  body  {col1: value1, col2: value2, ...}
#
# - Insert with
# -- POST resql.pl/TableName
#  body  {col1: value1, col2: value2, ...}
#

use CGI::Simple; # https://metacpan.org/pod/CGI::Simple  -  http header output and parsing
use CGI::Simple::Cookie;
use DBI;         # https://metacpan.org/pod/DBI          -  connect to sql database
use JSON;        # https://metacpan.org/pod/JSON         -  convert objects to json and vice versa
use Time::Local;
use POSIX qw(strftime);

use CGI::Carp qw(warningsToBrowser fatalsToBrowser); # use only while debugging!!: displays (non-syntax) errors and warning in html


my $q = CGI::Simple->new;

# get database handle
my $dbh = DBI->connect("DBI:mysql:database=db208674_361;host=127.0.0.3", "db208674_361", "",  { RaiseError => 1, AutoCommit => 0, mysql_enable_utf8 => ($q->request_method() =~ /^POST$/) });

if ( $q->request_method() =~ /^OPTIONS/ ) {
	print $q->header({"content-type" => "application/json", "access_control_allow_origin" => $q->referer() ? "http://solawi.fairtrademap.de" : "null", "Access-Control-Allow-Methods" => "POST, GET, OPTIONS, DELETE", "Access-Control-Allow-Headers" => "content-type,x-requested-with", "Access-Control-Allow-Credentials" => "true"});
}


# user wants to login?
if ( $q->request_method() =~ /^POST$/ && $q->path_info =~ /^\/login\/?/ ) {

	my $sessionid = rand();
	my $body = decode_json($q->param( 'POSTDATA' ));
	my $stl = $dbh->prepare("UPDATE `Benutzer` SET `Cookie` = ? WHERE `Name` = ? and `Passwort` = ?");
	$stl->execute($sessionid, $body->{name}, $body->{password});
	my $cookie = CGI::Simple::Cookie->new( -name=>'sessionid', -value=>$sessionid );

	# print http header with cookies
	print $q->header( {cookie => [$cookie], "content-type" => "application/json", "access_control_allow_origin" => $q->referer() ? "http://solawi.fairtrademap.de" : "null", "Access-Control-Allow-Credentials" => "true"} );
	print encode_json({result => $stl->rows()});
	$dbh->commit();

} elsif ( $q->path_info =~  /^[a-zA-Z0-9\/._ -]*$/) {
	# print http header
	print $q->header({"content-type" => "application/json", "access_control_allow_origin" => $q->referer() ? "http://solawi.fairtrademap.de" : "null", "Access-Control-Allow-Credentials" => "true"});

	# user does not want to login -> check if logged in (sessionid cookie)
	my %cookies = CGI::Simple::Cookie->fetch;
	my $bc = $cookies{'sessionid'} ? $cookies{'sessionid'}->value : undef;
	my $stbc = $dbh->prepare("SELECT * FROM `Benutzer` WHERE `Cookie` = ?");
	$stbc->execute($bc);
	if ( my $user = $stbc->fetchrow_hashref ) { # is logged in: sessionid cookie verified

		if ( $q->request_method() =~ /^GET$/ ) {

			my $sth;

			if ( $q->path_info =~ /^\/RECREATEPROCEDURES$/ ) {

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
CREATE TEMPORARY TABLE IF NOT EXISTS BenutzerBestellungenTemp ENGINE=MEMORY AS (
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
                  Replace(Replace(`Modul`.`Name`, 'Kräutermodul', 'Kräuter'), 'Quarkmodul' , 'Quark') AS Modul,
                 ModulInhalt.Produkt_ID,
                 ( IFNULL(`BenutzerModulAbo`.`Anzahl`,0) ) AS `Anzahl`,
                 IFNULL(`BenutzerModulAbo`.`Anzahl`,0) * IF(ISNULL(ModulInhaltWoche.Anzahl) AND ISNULL(ModulInhaltDepot.Anzahl), NULL, IFNULL(ModulInhaltWoche.Anzahl,0) + IFNULL(ModulInhaltDepot.Anzahl, 0))  * ModulInhalt.Anzahl AS Lieferzahl,
                 IF(ISNULL(ModulInhaltWoche.Anzahl) AND ISNULL(ModulInhaltDepot.Anzahl), NULL, IFNULL(ModulInhaltWoche.Anzahl,0) + IFNULL(ModulInhaltDepot.Anzahl, 0))  * ModulInhalt.Anzahl * IF(Modul.ID = 4,Benutzer.FleischAnteile,Benutzer.Anteile) * IF(Modul.ID = 2,3,Modul.AnzahlProAnteil) AS Gutschrift,
                 `BenutzerModulAbo`.BezahltesModul,
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
             	AND ( ISNULL(ModulInhaltWoche.Depot_ID) OR ModulInhaltWoche.Depot_ID = 0  )
             LEFT JOIN ModulInhaltWoche AS ModulInhaltDepot
             	ON ModulInhaltDepot.Woche = pWoche
             	AND ModulInhaltDepot.ModulInhalt_ID = ModulInhalt.ID
             	AND (ModulInhaltDepot.Anzahl IS NOT NULL)
             	AND ( ModulInhaltDepot.Depot_ID = Benutzer.Depot_ID )
             WHERE
                    (( `BenutzerModulAbo`.ID IS NOT NULL )
                 OR ( Modul.ID <> 4 AND ((Modul.AnzahlProAnteil * Benutzer.Anteile) > 0) )
                 OR ( Modul.ID = 4 /*Fleisch*/ AND Benutzer.FleischAnteile > 0 )
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
   sum(IFNULL(Gutschrift,0)) as `Gutschrift`,
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
		   SUM(IF(Produkt <> \\'Gemüse\\',0, Urlaub)) as Urlauber,

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
		   SUM(IF(Produkt <> \\'Gemüse\\',0, Urlaub)) as `99.', pWoche,' Urlauber`,
		  SUM(IF(Produkt <> \\'Gemüse\\' OR BenutzerId <> (SELECT Min(ID) FROM Benutzer Where Benutzer.Depot_ID = subq.Depot_ID),0, (SELECT Count(*) FROM Benutzer where Benutzer.Depot_ID = `subq`.`Depot_ID`))) as `97.Mitglieder`,
		  SUM(IF(Produkt <> \\'Gemüse\\' OR BenutzerId <> (SELECT Min(ID) FROM Benutzer Where Benutzer.Depot_ID = subq.Depot_ID),0, (SELECT Sum(Anteile) FROM Benutzer where Benutzer.Depot_ID = `subq`.`Depot_ID`))) as `98.Anteile`,
		  SUM(IF(Produkt <> \\'Gemüse\\' OR BenutzerId <> (SELECT Min(ID) FROM Benutzer Where Benutzer.Depot_ID = subq.Depot_ID),0, (SELECT Sum(FleischAnteile) FROM Benutzer where Benutzer.Depot_ID = `subq`.`Depot_ID`))) as `98.FleischAnteileErlaubt`,
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

			} elsif ( $q->path_info =~ /^\/([a-zA-Z]+)\/?(MY|OWN)?$/ ) {
				# regex matching with perl: will put capture group in implicit variables $1, $2, ...
				my $table = $1;
				my $myOwn = $2;

				if ( ($myOwn || $user->{Role_ID} <= 1) && $table =~ /^Benutzer(View)?$/ ) {
					$sth = $dbh->prepare("SELECT * FROM `$table` WHERE `ID` = ?");
					$sth->execute($user->{ID});
				} elsif ( ($myOwn || $user->{Role_ID} <= 1) && $table =~ /.*Benutzer.*/ ) {
					$sth = $dbh->prepare("SELECT * FROM `$table` WHERE `Benutzer_ID` = ?");
					$sth->execute($user->{ID});
				} elsif ( ($user->{Role_ID} == 3) && $table =~ /^Benutzer(View)?$/ ) {
					$sth = $dbh->prepare("SELECT * FROM `$table` WHERE `ID` in ( SELECT ID FROM Benutzer WHERE Depot_ID = ?)");
					$sth->execute($user->{Depot_ID});
				} elsif ( ($user->{Role_ID} == 3) && $table =~ /.*Benutzer.*/ ) {
					$sth = $dbh->prepare("SELECT * FROM `$table` WHERE `Benutzer_ID` in ( SELECT ID FROM Benutzer WHERE Depot_ID = ?)");
					$sth->execute($user->{Depot_ID});
				} else {
					$sth = $dbh->prepare("SELECT * FROM `$table`");
					$sth->execute();
				}

			} elsif ( $q->path_info =~ /^\/([a-zA-Z]+)\/([a-zA-Z0-9_.-]+)$/ ) {
				my $table = $1;
				my $id = $2;

				if ( $user->{Role_ID} <= 1 && $table =~ /^Benutzer(View)?$/ ) {
					$sth = $dbh->prepare("SELECT * FROM `$table` WHERE `ID` = ? AND `ID` = ?");
					$sth->execute($id, $user->{ID});
				} elsif ( $table =~ /^BenutzerBestellungView$/ ) {
					$sth = $dbh->prepare("CALL $table(?,?,?)");
					$sth->execute($id,$user->{ID},undef);
				} elsif ( $user->{Role_ID} <= 1 && $table =~ /.*Benutzer.*/ ) {
					$sth = $dbh->prepare("SELECT * FROM `$table` WHERE `ID` = ? AND `Benutzer_ID` = ?");
					$sth->execute($id, $user->{ID});
				} elsif ( $table =~ /^PivotDepot.*/ ) {
					$sth = $dbh->prepare("CALL $table(?,?)");
					$sth->execute($id,$user->{Depot_ID});
				} elsif ( $table =~ /^Pivot.*/ ) {
					$sth = $dbh->prepare("CALL $table(?)");
					$sth->execute($id);
				} else {
					$sth = $dbh->prepare("SELECT * FROM `$table` WHERE `ID` = ?");
					$sth->execute($id);
				}

			} elsif ( $q->path_info =~ /^\/([a-zA-Z]+)\/([a-zA-Z0-9_]+)\/([a-zA-Z0-9_.-]+)$/ ) {
				my $table = $1;
				my $column = $2;
				my $id = $3;

				if ( $user->{Role_ID} <= 1 && $table =~ /^Benutzer(View)?$/ ) {
					$sth = $dbh->prepare("SELECT * FROM `$table` WHERE `$column` = ? AND `ID` = ?");
					$sth->execute($id, $user->{ID});
				} elsif ( $user->{Role_ID} <= 1 && $table =~ /^BenutzerModulAbo$/ && $column =~ /^Woche$/ ) {
					$sth = $dbh->prepare("SELECT * FROM `$table` WHERE `StartWoche` <= ? AND `EndWoche` >= ? AND `Benutzer_ID` = ?");
					$sth->execute($id, $id, $user->{ID});
				} elsif ( $user->{Role_ID} <= 1 && $table =~ /^BenutzerModulAbo$/ && $column =~ /^Bis$/ ) {
					$sth = $dbh->prepare("SELECT * FROM `$table` WHERE `EndWoche` >= ? AND `Benutzer_ID` = ?");
					$sth->execute($id, $user->{ID});
				} elsif ( $user->{Role_ID} <= 1 && $table =~ /.*Benutzer.*/ ) {
					$sth = $dbh->prepare("SELECT * FROM `$table` WHERE `$column` = ? AND `Benutzer_ID` = ?");
					$sth->execute($id, $user->{ID});
				} elsif ( ($user->{Role_ID} == 3) && $table =~ /^Benutzer(View)?$/ ) {
					$sth = $dbh->prepare("SELECT * FROM `$table` WHERE `$column` = ? AND `ID` in ( SELECT ID FROM Benutzer WHERE Depot_ID = ?)");
					$sth->execute($id, $user->{Depot_ID});
				} elsif ( $user->{Role_ID} == 3 && $table =~ /^BenutzerModulAbo$/ && $column =~ /^Woche$/ ) {
					$sth = $dbh->prepare("SELECT * FROM `$table` WHERE `StartWoche` <= ? AND `EndWoche` >= ? AND `Benutzer_ID` in ( SELECT ID FROM Benutzer WHERE Depot_ID = ?)");
					$sth->execute($id, $id, $user->{Depot_ID});
				} elsif ( $user->{Role_ID} == 3 && $table =~ /^BenutzerModulAbo$/ && $column =~ /^Bis$/ ) {
					$sth = $dbh->prepare("SELECT * FROM `$table` WHERE `EndWoche` >= ? AND `Benutzer_ID` in ( SELECT ID FROM Benutzer WHERE Depot_ID = ?)");
					$sth->execute($id, $user->{Depot_ID});
				} elsif ( ($user->{Role_ID} == 3) && $table =~ /^BenutzerBestellungView$/ && $column =~ /^Woche$/) {
					$sth = $dbh->prepare("CALL $table(?,?,?)");
					$sth->execute($id,undef,$user->{Depot_ID});
				} elsif ( ($user->{Role_ID} == 3) && $table =~ /.*Benutzer.*/ ) {
					$sth = $dbh->prepare("SELECT * FROM `$table` WHERE `$column` = ? AND `Benutzer_ID` in ( SELECT ID FROM Benutzer WHERE Depot_ID = ?)");
					$sth->execute($id, $user->{Depot_ID});
				} elsif ( $table =~ /^BenutzerBestellungView$/ && $column =~ /^Woche$/) {
					$sth = $dbh->prepare("CALL $table(?,?,?)");
					$sth->execute($id,undef,undef);
				} elsif ( $table =~ /^BenutzerModulAbo$/ && $column =~ /^Woche$/ ) {
					$sth = $dbh->prepare("SELECT * FROM `$table` WHERE `StartWoche` <= ? AND `EndWoche` >= ?");
					$sth->execute($id, $id);
				} elsif ( $table =~ /^BenutzerModulAbo$/ && $column =~ /^Bis$/ ) {
					$sth = $dbh->prepare("SELECT * FROM `$table` WHERE `EndWoche` >= ?");
					$sth->execute($id);
				} else {
					$sth = $dbh->prepare("SELECT * FROM `$table` WHERE `$column` = ?");
					$sth->execute($id);
				}

			} elsif ( $q->path_info =~ /^\/([a-zA-Z]+)\/([a-zA-Z0-9_]+)\/([a-zA-Z0-9_.-]+)\/([a-zA-Z0-9_]+)\/([a-zA-Z0-9_.-]+)$/ ) {
				my $table = $1;
				my $column = $2;
				my $id = $column == 'Benutzer_ID' && $3 == 'MY' ? $user->{ID} : $3;
				my $column2 = $4;
				my $id2 = $5;

				if ( $user->{Role_ID} <= 1 && $table =~ /^Benutzer(View)?$/ ) {
					$sth = $dbh->prepare("SELECT * FROM `$table` WHERE `$column` = ? AND `$column2` = ? AND `ID` = ?");
					$sth->execute($id, $id2, $user->{ID});
				} elsif ( $user->{Role_ID} <= 1 && $table =~ /^BenutzerBestellungView$/ && $column2 == 'Woche' && $column == 'Benutzer_ID') {
					$sth = $dbh->prepare("CALL $table(?,?,?)");
					$sth->execute($id2,$user->{ID},undef);
				} elsif ( $user->{Role_ID} <= 1 && $table =~ /^BenutzerModulAbo$/ && $column2 =~ /^Woche$/ ) {
					$sth = $dbh->prepare("SELECT * FROM `$table` WHERE `$column` = ? AND `StartWoche` <= ? AND `EndWoche` >= ? AND `Benutzer_ID` = ?");
					$sth->execute($id, $id2, $id2, $user->{ID});
				} elsif ( $user->{Role_ID} <= 1 && $table =~ /^BenutzerModulAbo$/ && $column2 =~ /^Bis$/ ) {
					$sth = $dbh->prepare("SELECT * FROM `$table` WHERE `$column` = ? AND `EndWoche` >= ? AND `Benutzer_ID` = ?");
					$sth->execute($id, $id2, $user->{ID});
				} elsif ( $user->{Role_ID} <= 1 && $table =~ /.*Benutzer.*/ ) {
					$sth = $dbh->prepare("SELECT * FROM `$table` WHERE `$column` = ? AND `$column2` = ? AND `Benutzer_ID` = ?");
					$sth->execute($id, $id2, $user->{ID});
				} elsif ( ($user->{Role_ID} == 3) && $table =~ /^Benutzer(View)?$/ ) {
					$sth = $dbh->prepare("SELECT * FROM `$table` WHERE `$column` = ? AND `$column2` = ? AND `ID` in ( SELECT ID FROM Benutzer WHERE Depot_ID = ?)");
					$sth->execute($id, $id2, $user->{Depot_ID});
				} elsif ( $user->{Role_ID} >= 2 && $table =~ /^BenutzerBestellungView$/ && $column2 == 'Woche' && $column == 'Benutzer_ID') {
					$sth = $dbh->prepare("CALL $table(?,?,?)");
					$sth->execute($id2,$id,undef);
				} elsif ( $user->{Role_ID} >= 2 && $table =~ /^BenutzerBestellungView$/ && $column2 == 'Woche' && $column == 'Depot_ID') {
					$sth = $dbh->prepare("CALL $table(?,?,?)");
					$sth->execute($id2,undef,$id);
				} elsif ( $user->{Role_ID} == 3 && $table =~ /^BenutzerModulAbo$/ && $column2 =~ /^Woche$/ ) {
					$sth = $dbh->prepare("SELECT * FROM `$table` WHERE `$column` = ? AND `StartWoche` <= ? AND `EndWoche` >= ? AND `Benutzer_ID` in ( SELECT ID FROM Benutzer WHERE Depot_ID = ?)");
					$sth->execute($id, $id2, $id2, $user->{Depot_ID});
				} elsif ( $user->{Role_ID} == 3 && $table =~ /^BenutzerModulAbo$/ && $column2 =~ /^Bis$/ ) {
					$sth = $dbh->prepare("SELECT * FROM `$table` WHERE `$column` = ? AND `EndWoche` >= ? AND `Benutzer_ID` in ( SELECT ID FROM Benutzer WHERE Depot_ID = ?)");
					$sth->execute($id, $id2, $user->{Depot_ID});
				} elsif ( ($user->{Role_ID} == 3) && $table =~ /.*Benutzer.*/ ) {
					$sth = $dbh->prepare("SELECT * FROM `$table` WHERE `$column` = ? AND `$column2` = ? AND `Benutzer_ID` in ( SELECT ID FROM Benutzer WHERE Depot_ID = ?)");
					$sth->execute($id, $id2, $user->{Depot_ID});
				} elsif ( $table =~ /^BenutzerModulAbo$/ && $column2 =~ /^Woche$/ ) {
					$sth = $dbh->prepare("SELECT * FROM `$table` WHERE `$column` = ? AND `StartWoche` <= ? AND `EndWoche` >= ?");
					$sth->execute($id, $id2, $id2);
				} elsif ( $table =~ /^BenutzerModulAbo$/ && $column2 =~ /^Bis$/ ) {
					$sth = $dbh->prepare("SELECT * FROM `$table` WHERE `$column` = ? AND `EndWoche` >= ?");
					$sth->execute($id, $id2);
				} elsif ( $user->{Role_ID} > 1 && $table =~ /^PivotDepot.*/ ) {
					$sth = $dbh->prepare("CALL $table(?,?)");
					$sth->execute($id,$id2);
				} else {
					$sth = $dbh->prepare("SELECT * FROM `$table` WHERE `$column` = ? AND `$column2` = ?");
					$sth->execute($id, $id2);
				}
			} elsif ( $q->path_info =~ /^\/([a-zA-Z]+)\/([a-zA-Z0-9_]+)\/([a-zA-Z0-9_.-]+)\/([a-zA-Z0-9_]+)\/([a-zA-Z0-9_.-]+)\/([a-zA-Z0-9_]+)\/([a-zA-Z0-9_.-]+)$/ ) {
				my $table = $1;
				my $column = $2;
				my $id = $column == 'Benutzer_ID' && $3 == 'MY' ? $user->{ID} : $3;
				my $column2 = $4;
				my $id2 = $5;
				my $column3 = $6;
				my $id3 = $7;

				if ( $user->{Role_ID} <= 1 && $table =~ /^Benutzer(View)?$/ ) {
					$sth = $dbh->prepare("SELECT * FROM `$table` WHERE `$column` = ? AND `$column2` = ? AND `$column3` = ? AND `ID` = ?");
					$sth->execute($id, $id2, $id3, $user->{ID});
				} elsif ( $user->{Role_ID} <= 1 && $table =~ /^BenutzerModulAbo$/ && $column2 =~ /^Woche$/ ) {
					$sth = $dbh->prepare("SELECT * FROM `$table` WHERE `$column` = ? AND `StartWoche` <= ? AND `EndWoche` >= ? AND `$column3` = ? AND `Benutzer_ID` = ?");
					$sth->execute($id, $id2, $id2, $id3, $user->{ID});
				} elsif ( $user->{Role_ID} <= 1 && $table =~ /^BenutzerModulAbo$/ && $column2 =~ /^Bis$/ ) {
					$sth = $dbh->prepare("SELECT * FROM `$table` WHERE `$column` = ? AND `EndWoche` >= ? AND `$column3` = ? AND `Benutzer_ID` = ?");
					$sth->execute($id, $id2, $id3, $user->{ID});
				} elsif ( $user->{Role_ID} <= 1 && $table =~ /.*Benutzer.*/ ) {
					$sth = $dbh->prepare("SELECT * FROM `$table` WHERE `$column` = ? AND `$column2` = ? AND `$column3` = ? AND `Benutzer_ID` = ?");
					$sth->execute($id, $id2, $id3, $user->{ID});
				} elsif ( ($user->{Role_ID} == 3) && $table =~ /^Benutzer(View)?$/ ) {
					$sth = $dbh->prepare("SELECT * FROM `$table` WHERE `$column` = ? AND `$column2` = ? AND `$column3` = ? AND `ID` in ( SELECT ID FROM Benutzer WHERE Depot_ID = ?)");
					$sth->execute($id, $id2, $id3, $user->{Depot_ID});
				} elsif ( $user->{Role_ID} == 3 && $table =~ /^BenutzerModulAbo$/ && $column2 =~ /^Woche$/ ) {
					$sth = $dbh->prepare("SELECT * FROM `$table` WHERE `$column` = ? AND `StartWoche` <= ? AND `EndWoche` >= ? AND `$column3` = ? AND `Benutzer_ID` in ( SELECT ID FROM Benutzer WHERE Depot_ID = ?)");
					$sth->execute($id, $id2, $id2, $id3, $user->{Depot_ID});
				} elsif ( $user->{Role_ID} == 3 && $table =~ /^BenutzerModulAbo$/ && $column2 =~ /^Bis$/ ) {
					$sth = $dbh->prepare("SELECT * FROM `$table` WHERE `$column` = ? AND `EndWoche` >= ? AND `$column3` = ? AND `Benutzer_ID` in ( SELECT ID FROM Benutzer WHERE Depot_ID = ?)");
					$sth->execute($id, $id2, $id3, $user->{Depot_ID});
				} elsif ( ($user->{Role_ID} == 3) && $table =~ /.*Benutzer.*/ ) {
					$sth = $dbh->prepare("SELECT * FROM `$table` WHERE `$column` = ? AND `$column2` = ? AND `$column3` = ? AND `Benutzer_ID` in ( SELECT ID FROM Benutzer WHERE Depot_ID = ?)");
					$sth->execute($id, $id2, $id3, $user->{Depot_ID});
				} elsif ( $table =~ /^BenutzerModulAbo$/ && $column2 =~ /^Woche$/ ) {
					$sth = $dbh->prepare("SELECT * FROM `$table` WHERE `$column` = ? AND `StartWoche` <= ? AND `EndWoche` >= ? AND `$column3` = ?");
					$sth->execute($id, $id2, $id2, $id3);
				} elsif ( $table =~ /^BenutzerModulAbo$/ && $column2 =~ /^Bis$/ ) {
					$sth = $dbh->prepare("SELECT * FROM `$table` WHERE `$column` = ? AND `EndWoche` >= ? AND `$column3` = ?");
					$sth->execute($id, $id2,$id3);
				} else {
					$sth = $dbh->prepare("SELECT * FROM `$table` WHERE `$column` = ? AND `$column2` = ? AND `$column3` = ?");
					$sth->execute($id, $id2,$id3);
				}

			} else {

				print encode_json({result => 0, reason => "unknown path " . $q->path_info});
				# string concat in perl: . (dot operator). Operator + would try to interpret as some number and calc math. sum
			}

			#output query results
			if ($sth) {
				my $results = [];
				while ( my $row = $sth->fetchrow_hashref ) {
					if ($row->{Passwort}) {
						$row->{Passwort} = '***';
					}
					if ($row->{Cookie}) {
						$row->{Cookie} = '*****';
					}
					push(@$results, $row);
				}
				print encode_json($results);
			}

		} elsif ( $q->request_method() =~ /^POST$/ ) {
			my $cur_week = POSIX::strftime("%G.%V", gmtime time);
			my $body = decode_json($q->param( 'POSTDATA' ));
			my $sth;

			if ( $q->path_info =~ /^\/([a-zA-Z]+)\/([a-zA-Z0-9]+)$/ ) {  # ID supplied -> UPDATE
				my $table = $1;
				my $id = $2;

				my @keys = ();
				my @values = ();
				my $key;
				my $value;
				my $reason;
				while (($key, $value) = each (%$body)) {
					if ( $key =~ /^[a-zA-Z0-9_]+$/ && (! ($key =~ /^(ErstellZeitpunkt|AenderZeitpunkt|AenderBenutzer_ID)$/ )) ) {

						if ( $user->{Role_ID} <= 1 && ($key =~ /^Woche$/ || $key =~ /^StartWoche$/ || $key =~ /^EndWoche$/) && $value < $cur_week ) {
							$reason = "Woche muss in Zukunft liegen (>= $cur_week )!";
						} elsif ( ($key =~ /^Passwort$/) && length($value) < 4) {
							$reason = "password min length 4 chars";
						} elsif ( $user->{Role_ID} <= 1 && $table =~ /^Benutzer$/ &&  (! ($key =~ /^(Name|Passwort|Email|Depot_ID|)$/)) ) {
							$reason = "Benutzer darf nur eigenes Passwort und Depot aendern!";
						} else {
							push(@keys, "`$key` = ?");
							push(@values, $value);
						}
					}
				}
				push(@keys, "`AenderBenutzer_ID` = ?");
				push(@values, $user->{ID});
				push(@keys, "`AenderZeitpunkt` = NOW()");
				my $keys = join(",", @keys);
				push(@values, $id);
				my $sql;
				if ($reason) {
					print encode_json({result => 0, reason => $reason || ("no update right for role " . $user->{Role_ID} . " on table $table")});
				} elsif ( @keys.length > 0 && $user->{Role_ID} <= 1 && $table =~ /^Benutzer$/ ) {
					$sql = "UPDATE `$table` SET $keys WHERE `ID` = ? AND `ID` = ?";
					push(@values, $user->{ID});
				} elsif ( @keys.length > 0 && $user->{Role_ID} <= 1 && $table =~ /^BenutzerModulAbo$/ ) {
					push(@values, $user->{ID});
					push(@values, $cur_week);
					if (@keys.length == 3 && $keys[0] =~ /^`(EndWoche|Kommentar)` = .$/ && $keys[1] =~ /^`AenderBenutzer_ID` = .$/ && $keys[2] =~ /^`AenderZeitpunkt` = NOW..$/) {
						$sql = "UPDATE `$table` SET $keys WHERE `ID` = ? AND `Benutzer_ID` = ? AND `EndWoche` >= ?";
					} else {
						$sql = "UPDATE `$table` SET $keys WHERE `ID` = ? AND `Benutzer_ID` = ? AND `StartWoche` >= ? AND `EndWoche` >= ?";
						push(@values, $cur_week);
					}
				} elsif ( @keys.length > 0 && $user->{Role_ID} <= 1 && $table =~ /.*Benutzer.*/ ) {
					$sql = "UPDATE `$table` SET $keys WHERE `ID` = ? AND `Benutzer_ID` = ? AND `Woche` >= ?";
					push(@values, $user->{ID});
					push(@values, $cur_week);
				} elsif ( $user->{Role_ID} == 2 || ($user->{Role_ID} == 3 && $table =~ /.*Benutzer.*/) || ($user->{Role_ID} == 0 && ( ! ( $table =~ /.*Benutzer.*/) ))    ) {
					$sql = "UPDATE `$table` SET $keys WHERE `ID` = ?";
				} else {
					print encode_json({result => 0, reason => $reason || ("no update right for role " . $user->{Role_ID} . " on table $table")});
				}
				if ($sql) {
					eval {
						$sth = $dbh->prepare($sql);
						$sth->execute(@values);
						$dbh->commit();
						print encode_json({result => 1, type => "update", query => $sql, params => [@values]});
					};
					if ($@) {
						print encode_json({result => 0, type => "update", reason => $@, query => $sql, params => [@values]});
					}
				}
			} elsif ( $q->path_info =~ /^\/([a-zA-Z]+)\/?$/ ) { # NO ID yet -> INSERT
				my $table = $1;
				if ( $user->{Role_ID} == 2
					|| ( $user->{Role_ID} == 3 && $table =~ /.*Benutzer.*/)
					|| ( $user->{Role_ID} == 0 && ( ! ( $table =~ /.*Benutzer.*/) )  )
					|| ( $user->{Role_ID} <= 1 && ( $table =~ /.+Benutzer.*/ || $table =~ /^Benutzer.+/ ) && $body->{Benutzer_ID} == $user->{ID} )  ) {

					my @keys = ();
					my @placeholders = ();
					my @values = ();
					my $key;
					my $value;
					my $reason;
					my $onDuplicateKeyUpdate;
					while (($key, $value) = each (%$body)) {
						if ( $key =~ /^[a-zA-Z0-9_]+$/ && (! ($key =~ /^(ErstellZeitpunkt|AenderZeitpunkt|AenderBenutzer_ID)$/ )) ) {
							if ( $key =~ /^onDuplicateKeyUpdate$/ ) {
								if ($value =~ /^[a-zA-Z0-9_]+$/) {
									$onDuplicateKeyUpdate = $value;
								}
							} elsif ( ($user->{Role_ID} == 1 || ($user->{Role_ID} == 0 && $table =~ /.*Benutzer.*/))
								 && ($key =~ /^Woche$/ || $key =~ /^StartWoche$/ || $key =~ /^EndWoche$/) && $value < $cur_week ) {
								$reason = "Woche muss in Zukunft liegen (>= $cur_week )!";
							} else {
								push(@keys, "`$key`");
								push(@values, $value);
								push(@placeholders, "?");
							}
						}
					}
					push(@keys, "`AenderBenutzer_ID`");
					push(@values, $user->{ID});
					push(@placeholders, "?");

					if ($reason) {
						print encode_json({result => 0, reason => $reason || ("no insert right for role " . $user->{Role_ID} . " on table $table")});
					} else {
						my $keys = join(",", @keys);
						my $placeholders = join(",", @placeholders);
						my $sql= "INSERT INTO `$table` ( $keys ) VALUES ( $placeholders )";
						if ( $onDuplicateKeyUpdate ) {
							$sql = $sql . " ON DUPLICATE KEY UPDATE `$onDuplicateKeyUpdate` = ? ";
							push(@values, $body->{$onDuplicateKeyUpdate});
						}
						eval {
							$sth = $dbh->prepare($sql);
							$sth->execute(@values);
							$dbh->commit();
							print encode_json({result => 1, type => "insert", query => $sql, params => [@values], id => $sth->{'mysql_insertid'}});
						};
						if ($@) {
							print encode_json({result => 0, type => "insert", reason => $@, query => $sql, params => [@values]});
						}
					}

				} else {
					print encode_json({result => 0, reason => "no insert right for role " . $user->{Role_ID} . " on table $table"});
				}
			} else {
				print  encode_json({result => 0, reason => "unknown path " . $q->path_info});
			}

		} elsif ( $q->request_method() =~ /^DELETE$/ ) {
			my $cur_week = POSIX::strftime("%G.%V", gmtime time);
			my $last_week = POSIX::strftime("%G.%V", gmtime time - 7 * 24 * 60 * 60);
			my $preSql;
			my $sql;
			my @preValues;
			my @values;
			if ( $q->path_info =~ /^\/([a-zA-Z]+)\/([a-zA-Z0-9]+)$/ ) {
				my $table = $1;
				my $id = $2;

				if ( $user->{Role_ID} <= 1 && $table =~ /^BenutzerModulAbo$/ ) {
					@values = ($id, $user->{ID}, $cur_week, $cur_week);
					@preValues = ($user->{ID}, $id, $user->{ID}, $cur_week, $cur_week);
					$preSql = "UPDATE `$table` SET `AenderBenutzer_ID` = ?, `AenderZeitpunkt` = NOW() WHERE `ID` = ? AND `Benutzer_ID` = ?  AND `StartWoche` >= ? AND `EndWoche` >= ?";
					$sql = "DELETE FROM `$table` WHERE `ID` = ? AND `Benutzer_ID` = ?  AND `StartWoche` >= ? AND `EndWoche` >= ?";
				} elsif ( $user->{Role_ID} <= 1 && ( $table =~ /.+Benutzer.*/ || $table =~ /^Benutzer.+/ ) ) {
					@values = ($id, $user->{ID}, $last_week);
					@preValues = ($user->{ID}, $id, $user->{ID}, $last_week);
					$preSql = "UPDATE `$table` SET `AenderBenutzer_ID` = ?, `AenderZeitpunkt` = NOW() WHERE `ID` = ? AND `Benutzer_ID` = ? AND `Woche` >= ?";
					$sql = "DELETE FROM `$table` WHERE `ID` = ? AND `Benutzer_ID` = ? AND `Woche` >= ?";
				} elsif ( $user->{Role_ID} == 2 || ($user->{Role_ID} == 3 && $table =~ /^.*Benutzer.*$/) || ($user->{Role_ID} == 0 && (! ($table =~ /^.*Benutzer.*$/) ))   ) {
					@values = ($id);
					@preValues = ($user->{ID}, $id);
					$preSql = "UPDATE `$table` SET `AenderBenutzer_ID` = ?, `AenderZeitpunkt` = NOW() WHERE `ID` = ?";
					$sql = "DELETE FROM `$table` WHERE `ID` = ?";
				} else {
					print encode_json({result => 0, reason => "no delete right for role " . $user->{Role_ID} . " on table $table"});
				}
			} elsif ( $q->path_info =~ /^\/([a-zA-Z]+)\/([a-zA-Z0-9_]+)\/([a-zA-Z0-9_.-]+)\/([a-zA-Z0-9_]+)\/([a-zA-Z0-9_.-]+)$/ ) {
				my $table = $1;
				my $column = $2;
				my $id = $column == 'Benutzer_ID' && $3 == 'MY' ? $user->{ID} : $3;
				my $column2 = $4;
				my $id2 = $5;

				if ( $user->{Role_ID} <= 1 && $table =~ /^BenutzerModulAbo$/ ) {
					$preSql = "UPDATE `$table` SET `AenderBenutzer_ID` = ?, `AenderZeitpunkt` = NOW() WHERE `$column` = ? AND `$column2` = ? AND `Benutzer_ID` = ? AND `StartWoche` >= ? AND `EndWoche` >= ?";
					@preValues = ($user->{ID}, $id, $id2, $user->{ID}, $cur_week, $cur_week);
					$sql = "DELETE FROM `$table` WHERE `$column` = ? AND `$column2` = ? AND `Benutzer_ID` = ? AND `StartWoche` >= ? AND `EndWoche` >= ?";
					@values = ($id, $id2, $user->{ID}, $cur_week, $cur_week);
				} elsif ( $user->{Role_ID} <= 1 && ( $table =~ /.+Benutzer.*/ || $table =~ /^Benutzer.+/ ) ) {
					$preSql = "UPDATE `$table` SET `AenderBenutzer_ID` = ?, `AenderZeitpunkt` = NOW() WHERE `$column` = ? AND `$column2` = ? AND `Benutzer_ID` = ? AND `Woche` >= ?";
					@preValues = ($user->{ID}, $id, $id2, $user->{ID}, $last_week);
					$sql = "DELETE FROM `$table` WHERE `$column` = ? AND `$column2` = ? AND `Benutzer_ID` = ? AND `Woche` >= ?";
					@values = ($id, $id2, $user->{ID}, $last_week);
				} elsif ( $user->{Role_ID} == 2 || ($user->{Role_ID} == 3 && $table =~ /^.*Benutzer.*$/) || ($user->{Role_ID} == 0 && (! ($table =~ /^.*Benutzer.*$/) ))   ) {
					$preSql = "UPDATE `$table` SET `AenderBenutzer_ID` = ?, `AenderZeitpunkt` = NOW() WHERE `$column` = ? AND `$column2` = ?";
					@preValues = ($user->{ID}, $id, $id2);
					$sql = "DELETE FROM `$table` WHERE `$column` = ? AND `$column2` = ?";
					@values = ($id, $id2);
				} else {
					print encode_json({result => 0, reason => "no delete right for role " . $user->{Role_ID} . " on table $table"});
				}
			} elsif ( $q->path_info =~ /^\/([a-zA-Z]+)\/([a-zA-Z0-9_]+)\/([a-zA-Z0-9_.-]+)\/([a-zA-Z0-9_]+)\/([a-zA-Z0-9_.-]+)\/([a-zA-Z0-9_]+)\/([a-zA-Z0-9_.-]+)$/ ) {
				my $table = $1;
				my $column = $2;
				my $id = $column == 'Benutzer_ID' && $3 == 'MY' ? $user->{ID} : $3;
				my $column2 = $4;
				my $id2 = $5;
				my $column3 = $6;
				my $id3 = $7;

				if ( $user->{Role_ID} <= 1 && $table =~ /^BenutzerModulAbo$/ ) {
					$preSql = "UPDATE `$table` SET `AenderBenutzer_ID` = ?, `AenderZeitpunkt` = NOW() WHERE `$column` = ? AND `$column2` = ? AND `$column3` = ? AND `Benutzer_ID` = ? AND `StartWoche` >= ? AND `EndWoche` >= ?";
					@preValues = ($user->{ID}, $id, $id2, $id3, $user->{ID}, $cur_week, $cur_week);
					$sql = "DELETE FROM `$table` WHERE `$column` = ? AND `$column2` = ? AND `$column3` = ? AND `Benutzer_ID` = ? AND `StartWoche` >= ? AND `EndWoche` >= ?";
					@values = ($id, $id2, $id3, $user->{ID}, $cur_week, $cur_week);
				} elsif ( $user->{Role_ID} <= 1 && ( $table =~ /.+Benutzer.*/ || $table =~ /^Benutzer.+/ ) ) {
					$preSql = "UPDATE `$table` SET `AenderBenutzer_ID` = ?, `AenderZeitpunkt` = NOW() WHERE `$column` = ? AND `$column2` = ? AND `$column3` = ? AND `Benutzer_ID` = ? AND `Woche` >= ?";
					@preValues = ($user->{ID}, $id, $id2, $id3, $user->{ID}, $last_week);
					$sql = "DELETE FROM `$table` WHERE `$column` = ? AND `$column2` = ? AND `$column3` = ? AND `Benutzer_ID` = ? AND `Woche` >= ?";
					@values = ($id, $id2, $id3, $user->{ID}, $last_week);
				} elsif ( $user->{Role_ID} == 2 || ($user->{Role_ID} == 3 && $table =~ /^.*Benutzer.*$/) || ($user->{Role_ID} == 0 && (! ($table =~ /^.*Benutzer.*$/) ))   ) {
					$preSql = "UPDATE `$table` SET `AenderBenutzer_ID` = ?, `AenderZeitpunkt` = NOW() WHERE `$column` = ? AND `$column2` = ? AND `$column3` = ?";
					@preValues = ($user->{ID}, $id, $id2, $id3);
					$sql = "DELETE FROM `$table` WHERE `$column` = ? AND `$column2` = ? AND `$column3` = ?";
					@values = ($id, $id2, $id3);
				} else {
					print encode_json({result => 0, reason => "no delete right for role " . $user->{Role_ID} . " on table $table"});
				}
			} elsif ( $q->path_info =~ /^\/([a-zA-Z]+)\/([a-zA-Z0-9_]+)\/([a-zA-Z0-9_.-]+)\/([a-zA-Z0-9_]+)\/([a-zA-Z0-9_.-]+)\/([a-zA-Z0-9_]+)\/([a-zA-Z0-9_.-]+)\/([a-zA-Z0-9_]+)\/([a-zA-Z0-9_.-]+)$/ ) {
				my $table = $1;
				my $column = $2;
				my $id = $column == 'Benutzer_ID' && $3 == 'MY' ? $user->{ID} : $3;
				my $column2 = $4;
				my $id2 = $5;
				my $column3 = $6;
				my $id3 = $7;
				my $column4 = $8;
				my $id4 = $9;

				if ( $user->{Role_ID} <= 1 && $table =~ /^BenutzerModulAbo$/ ) {
					$preSql = "UPDATE `$table` SET `AenderBenutzer_ID` = ?, `AenderZeitpunkt` = NOW() WHERE `$column` = ? AND `$column2` = ? AND `$column3` = ? AND `$column4` = ? AND `Benutzer_ID` = ? AND `StartWoche` >= ? AND `EndWoche` >= ?";
					@preValues = ($user->{ID}, $id, $id2, $id3, $id4, $user->{ID}, $cur_week, $cur_week);
					$sql = "DELETE FROM `$table` WHERE `$column` = ? AND `$column2` = ? AND `$column3` = ? AND `$column4` = ? AND `Benutzer_ID` = ? AND `StartWoche` >= ? AND `EndWoche` >= ?";
					@values = ($id, $id2, $id3, $id4, $user->{ID}, $cur_week, $cur_week);
				} elsif ( $user->{Role_ID} <= 1 && ( $table =~ /.+Benutzer.*/ || $table =~ /^Benutzer.+/ ) ) {
					$preSql = "UPDATE `$table` SET `AenderBenutzer_ID` = ?, `AenderZeitpunkt` = NOW() WHERE `$column` = ? AND `$column2` = ? AND `$column3` = ? AND `$column4` = ? AND `Benutzer_ID` = ? AND `Woche` >= ?";
					@preValues = ($user->{ID}, $id, $id2, $id3, $id4, $user->{ID}, $last_week);
					$sql = "DELETE FROM `$table` WHERE `$column` = ? AND `$column2` = ? AND `$column3` = ? AND `$column4` = ? AND `Benutzer_ID` = ? AND `Woche` >= ?";
					@values = ($id, $id2, $id3, $id4, $user->{ID}, $last_week);
				} elsif ( $user->{Role_ID} == 2 || ($user->{Role_ID} == 3 && $table =~ /^.*Benutzer.*$/) || ($user->{Role_ID} == 0 && (! ($table =~ /^.*Benutzer.*$/) ))   ) {
					$preSql = "UPDATE `$table` SET `AenderBenutzer_ID` = ?, `AenderZeitpunkt` = NOW() WHERE `$column` = ? AND `$column2` = ? AND `$column3` = ? AND `$column4` = ?";
					@preValues = ($user->{ID}, $id, $id2, $id3, $id4);
					$sql = "DELETE FROM `$table` WHERE `$column` = ? AND `$column2` = ? AND `$column3` = ? AND `$column4` = ?";
					@values = ($id, $id2, $id3, $id4);
				} else {
					print encode_json({result => 0, reason => "no delete right for role " . $user->{Role_ID} . " on table $table"});
				}
			} else {
				print  encode_json({result => 0, reason => "unknown path " . $q->path_info});
			}
			if ($sql) {
				eval {
					my $preSth = $dbh->prepare($preSql);
					$preSth->execute(@preValues);
					my $sth = $dbh->prepare($sql);
					$sth->execute(@values);
					$dbh->commit();
					print encode_json({result => 1, type => "delete", query => $sql, params => [@values]});
				};
				if ($@) {
					print encode_json({result => 0, type => "delete", reason => $@, query => $sql, params => [@values]});
				}
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


