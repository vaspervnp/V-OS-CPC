# V-OS NET

Ένα μικρό BBS σε .NET 10 για Linux, στο οποίο συνδέεται το πρόγραμμα
TELNET του V-OS (`myapps/telnet`) μέσω της κάρτας M4, και κάθε κοινός
πελάτης telnet (PuTTY, `telnet`, SyncTERM). Νέα του V-OS από το GitHub,
πίνακας μηνυμάτων, ζωντανή συζήτηση, βιβλίο επισκεπτών, λογαριασμοί με
ρόλους, και διαχείριση στο web. Η προδιαγραφή είναι το [DESIGN.md](DESIGN.md).

```
server/
  VosNet.sln
  src/VosNet.Server/   Program.cs: web και telnet σε μία διεργασία, ακροατές, set-owner, appsettings.json
  src/VosNet.Telnet/   TelnetParser, OptionNegotiator (RFC 1143), LineReader, TerminalProfile, VosEncoding, TextWrap
  src/VosNet.Core/     οθόνες (Screens/), υπηρεσίες (Services/), SQLite με Dapper (Storage/, Migrations/*.sql)
  src/VosNet.Web/      Razor Pages: /admin και η δημόσια αρχική σελίδα
  tests/VosNet.Tests/  xUnit: πρωτόκολλο, αναδίπλωση, κωδικοποιήσεις, λογαριασμοί, όρια, σενάρια, web
  deploy/              vosnet.service (systemd), Caddyfile
  texts/               en.json, el.json: τα κείμενα των οθονών
```

## Χτίσιμο, τεστ, τοπική εκτέλεση

Χρειάζεται το .NET 10 SDK.

```bash
dotnet build server/VosNet.sln
```

```bash
dotnet test server/VosNet.sln
```

Τα τεστ σηκώνουν όλον τον διακομιστή (web και telnet σε ελεύθερη θύρα)
με δική τους βάση σε προσωρινό φάκελο. Ο ψεύτικος πελάτης V-OS
(`tests/VosNet.Tests/TestClient.cs`) αρνείται όλες τις επιλογές, στέλνει
γραμμές έως 45 χαρακτήρες και ελέγχει ότι καμία γραμμή δεν ξεπερνά τις 48
στήλες, ότι δεν έρχεται ANSI και ότι δεν γίνεται ηχώ.

Τοπικά, χωρίς root (οι θύρες κάτω από 1024 θέλουν `CAP_NET_BIND_SERVICE`):

```bash
VOSNET__TelnetPorts=2323 VOSNET__Database=/tmp/vosnet.db dotnet run --project server/src/VosNet.Server
```

```bash
telnet 127.0.0.1 2323
```

Η διαχείριση είναι στο `http://127.0.0.1:5080/admin`. Το cookie της είναι
`Secure`· οι browsers το δέχονται στο `localhost`/`127.0.0.1` και χωρίς HTTPS.

Ο πρώτος OWNER: εγγραφή από το telnet, και μετά

```bash
VOSNET__Database=/tmp/vosnet.db dotnet server/src/VosNet.Server/bin/Debug/net10.0/VosNet.Server.dll set-owner VASILHS
```

Με τον πραγματικό TELNET μέσα στον εξομοιωτή 1984 με την M4 (Windows, από
το WSL): `make test-vosnet` στη ρίζα του repo. Χτίζει τον διακομιστή,
τον τρέχει στη θύρα 2323 με καινούργια βάση στο `build/vosnet/`, και το
σενάριο 62 συνδέει τον TELNET, διαλέγει ΕΛΛΗΝΙΚΑ και ΕΠΙΣΚΕΠΤΗΣ:
στιγμιότυπα στο `build/shots/t-*.png`. Όχι μαζί με το `make test-telnet-m4`
(η ίδια θύρα).

## Ρυθμίσεις

Στο `appsettings.json`, ενότητα `VosNet`, ή με μεταβλητές `VOSNET__…`:

