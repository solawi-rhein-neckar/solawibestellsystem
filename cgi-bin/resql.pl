﻿#!/usr/bin/perl
use strict;
use warnings;
use utf8;

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
# Users with Benutzer.Role_ID == 2 can read all Tables that have NOT 'Benutzer' in their name, Users with Role_ID != 1 can read all Tables.
# Users with Benutzer.Role_ID <= 2 can read and update/insert rows of tables with 'Benutzer' in their name, if and only
# IF the row has a column 'Benutzer_ID' with value of the logged in users Benutzer.ID
# (further restrictions apply, i.e. only editing if "Woche" is in Future)
#
# Users with Benutzer.Role_ID == 3 or 4 can update/insert/delete all rows in all Tables, that have 'Benutzer' in their name (Role_ID = 3 (Depotverwalter): select limited to own depot)
# Users with Benutzer.Role_ID == 1 can update all other Tables (Produkte, Deliveries etc = Packteam)
# Users with Benutzer.Role_ID == 5 can do everything (=Admin).
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

use constant {
    R_PROD   => 1,
    R_USER   => 2,
    R_DEPOT  => 3,
    R_ORGA   => 4,
    R_ADMIN  => 5
};

my $q = CGI::Simple->new;

# get database handle
my $dbh = DBI->connect("DBI:mysql:database=db208674_361;host=mysql", "db208674_361", "",  { RaiseError => 1, AutoCommit => 0, mysql_enable_utf8mb4 => 1 });

if ( $q->request_method() =~ /^OPTIONS/ ) {
	print $q->header({'Cache-Control'=> 'no-store, no-cache, must-revalidate, s-maxage=0',"content-type" => "application/json", "access_control_allow_origin" => $q->referer() ? "http://solawi.fairtrademap.de" : "null", "Access-Control-Allow-Methods" => "POST, GET, OPTIONS, DELETE", "Access-Control-Allow-Headers" => "content-type,x-requested-with", "Access-Control-Allow-Credentials" => "true"});
}


