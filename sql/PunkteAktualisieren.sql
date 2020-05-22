UPDATE Benutzer SET PunkteStand = PunkteStand
+ IFNULL((SELECT SUM(IF(Modul_ID = 2, 3, AnzahlProAnteil) * ModulInhalt.Anzahl * Produkt.Punkte * IF(Modul_ID = 4, Benutzer.FleischAnteile, Benutzer.Anteile))
   FROM Modul JOIN ModulInhalt on Modul.ID = ModulInhalt.Modul_ID JOIN ModulInhaltWoche on ModulInhaltWoche.ModulInhalt_ID = ModulInhalt.ID Join Produkt on ModulInhalt.Produkt_ID = Produkt.ID
   where ModulInhaltWoche.Woche > Benutzer.PunkteWoche AND ModulInhaltWoche.Woche <= cast(yearweek((curdate() - interval 4 day),1)/100 as decimal(6,2))), 0)
- IFNULL((SELECT SUM(BenutzerBestellViewUnsorted.Punkte)
   FROM BenutzerBestellViewUnsorted JOIN Produkt ON BenutzerBestellViewUnsorted.Produkt_ID = Produkt.ID
   WHERE BenutzerBestellViewUnsorted.Benutzer_ID = Benutzer.ID AND BenutzerBestellViewUnsorted.Woche > Benutzer.PunkteWoche
   AND BenutzerBestellViewUnsorted.Woche <= cast(yearweek((curdate() - interval 4 day),1)/100 as decimal(6,2))), 0)
, PunkteWoche = cast(yearweek((curdate() - interval 4 day),1)/100 as decimal(6,2))