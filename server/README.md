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

## Εγκατάσταση σε server Debian

Για Debian 12 (bookworm) ή 13 (trixie), x86-64, με `sudo`. Ο διακομιστής
τρέχει ως ο χρήστης `vosnet` υπό το systemd, τα προγράμματα στο
`/opt/vosnet`, η βάση και τα κλειδιά στο `/var/lib/vosnet`, και το Caddy
μπροστά από το web για το HTTPS (DESIGN.md §8).

### 1. DNS

Μια εγγραφή A (και AAAA, αν ο server έχει IPv6) `vos.revive8bit.com` → η
IP του server. Στο Cloudflare: **DNS only** (γκρι σύννεφο), γιατί το
Cloudflare δεν περνά telnet.

### 2. Το runtime του .NET 10

Από το αποθετήριο της Microsoft:

```bash
wget https://packages.microsoft.com/config/debian/$(. /etc/os-release; echo $VERSION_ID)/packages-microsoft-prod.deb -O /tmp/packages-microsoft-prod.deb
```

```bash
sudo dpkg -i /tmp/packages-microsoft-prod.deb && sudo apt update && sudo apt install -y aspnetcore-runtime-10.0 sqlite3 rsync
```

```bash
dotnet --list-runtimes
```

Πρέπει να δείχνει `Microsoft.AspNetCore.App 10.0.x`. Χωρίς runtime στον
server: στο βήμα 3 `--self-contained true`, και στο `vosnet.service`
`ExecStart=/opt/vosnet/VosNet.Server`.

### 3. Χτίσιμο (στο μηχάνημα ανάπτυξης)

Στη ρίζα του repo:

```bash
dotnet publish server/src/VosNet.Server -c Release -r linux-x64 --self-contained false -o build/vosnet-pub
```

Βγαίνουν περίπου 2,6 MB: τα `.dll`, το `appsettings.json`, το `texts/` και
το `libe_sqlite3.so`. Για server ARM (π.χ. Raspberry Pi): `-r linux-arm64`.
Αντιγραφή στον server, μαζί με το `deploy/`:

```bash
rsync -av --delete build/vosnet-pub/ USER@vos.revive8bit.com:vosnet/
```

```bash
rsync -av server/deploy/ USER@vos.revive8bit.com:vosnet-deploy/
```

### 4. Χρήστης, φάκελοι, systemd

Στον server:

```bash
sudo useradd --system --home /var/lib/vosnet --shell /usr/sbin/nologin vosnet
```

```bash
sudo mkdir -p /opt/vosnet && sudo rsync -a --delete ~/vosnet/ /opt/vosnet/ && sudo chown -R root:root /opt/vosnet
```

```bash
sudo cp ~/vosnet-deploy/vosnet.service /etc/systemd/system/ && sudo systemctl daemon-reload && sudo systemctl enable --now vosnet
```

Το `/opt/vosnet` ανήκει στον root και ο `vosnet` μόνο το διαβάζει· το
systemd φτιάχνει το `/var/lib/vosnet` (`StateDirectory`) και δίνει μόνο
το δικαίωμα για τη θύρα 23 (`CAP_NET_BIND_SERVICE`), όχι root. Έλεγχος:

```bash
systemctl status vosnet
```

```bash
journalctl -u vosnet -f
```

```bash
telnet 127.0.0.1 2323
```

Άλλες ρυθμίσεις (π.χ. `VOSNET__HostName`, `VOSNET__FetchReleases`) μπαίνουν
ως `Environment=` στο `vosnet.service`, ή με
`sudo systemctl edit vosnet`, ώστε να μη χάνονται στην επόμενη ενημέρωση.

### 5. Caddy (HTTPS για τη διαχείριση)

```bash
sudo apt install -y caddy
```

```bash
sudo cp ~/vosnet-deploy/Caddyfile /etc/caddy/Caddyfile && sudo systemctl reload caddy
```

Το Caddy παίρνει μόνο του το πιστοποιητικό Let's Encrypt, όταν το DNS
δείχνει ήδη στον server και οι 80 και 443 είναι ανοιχτές. Άλλο όνομα:
αλλαγή στην πρώτη γραμμή του `Caddyfile` και `VOSNET__HostName`.

### 6. Τείχος προστασίας

Το Debian δεν έχει τείχος από μόνο του. Με το `ufw`, **πρώτα το SSH**:

```bash
sudo apt install -y ufw && sudo ufw allow OpenSSH
```

```bash
sudo ufw allow 23/tcp && sudo ufw allow 2323/tcp && sudo ufw allow 80/tcp && sudo ufw allow 443/tcp && sudo ufw enable
```

Η 5080 μένει κλειστή: ακούει μόνο στο 127.0.0.1. Η 2323 υπάρχει γιατί
αρκετοί πάροχοι κόβουν την εξερχόμενη 23· τότε στον TELNET του V-OS
γράφει κανείς `vos.revive8bit.com:2323`. Αν ο πάροχος του server έχει
δικό του firewall (Hetzner, AWS κ.λπ.), οι ίδιες θύρες και εκεί.

### 7. Ο πρώτος OWNER

Εγγραφή από το telnet (π.χ. ως `VASILHS`), και μετά στον server:

```bash
sudo -u vosnet env DOTNET_ENVIRONMENT=Production VOSNET__Database=/var/lib/vosnet/vosnet.db VOSNET__Keys=/var/lib/vosnet/keys dotnet /opt/vosnet/VosNet.Server.dll set-owner VASILHS
```

Η διαχείριση είναι στο `https://vos.revive8bit.com/admin`, με τον
λογαριασμό του telnet.

### 8. Αντίγραφα ασφαλείας

Κάθε νύχτα στις 03:30, κρατά 30 ημέρες. Το αρχείο `/etc/cron.d/vosnet`:

```
30 3 * * * root umask 077; sqlite3 /var/lib/vosnet/vosnet.db ".backup /var/backups/vosnet-$(date +\%F).db" && find /var/backups -name 'vosnet-*.db' -mtime +30 -delete
```

Το `.backup` είναι ασφαλές με τη βάση ανοιχτή (WAL). Το `umask 077`,
γιατί η βάση έχει τα hash των κωδικών. Τα κλειδιά (`/var/lib/vosnet/keys`)
αλλάζουν σπάνια· χωρίς αυτά απλώς ξαναγίνεται είσοδος στο web.
Επαναφορά: `sudo systemctl stop vosnet`, αντιγραφή του αντιγράφου ως
`/var/lib/vosnet/vosnet.db` με ιδιοκτήτη `vosnet`, και διαγραφή των
`vosnet.db-wal` και `vosnet.db-shm`, πριν από το `start`.

### 9. Ενημέρωση

Βήμα 3 στο μηχάνημα ανάπτυξης, και στον server:

```bash
sudo rsync -a --delete ~/vosnet/ /opt/vosnet/ && sudo chown -R root:root /opt/vosnet && sudo systemctl restart vosnet
```

Οι συνδεδεμένοι παίρνουν πρώτα το «Ο ΔΙΑΚΟΜΙΣΤΗΣ ΞΑΝΑΞΕΚΙΝΑ». Οι αλλαγές
της βάσης (`Storage/Migrations/*.sql`) γίνονται μόνες τους με την
εκκίνηση· καλό είναι ένα `.backup` πριν. Το runtime ενημερώνεται με το
`sudo apt upgrade` και ένα `restart`.
