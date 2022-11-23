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
my $dbh = DBI->connect("DBI:mysql:database=db208674_361;host=mysql", "db208674_361", "",  { RaiseError => 1, AutoCommit => 0, mysql_enable_utf8 => ($q->request_method() =~ /^POST$/) });

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



