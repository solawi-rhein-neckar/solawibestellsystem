<?php
/*
 * Attrappe der Website-Brücke (auf dem Server: mitglieder/_intern/bestellsystem.php der Website) für die Tests des Bestellsystems.
 * Gleicher Vertrag wie das Original:
 *   pruefen   stdin: Cookie mg_s, dann "<zugang_id>\t<benutzer_id>\t<email>" je Zeile -> "OK <zid> <bid> <bis>" | "NEIN" | "MEHRDEUTIG"
 *   abmelden  stdin: Cookie mg_s -> "OK"
 * Statt Schlüssel und Prüfsummen liest sie die Anmeldungen der Website aus einer JSON-Datei (ATTRAPPE_DATEI):
 *   { "<cookie>": { "email": "...", "bis": <unix-zeit> }, ... }
 * Jeder Aufruf wird in ATTRAPPE_DATEI.log mitgeschrieben (Befehl und Zahl der Zeilen, keine Adressen), damit der Test sieht,
 * dass Adressen über stdin kommen und nicht über die Kommandozeile.
 */
$datei = getenv('ATTRAPPE_DATEI');
if (!$datei || !is_file($datei)) {
    fwrite(STDERR, "ATTRAPPE_DATEI fehlt\n");
    exit(2);
}
$befehl = $argv[1] ?? '';
$weitere = count($argv) - 2;
$sid = trim((string) fgets(STDIN));
$zeilen = [];
while (($z = fgets(STDIN)) !== false) {
    $zeilen[] = rtrim($z, "\r\n");
}
file_put_contents($datei . '.log', $befehl . ' argumente=' . $weitere . ' zeilen=' . count($zeilen) . "\n", FILE_APPEND);
$anmeldungen = json_decode((string) file_get_contents($datei), true) ?: [];

if ($befehl === 'abmelden') {
    unset($anmeldungen[$sid]);
    file_put_contents($datei, json_encode($anmeldungen));
    echo "OK\n";
    exit(0);
}
if ($befehl !== 'pruefen') {
    exit(2);
}
$s = $anmeldungen[$sid] ?? null;
if (!preg_match('/^[A-Za-z0-9_-]{43}$/', $sid) || !is_array($s) || (int) $s['bis'] < time()) {
    echo "NEIN\n";
    exit(0);
}
$treffer = null;
$anteile = [];
foreach ($zeilen as $z) {
    $t = explode("\t", $z);
    if (count($t) !== 3 || !ctype_digit($t[0]) || !ctype_digit($t[1]) || (int) $t[1] < 1) {
        continue;
    }
    if (strtolower(trim($t[2])) !== strtolower(trim($s['email']))) {
        continue;
    }
    $anteile[(int) $t[1]] = true;
    if ($treffer === null) {
        $treffer = $t;
    }
}
if ($treffer === null) {
    echo "NEIN\n";
} elseif (count($anteile) > 1) {
    echo "MEHRDEUTIG\n";
} else {
    echo 'OK ' . (int) $treffer[0] . ' ' . (int) $treffer[1] . ' ' . (int) $s['bis'] . "\n";
}
exit(0);