| Ρύθμιση | Προεπιλογή | |
|---|---|---|
| `TelnetPorts` | `23,2323` | οι θύρες telnet· το 0 μια ελεύθερη |
| `Web` | `http://127.0.0.1:5080` | μόνο στο 127.0.0.1· το Caddy μπροστά |
| `Database` | `vosnet.db` | η βάση SQLite (WAL) |
| `Keys` | `keys` δίπλα στη βάση | τα κλειδιά του Data Protection (τα cookies) |
| `GitHubRepo` | `vaspervnp/V-OS-CPC` | από πού έρχονται τα νέα (κάθε ώρα) |
| `FetchReleases` | `true` | `false`: χωρίς GitHub |
| `HostName` | `vos.revive8bit.com` | στη βοήθεια και στη δημόσια σελίδα |
| `DetectWait` | `00:00:04` | η αναμονή για τις απαντήσεις σε DO TTYPE, DO NAWS |
| `MaxConnections`, `MaxPerIp`, `NewPerMinutePerIp` | 200, 4, 10 | τα όρια του §7 |
| `IdleWarning`, `IdleClose` | 13 και 15 λεπτά | αδράνεια |
| `ChatLines`, `ChatWindow`, `PostInterval` | 5 σε 10 δευτ., 1 λεπτό | συζήτηση, πίνακας |
| `RegistrationsPerDay`, `LoginFailuresToLock`, `LockTime` | 3, 5, 15 λεπτά | εγγραφές, κλειδώματα |
| `IpFailuresPerHour`, `RobotConnectionsPerHour` | 20, 20 | πάνω από αυτά, αποκλεισμός 24 ωρών |

## Τι διαφέρει από το DESIGN.md

- **Σύνολο χαρακτήρων**: η έξοδος προς τον V-OS είναι το σύνολο του V-OS
  (`tools/voscs.py`): ISO 8859-7 για τα ελληνικά, όπως ακριβώς (τα ίδια
  bytes, π.χ. «Καλημέρα» = `CA E1 EB E7 EC DD F1 E1`), και τα γράμματα των
  fr, es, de, it στις θέσεις που ο V-OS αφήνει ελεύθερες. Ο πίνακας 28597
  του .NET είναι του 1987 (`A1`, `A2` = `ʽ ʼ`)· του V-OS είναι του 2003
  (`‘ ’`). Το 255 (`¿` στον V-OS) δεν στέλνεται ποτέ, γιατί ο TELNET το
  πετά ως IAC.
- **Προφίλ**: στον 1984 η M4 έφερε τα WONT του V-OS μετά από 3,4
  δευτερόλεπτα, άρα η αναμονή είναι 4 δευτερόλεπτα. Αν μια απάντηση έρθει
  ακόμα αργότερα, το απλό προφίλ (ASCII) γίνεται V-OS ή UTF-8 και το
  καλωσόρισμα ξαναγράφεται.
- **TTYPE `V-OS`**: ο TELNET του V-OS από την έκδοση 0.54 (M83) απαντά
  WILL TTYPE και `IS V-OS`, και δέχεται το ECHO για τον κωδικό (δείχνει `*`).
  Τότε το προφίλ είναι V-OS από το όνομα· ο παλιός TELNET, που αρνείται
  όλες τις επιλογές, αναγνωρίζεται όπως πριν.
- **Ακροατές**: χωριστά σε IPv4 και IPv6, γιατί το WSL προωθεί στα Windows
  μόνο ό,τι ακούει σε IPv4.
- **Εντολές στο μενού**: `TERM V-OS|UTF8|ASCII`, `LANG` (η επόμενη
  γλώσσα), `PASSWORD` (αλλαγή κωδικού).
- **MODERATOR**: στη συζήτηση βλέπει τον αριθμό κάθε γραμμής, για το
  `/del <αρ.>`· στον πίνακα `D <αρ.>` σβήνει ένα μήνυμα του νήματος.
- **Πίνακας `logins`**: για τις «συνδέσεις ανά ημέρα» της επισκόπησης.

## Εγκατάσταση

Όπως το §8 του DESIGN.md, με τα αρχεία του `deploy/`.
