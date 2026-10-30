# Τεκμηρίωση του V-OS

Το V-OS είναι γραφικό λειτουργικό σύστημα για τον Amstrad CPC 6128, γραμμένο από την αρχή σε Z80 assembly. Έχει:

- γραμμή μενού, παράθυρα που σέρνονται, διαλόγους και κουμπιά, με πληκτρολόγιο ή ποντίκι AMX
- τρεις όψεις για αρχεία και προγράμματα (Desktop, Launcher, Commander) και τις ρυθμίσεις (Setup)
- έξι γλώσσες ως plugins: αγγλικά, ελληνικά, γαλλικά, ισπανικά, γερμανικά και ιταλικά
- προγράμματα που τρέχουν δίπλα-δίπλα και συνεχίζουν όπου σταμάτησαν, ένα desk accessory και προγράμματα στο παρασκήνιο
- το Studio, έναν editor blocks τύπου Scratch που τρέχει πάνω στον ίδιο τον CPC
- ένα API με 42 κλήσεις και SDK για προγράμματα σε assembly

## Περιεχόμενα

| Κεφάλαιο | Για ποιον |
|---|---|
| [1. Ξεκίνημα](01-xekinima.md): εκκίνηση, οθόνη, πλήκτρα, ποντίκι | όλους |
| [2. Οι όψεις](02-opseis.md): Desktop, Launcher, Commander, Setup | όλους |
| [3. Προγράμματα](03-programmata.md): εκτέλεση, πολλά μαζί, accessory, παρασκήνιο, τα προγράμματα της δισκέτας | όλους |
| [4. Γλώσσες](04-glosses.md) | όλους |
| [5. Studio](05-studio.md): προγράμματα με blocks πάνω στον CPC, όλα τα blocks | όσους φτιάχνουν προγράμματα |
| [6. Blocks στον υπολογιστή](06-blocks-web.md): ο web editor και το `vbc.py` | όσους φτιάχνουν προγράμματα |
| [7. SDK](../../sdk/README.md): προγράμματα σε assembly με το API | προγραμματιστές |
| [8. Ανάπτυξη του V-OS](08-anaptyxi.md): build, δομή, δοκιμές, μνήμη | όσους δουλεύουν στο ίδιο το V-OS |

Το ίδιο υλικό υπάρχει και ως PDF, στο [`docs/V-OS.pdf`](../V-OS.pdf). Το φτιάχνει το `make docs`.

Το manual υπάρχει σε όλες τις γλώσσες του V-OS:

| Γλώσσα | Κεφάλαια | PDF |
|---|---|---|
| Ελληνικά | αυτά εδώ | [`V-OS.pdf`](../V-OS.pdf) |
| English | [en/00-index.md](en/00-index.md) | [`V-OS-en.pdf`](../V-OS-en.pdf) |
| Français | [fr/00-index.md](fr/00-index.md) | [`V-OS-fr.pdf`](../V-OS-fr.pdf) |
| Español | [es/00-index.md](es/00-index.md) | [`V-OS-es.pdf`](../V-OS-es.pdf) |
| Deutsch | [de/00-index.md](de/00-index.md) | [`V-OS-de.pdf`](../V-OS-de.pdf) |
| Italiano | [it/00-index.md](it/00-index.md) | [`V-OS-it.pdf`](../V-OS-it.pdf) |

## Άλλα κείμενα

- [`README.md`](../../README.md): η κατάσταση του έργου, milestone προς milestone, με ό,τι ελέγχθηκε σε καθένα.
- [`docs/REQUIREMENTS.md`](../REQUIREMENTS.md): οι απαιτήσεις και ο σχεδιασμός, με τις λεπτομέρειες υλοποίησης κάθε milestone.
- [`src/api/vos_api.inc`](../../src/api/vos_api.inc): το API, με όλους τους κανόνες του σε σχόλια.

> Η τεκμηρίωση αντιστοιχεί στο V-OS μέχρι και το M32. Ενημερώνεται σε κάθε milestone.