# user wants to login?
if ( $q->request_method() =~ /^POST$/ && $q->path_info =~ /^\/login\/?/ ) {

	my $sessionid = rand();
	my $body = decode_json($q->param( 'POSTDATA' ));
	my $stl = $dbh->prepare("UPDATE `Benutzer` SET `Cookie` = ? WHERE `Name` = ? and `Passwort` = ?");
	$stl->execute($sessionid, $body->{name}, $body->{password});
	my $cookie = CGI::Simple::Cookie->new( -name=>'sessionid', -value=>$sessionid );

	# print http header with cookies
	print $q->header( {'Cache-Control'=> 'no-store, no-cache, must-revalidate, s-maxage=0',cookie => [$cookie], "content-type" => "application/json", "access_control_allow_origin" => $q->referer() ? "http://solawi.fairtrademap.de" : "null", "Access-Control-Allow-Credentials" => "true"} );
	print encode_json({result => $stl->rows()});
	$dbh->commit();

} elsif ( $q->path_info =~  /^[a-zA-Z0-9\/._ -]*$/) {
	# print http header
	print $q->header({'Cache-Control'=> 'no-store, no-cache, must-revalidate, s-maxage=0',"content-type" => "application/json", "access_control_allow_origin" => $q->referer() ? "http://solawi.fairtrademap.de" : "null", "Access-Control-Allow-Credentials" => "true"});

	# user does not want to login -> check if logged in (sessionid cookie)
	my %cookies = CGI::Simple::Cookie->fetch;
	my $bc = $cookies{'sessionid'} ? $cookies{'sessionid'}->value : undef;
	my $stbc = $dbh->prepare("SELECT * FROM `Benutzer` WHERE `Cookie` = ?");
	$stbc->execute($bc);
        $dbh->prepare("SET NAMES utf8mb4")->execute();
	if ( my $user = $stbc->fetchrow_hashref ) { # is logged in: sessionid cookie verified

		if ( $q->request_method() =~ /^GET$/ ) {

			my $sth;

			if ( $q->path_info =~ /^\/([a-zA-Z]+)\/?(MY|OWN|ACTIVE)?$/ ) {
				# regex matching with perl: will put capture group in implicit variables $1, $2, ...
				my $table = $1;
				my $filter = $2;

				if ( ($filter eq "MY" || $filter eq "OWN" || $user->{Role_ID} <= R_USER) && $table =~ /^Benutzer(View)?$/ ) {
					$sth = $dbh->prepare("SELECT * FROM `$table` WHERE `ID` = ?");
					$sth->execute($user->{ID});
				} elsif ( ($filter eq "MY" || $filter eq "OWN" || $user->{Role_ID} <= R_USER) && $table =~ /.*Benutzer.*/ ) {
					$sth = $dbh->prepare("SELECT * FROM `$table` WHERE `Benutzer_ID` = ?");
					$sth->execute($user->{ID});
				} elsif ( ($user->{Role_ID} == R_DEPOT) && $table =~ /^Benutzer(View)?$/ ) {
					$sth = $dbh->prepare("SELECT * FROM `$table` WHERE `ID` in ( SELECT ID FROM Benutzer WHERE Depot_ID = ?)");
					$sth->execute($user->{Depot_ID});
				} elsif ( ($user->{Role_ID} == R_DEPOT) && $table =~ /.*Benutzer.*/ ) {
					$sth = $dbh->prepare("SELECT * FROM `$table` WHERE `Benutzer_ID` in ( SELECT ID FROM Benutzer WHERE Depot_ID = ?)");
					$sth->execute($user->{Depot_ID});
				} elsif ($filter eq "ACTIVE" ){
					$sth = $dbh->prepare("SELECT * FROM `$table` WHERE Depot_ID > 0");
					$sth->execute();
				} else {
					$sth = $dbh->prepare("SELECT * FROM `$table`");
					$sth->execute();
				}

			} elsif ( $q->path_info =~ /^\/([a-zA-Z]+)\/([a-zA-Z0-9_.-]+)$/ ) {
				my $table = $1;
				my $id = $2;

				if ( $user->{Role_ID} <= R_USER && $table =~ /^Benutzer(View)?$/ ) {
					$sth = $dbh->prepare("SELECT * FROM `$table` WHERE `ID` = ? AND `ID` = ?");
					$sth->execute($id, $user->{ID});
				} elsif ( $table =~ /^BenutzerBestellungView$/ ) {
					$sth = $dbh->prepare("CALL $table(?,?,?)");
					$sth->execute($id,$user->{ID},undef);
				} elsif ( $table =~ /^BenutzerPunkteUpdate$/ ||  $table =~ /^BenutzerPunkte$/) {
					$dbh->{AutoCommit} = 1;
					$sth = $dbh->prepare("CALL $table(?)");
					$sth->execute($user->{Role_ID} <= R_USER ? $user->{ID} : $id == 'null' || $id == 'NULL' ? undef : $id);
				} elsif ( $user->{Role_ID} <= R_USER && $table =~ /.*Benutzer.*/ ) {
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

				if ( $user->{Role_ID} <= R_USER && $table =~ /^Benutzer(View)?$/ ) {
					$sth = $dbh->prepare("SELECT * FROM `$table` WHERE `$column` = ? AND `ID` = ?");
					$sth->execute($id, $user->{ID});
				} elsif ( $user->{Role_ID} <= R_USER && $table =~ /^BenutzerModulAbo$/ && $column =~ /^Woche$/ ) {
					$sth = $dbh->prepare("SELECT * FROM `$table` WHERE `StartWoche` <= ? AND `EndWoche` >= ? AND `Benutzer_ID` = ?");
					$sth->execute($id, $id, $user->{ID});
				} elsif ( $user->{Role_ID} <= R_USER && $table =~ /^BenutzerModulAbo$/ && $column =~ /^Bis$/ ) {
					$sth = $dbh->prepare("SELECT * FROM `$table` WHERE `EndWoche` >= ? AND `Benutzer_ID` = ?");
					$sth->execute($id, $user->{ID});
				} elsif ( $user->{Role_ID} <= R_USER && $table =~ /.*Benutzer.*/ ) {
					$sth = $dbh->prepare("SELECT * FROM `$table` WHERE `$column` = ? AND `Benutzer_ID` = ?");
					$sth->execute($id, $user->{ID});
				} elsif ( ($user->{Role_ID} == R_DEPOT) && $table =~ /^Benutzer(View)?$/ ) {
					$sth = $dbh->prepare("SELECT * FROM `$table` WHERE `$column` = ? AND `ID` in ( SELECT ID FROM Benutzer WHERE Depot_ID = ?)");
					$sth->execute($id, $user->{Depot_ID});
				} elsif ( $user->{Role_ID} == R_DEPOT && $table =~ /^BenutzerModulAbo$/ && $column =~ /^Woche$/ ) {
					$sth = $dbh->prepare("SELECT * FROM `$table` WHERE `StartWoche` <= ? AND `EndWoche` >= ? AND `Benutzer_ID` in ( SELECT ID FROM Benutzer WHERE Depot_ID = ?)");
					$sth->execute($id, $id, $user->{Depot_ID});
				} elsif ( $user->{Role_ID} == R_DEPOT && $table =~ /^BenutzerModulAbo$/ && $column =~ /^Bis$/ ) {
					$sth = $dbh->prepare("SELECT * FROM `$table` WHERE `EndWoche` >= ? AND `Benutzer_ID` in ( SELECT ID FROM Benutzer WHERE Depot_ID = ?)");
					$sth->execute($id, $user->{Depot_ID});
				} elsif ( ($user->{Role_ID} == R_DEPOT) && $table =~ /^BenutzerBestellungView$/ && $column =~ /^Woche$/) {
					$sth = $dbh->prepare("CALL $table(?,?,?)");
					$sth->execute($id,undef,$user->{Depot_ID});
				} elsif ( $table =~ /^BenutzerPunkteView$/ ||  $table =~ /^BenutzerPunkte$/) {
					$sth = $dbh->prepare("CALL $table(?, ?)");
					$sth->execute($user->{Role_ID} <= R_USER ? $user->{ID} : $id == 'null' || $id == 'NULL' ? undef : $id, $column);
				} elsif ( ($user->{Role_ID} == R_DEPOT) && $table =~ /.*Benutzer.*/ ) {
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

				if ( $user->{Role_ID} <= R_USER && $table =~ /^Benutzer(View)?$/ ) {
					$sth = $dbh->prepare("SELECT * FROM `$table` WHERE `$column` = ? AND `$column2` = ? AND `ID` = ?");
					$sth->execute($id, $id2, $user->{ID});
				} elsif ( $user->{Role_ID} <= R_USER && $table =~ /^BenutzerBestellungView$/ && $column2 == 'Woche' && $column == 'Benutzer_ID') {
					$sth = $dbh->prepare("CALL $table(?,?,?)");
					$sth->execute($id2,$user->{ID},undef);
				} elsif ( $user->{Role_ID} <= R_USER && $table =~ /^BenutzerModulAbo$/ && $column2 =~ /^Woche$/ ) {
					$sth = $dbh->prepare("SELECT * FROM `$table` WHERE `$column` = ? AND `StartWoche` <= ? AND `EndWoche` >= ? AND `Benutzer_ID` = ?");
					$sth->execute($id, $id2, $id2, $user->{ID});
				} elsif ( $user->{Role_ID} <= R_USER && $table =~ /^BenutzerModulAbo$/ && $column2 =~ /^Bis$/ ) {
					$sth = $dbh->prepare("SELECT * FROM `$table` WHERE `$column` = ? AND `EndWoche` >= ? AND `Benutzer_ID` = ?");
					$sth->execute($id, $id2, $user->{ID});
				} elsif ( $user->{Role_ID} <= R_USER && $table =~ /.*Benutzer.*/ ) {
					$sth = $dbh->prepare("SELECT * FROM `$table` WHERE `$column` = ? AND `$column2` = ? AND `Benutzer_ID` = ?");
					$sth->execute($id, $id2, $user->{ID});
				} elsif ( ($user->{Role_ID} == R_DEPOT) && $table =~ /^Benutzer(View)?$/ ) {
					$sth = $dbh->prepare("SELECT * FROM `$table` WHERE `$column` = ? AND `$column2` = ? AND `ID` in ( SELECT ID FROM Benutzer WHERE Depot_ID = ?)");
					$sth->execute($id, $id2, $user->{Depot_ID});
				} elsif ( $user->{Role_ID} >= R_DEPOT && $table =~ /^BenutzerBestellungView$/ && $column2 == 'Woche' && $column == 'Benutzer_ID') {
					$sth = $dbh->prepare("CALL $table(?,?,?)");
					$sth->execute($id2,$id,undef);
				} elsif ( $user->{Role_ID} >= R_DEPOT && $table =~ /^BenutzerBestellungView$/ && $column2 == 'Woche' && $column == 'Depot_ID') {
					$sth = $dbh->prepare("CALL $table(?,?,?)");
					$sth->execute($id2,undef,$id);
				} elsif ( $user->{Role_ID} == R_DEPOT && $table =~ /^BenutzerModulAbo$/ && $column2 =~ /^Woche$/ ) {
					$sth = $dbh->prepare("SELECT * FROM `$table` WHERE `$column` = ? AND `StartWoche` <= ? AND `EndWoche` >= ? AND `Benutzer_ID` in ( SELECT ID FROM Benutzer WHERE Depot_ID = ?)");
					$sth->execute($id, $id2, $id2, $user->{Depot_ID});
				} elsif ( $user->{Role_ID} == R_DEPOT && $table =~ /^BenutzerModulAbo$/ && $column2 =~ /^Bis$/ ) {
					$sth = $dbh->prepare("SELECT * FROM `$table` WHERE `$column` = ? AND `EndWoche` >= ? AND `Benutzer_ID` in ( SELECT ID FROM Benutzer WHERE Depot_ID = ?)");
					$sth->execute($id, $id2, $user->{Depot_ID});
				} elsif ( ($user->{Role_ID} == R_DEPOT) && $table =~ /.*Benutzer.*/ ) {
					$sth = $dbh->prepare("SELECT * FROM `$table` WHERE `$column` = ? AND `$column2` = ? AND `Benutzer_ID` in ( SELECT ID FROM Benutzer WHERE Depot_ID = ?)");
					$sth->execute($id, $id2, $user->{Depot_ID});
				} elsif ( $table =~ /^BenutzerModulAbo$/ && $column2 =~ /^Woche$/ ) {
					$sth = $dbh->prepare("SELECT * FROM `$table` WHERE `$column` = ? AND `StartWoche` <= ? AND `EndWoche` >= ?");
					$sth->execute($id, $id2, $id2);
				} elsif ( $table =~ /^BenutzerModulAbo$/ && $column2 =~ /^Bis$/ ) {
					$sth = $dbh->prepare("SELECT * FROM `$table` WHERE `$column` = ? AND `EndWoche` >= ?");
					$sth->execute($id, $id2);
				} elsif ( $user->{Role_ID} > R_USER && $table =~ /^PivotDepot.*/ ) {
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

				if ( $user->{Role_ID} <= R_USER && $table =~ /^Benutzer(View)?$/ ) {
					$sth = $dbh->prepare("SELECT * FROM `$table` WHERE `$column` = ? AND `$column2` = ? AND `$column3` = ? AND `ID` = ?");
					$sth->execute($id, $id2, $id3, $user->{ID});
				} elsif ( $user->{Role_ID} <= R_USER && $table =~ /^BenutzerModulAbo$/ && $column2 =~ /^Woche$/ ) {
					$sth = $dbh->prepare("SELECT * FROM `$table` WHERE `$column` = ? AND `StartWoche` <= ? AND `EndWoche` >= ? AND `$column3` = ? AND `Benutzer_ID` = ?");
					$sth->execute($id, $id2, $id2, $id3, $user->{ID});
				} elsif ( $user->{Role_ID} <= R_USER && $table =~ /^BenutzerModulAbo$/ && $column2 =~ /^Bis$/ ) {
					$sth = $dbh->prepare("SELECT * FROM `$table` WHERE `$column` = ? AND `EndWoche` >= ? AND `$column3` = ? AND `Benutzer_ID` = ?");
					$sth->execute($id, $id2, $id3, $user->{ID});
				} elsif ( $user->{Role_ID} <= R_USER && $table =~ /.*Benutzer.*/ ) {
					$sth = $dbh->prepare("SELECT * FROM `$table` WHERE `$column` = ? AND `$column2` = ? AND `$column3` = ? AND `Benutzer_ID` = ?");
					$sth->execute($id, $id2, $id3, $user->{ID});
				} elsif ( ($user->{Role_ID} == R_DEPOT) && $table =~ /^Benutzer(View)?$/ ) {
					$sth = $dbh->prepare("SELECT * FROM `$table` WHERE `$column` = ? AND `$column2` = ? AND `$column3` = ? AND `ID` in ( SELECT ID FROM Benutzer WHERE Depot_ID = ?)");
					$sth->execute($id, $id2, $id3, $user->{Depot_ID});
				} elsif ( $user->{Role_ID} == R_DEPOT && $table =~ /^BenutzerModulAbo$/ && $column2 =~ /^Woche$/ ) {
					$sth = $dbh->prepare("SELECT * FROM `$table` WHERE `$column` = ? AND `StartWoche` <= ? AND `EndWoche` >= ? AND `$column3` = ? AND `Benutzer_ID` in ( SELECT ID FROM Benutzer WHERE Depot_ID = ?)");
					$sth->execute($id, $id2, $id2, $id3, $user->{Depot_ID});
				} elsif ( $user->{Role_ID} == R_DEPOT && $table =~ /^BenutzerModulAbo$/ && $column2 =~ /^Bis$/ ) {
					$sth = $dbh->prepare("SELECT * FROM `$table` WHERE `$column` = ? AND `EndWoche` >= ? AND `$column3` = ? AND `Benutzer_ID` in ( SELECT ID FROM Benutzer WHERE Depot_ID = ?)");
					$sth->execute($id, $id2, $id3, $user->{Depot_ID});
				} elsif ( ($user->{Role_ID} == R_DEPOT) && $table =~ /.*Benutzer.*/ ) {
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

					if ($user->{Role_ID} <= R_DEPOT) {
						my @keys = keys %$row;
						foreach my $key (@keys) {
							if ($key =~ /^_.*$/) {
								delete($row->{$key});
							}
						}
					}

					# FIX DUPLICATE UTF_8 ENCODING of COLUMN NAMES
					my @keys = keys %$row;
					foreach my $key (@keys) {
						my $value = $row->{$key};
						delete($row->{$key});
						utf8::decode($key);
						$row->{$key} = $value;
					}

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

						if ( $user->{Role_ID} <= R_USER && ($key =~ /^Woche$/ || $key =~ /^StartWoche$/ || $key =~ /^EndWoche$/) && $value < $cur_week ) {
							$reason = "Woche muss in Zukunft liegen (>= $cur_week )!";
						} elsif ( ($key =~ /^Passwort$/) && length($value) < 4) {
							$reason = "password min length 4 chars";
						} elsif ( $user->{Role_ID} <= R_USER && $table =~ /^Benutzer$/ &&  (! ($key =~ /^(Name|Passwort|Email|Depot_ID|)$/)) ) {
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
				} elsif ( @keys.length > 0 && $user->{Role_ID} <= R_USER && $table =~ /^Benutzer$/ ) {
					$sql = "UPDATE `$table` SET $keys WHERE `ID` = ? AND `ID` = ?";
					push(@values, $user->{ID});
				} elsif ( @keys.length > 0 && $user->{Role_ID} <= R_USER && $table =~ /^BenutzerModulAbo$/ ) {
					push(@values, $user->{ID});
					push(@values, $cur_week);
					if (@keys.length == 3 && $keys[0] =~ /^`(EndWoche|Kommentar)` = .$/ && $keys[1] =~ /^`AenderBenutzer_ID` = .$/ && $keys[2] =~ /^`AenderZeitpunkt` = NOW..$/) {
						$sql = "UPDATE `$table` SET $keys WHERE `ID` = ? AND `Benutzer_ID` = ? AND `EndWoche` >= ?";
					} else {
						$sql = "UPDATE `$table` SET $keys WHERE `ID` = ? AND `Benutzer_ID` = ? AND `StartWoche` >= ? AND `EndWoche` >= ?";
						push(@values, $cur_week);
					}
				} elsif ( @keys.length > 0 && $user->{Role_ID} <= R_USER && $table =~ /.*Benutzer.*/ ) {
					$sql = "UPDATE `$table` SET $keys WHERE `ID` = ? AND `Benutzer_ID` = ? AND `Woche` >= ?";
					push(@values, $user->{ID});
					push(@values, $cur_week);
				} elsif ( $user->{Role_ID} == R_ADMIN || ($user->{Role_ID} >= R_DEPOT && $table =~ /.*Benutzer.*/) || ($user->{Role_ID} == R_PROD && ( ! ( $table =~ /.*Benutzer.*/) ))    ) {
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
				if ( $user->{Role_ID} == R_ADMIN
					|| ( $user->{Role_ID} >= R_DEPOT && $table =~ /.*Benutzer.*/)
					|| ( $user->{Role_ID} == R_PROD && ( ! ( $table =~ /.*Benutzer.*/) )  )
					|| ( $user->{Role_ID} <= R_USER && ( $table =~ /.+Benutzer.*/ || $table =~ /^Benutzer.+/ ) && $body->{Benutzer_ID} == $user->{ID} )  ) {

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
							} elsif ( ($user->{Role_ID} == R_USER || ($user->{Role_ID} == R_PROD && $table =~ /.*Benutzer.*/))
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

				if ( $user->{Role_ID} <= R_USER && $table =~ /^BenutzerModulAbo$/ ) {
					@values = ($id, $user->{ID}, $cur_week, $cur_week);
					@preValues = ($user->{ID}, $id, $user->{ID}, $cur_week, $cur_week);
					$preSql = "UPDATE `$table` SET `AenderBenutzer_ID` = ?, `AenderZeitpunkt` = NOW() WHERE `ID` = ? AND `Benutzer_ID` = ?  AND `StartWoche` >= ? AND `EndWoche` >= ?";
					$sql = "DELETE FROM `$table` WHERE `ID` = ? AND `Benutzer_ID` = ?  AND `StartWoche` >= ? AND `EndWoche` >= ?";
				} elsif ( $user->{Role_ID} <= R_USER && ( $table =~ /.+Benutzer.*/ || $table =~ /^Benutzer.+/ ) ) {
					@values = ($id, $user->{ID}, $last_week);
					@preValues = ($user->{ID}, $id, $user->{ID}, $last_week);
					$preSql = "UPDATE `$table` SET `AenderBenutzer_ID` = ?, `AenderZeitpunkt` = NOW() WHERE `ID` = ? AND `Benutzer_ID` = ? AND `Woche` >= ?";
					$sql = "DELETE FROM `$table` WHERE `ID` = ? AND `Benutzer_ID` = ? AND `Woche` >= ?";
				} elsif ( $user->{Role_ID} == R_ADMIN || ($user->{Role_ID} >= R_DEPOT && $table =~ /^.*Benutzer.*$/) || ($user->{Role_ID} == R_PROD && (! ($table =~ /^.*Benutzer.*$/) ))   ) {
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

				if ( $user->{Role_ID} <= R_USER && $table =~ /^BenutzerModulAbo$/ ) {
					$preSql = "UPDATE `$table` SET `AenderBenutzer_ID` = ?, `AenderZeitpunkt` = NOW() WHERE `$column` = ? AND `$column2` = ? AND `Benutzer_ID` = ? AND `StartWoche` >= ? AND `EndWoche` >= ?";
					@preValues = ($user->{ID}, $id, $id2, $user->{ID}, $cur_week, $cur_week);
					$sql = "DELETE FROM `$table` WHERE `$column` = ? AND `$column2` = ? AND `Benutzer_ID` = ? AND `StartWoche` >= ? AND `EndWoche` >= ?";
					@values = ($id, $id2, $user->{ID}, $cur_week, $cur_week);
				} elsif ( $user->{Role_ID} <= R_USER && ( $table =~ /.+Benutzer.*/ || $table =~ /^Benutzer.+/ ) ) {
					$preSql = "UPDATE `$table` SET `AenderBenutzer_ID` = ?, `AenderZeitpunkt` = NOW() WHERE `$column` = ? AND `$column2` = ? AND `Benutzer_ID` = ? AND `Woche` >= ?";
					@preValues = ($user->{ID}, $id, $id2, $user->{ID}, $last_week);
					$sql = "DELETE FROM `$table` WHERE `$column` = ? AND `$column2` = ? AND `Benutzer_ID` = ? AND `Woche` >= ?";
					@values = ($id, $id2, $user->{ID}, $last_week);
				} elsif ( $user->{Role_ID} == R_ADMIN || ($user->{Role_ID} >= R_DEPOT && $table =~ /^.*Benutzer.*$/) || ($user->{Role_ID} == R_PROD && (! ($table =~ /^.*Benutzer.*$/) ))   ) {
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

				if ( $user->{Role_ID} <= R_USER && $table =~ /^BenutzerModulAbo$/ ) {
					$preSql = "UPDATE `$table` SET `AenderBenutzer_ID` = ?, `AenderZeitpunkt` = NOW() WHERE `$column` = ? AND `$column2` = ? AND `$column3` = ? AND `Benutzer_ID` = ? AND `StartWoche` >= ? AND `EndWoche` >= ?";
					@preValues = ($user->{ID}, $id, $id2, $id3, $user->{ID}, $cur_week, $cur_week);
					$sql = "DELETE FROM `$table` WHERE `$column` = ? AND `$column2` = ? AND `$column3` = ? AND `Benutzer_ID` = ? AND `StartWoche` >= ? AND `EndWoche` >= ?";
					@values = ($id, $id2, $id3, $user->{ID}, $cur_week, $cur_week);
				} elsif ( $user->{Role_ID} <= R_USER && ( $table =~ /.+Benutzer.*/ || $table =~ /^Benutzer.+/ ) ) {
					$preSql = "UPDATE `$table` SET `AenderBenutzer_ID` = ?, `AenderZeitpunkt` = NOW() WHERE `$column` = ? AND `$column2` = ? AND `$column3` = ? AND `Benutzer_ID` = ? AND `Woche` >= ?";
					@preValues = ($user->{ID}, $id, $id2, $id3, $user->{ID}, $last_week);
					$sql = "DELETE FROM `$table` WHERE `$column` = ? AND `$column2` = ? AND `$column3` = ? AND `Benutzer_ID` = ? AND `Woche` >= ?";
					@values = ($id, $id2, $id3, $user->{ID}, $last_week);
				} elsif ( $user->{Role_ID} == R_ADMIN || ($user->{Role_ID} >= R_DEPOT && $table =~ /^.*Benutzer.*$/) || ($user->{Role_ID} == R_PROD && (! ($table =~ /^.*Benutzer.*$/) ))   ) {
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

				if ( $user->{Role_ID} <= R_USER && $table =~ /^BenutzerModulAbo$/ ) {
					$preSql = "UPDATE `$table` SET `AenderBenutzer_ID` = ?, `AenderZeitpunkt` = NOW() WHERE `$column` = ? AND `$column2` = ? AND `$column3` = ? AND `$column4` = ? AND `Benutzer_ID` = ? AND `StartWoche` >= ? AND `EndWoche` >= ?";
					@preValues = ($user->{ID}, $id, $id2, $id3, $id4, $user->{ID}, $cur_week, $cur_week);
					$sql = "DELETE FROM `$table` WHERE `$column` = ? AND `$column2` = ? AND `$column3` = ? AND `$column4` = ? AND `Benutzer_ID` = ? AND `StartWoche` >= ? AND `EndWoche` >= ?";
					@values = ($id, $id2, $id3, $id4, $user->{ID}, $cur_week, $cur_week);
				} elsif ( $user->{Role_ID} <= R_USER && ( $table =~ /.+Benutzer.*/ || $table =~ /^Benutzer.+/ ) ) {
					$preSql = "UPDATE `$table` SET `AenderBenutzer_ID` = ?, `AenderZeitpunkt` = NOW() WHERE `$column` = ? AND `$column2` = ? AND `$column3` = ? AND `$column4` = ? AND `Benutzer_ID` = ? AND `Woche` >= ?";
					@preValues = ($user->{ID}, $id, $id2, $id3, $id4, $user->{ID}, $last_week);
					$sql = "DELETE FROM `$table` WHERE `$column` = ? AND `$column2` = ? AND `$column3` = ? AND `$column4` = ? AND `Benutzer_ID` = ? AND `Woche` >= ?";
					@values = ($id, $id2, $id3, $id4, $user->{ID}, $last_week);
				} elsif ( $user->{Role_ID} == R_ADMIN || ($user->{Role_ID} >= R_DEPOT && $table =~ /^.*Benutzer.*$/) || ($user->{Role_ID} == R_PROD && (! ($table =~ /^.*Benutzer.*$/) ))   ) {
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
	print encode_json({result => 0, reason => "path contains forbidden characters"});
}


# close database handle
$dbh->disconnect


