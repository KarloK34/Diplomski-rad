# Prijedlog skupova podataka za diplomski rad

## Dataset 1 — MotionSense

**Puni naziv:** MotionSense Dataset for Human Activity and Attribute Recognition
**Autori:** Malekzadeh et al., Imperial College London
**Objavljeno:** ACM/IEEE IoTDI, 2019.
**Dataset:** https://github.com/mmalekzadeh/motion-sense (slobodan pristup, odmah dostupan)

### Tehničke karakteristike

| Parametar               | Vrijednost                                                     |
| ----------------------- | -------------------------------------------------------------- |
| Ispitanici              | 24 (različita dob, spol, težina, visina)                       |
| Frekvencija uzorkovanja | 50 Hz                                                          |
| Uređaj i pozicija       | iPhone 6s, prednji džep hlača                                  |
| Senzori                 | Acc + Gyro (attitude, gravity, userAcceleration, rotationRate) |
| Format                  | CSV, Python primjeri dostupni na GitHubu                       |

### Aktivnosti (6 klasa)

`walking` · `jogging` · `stairs_up` · `stairs_down` · `sitting` · `standing`

### Primjena

Klasifikacija aktivnosti (HAR). Originalni rad fokusiran je na zaštitu privatnosti senzorskih podataka, ne na ML analizu — što ostavlja prostor za doprinos kroz sustavnu usporedbu modela i optimizaciju parametara.

### Prednosti

- Slobodan pristup bez registracije, odmah spreman za upotrebu
- Dobro citiran dataset s bogatom literaturom za usporedbu rezultata
- Demografski podaci ispitanika dostupni (spol, dob, visina, težina)
- Metodološki jednostavan klasifikacijski problem

### Ograničenja

- Samo 24 ispitanika — manji dataset, ograničenija generalizabilnost
- Fiksna pozicija telefona (džep) — bez varijabilnosti uvjeta nošenja
- Tema HAR klasifikacije relativno istražena u literaturi

### Moguća aplikacijska priča

Aplikacija koja klasificira aktivnost korisnika u stvarnom vremenu (hoda / trči / sjedi / stoji / stube) s longitudinalnim praćenjem dnevnih aktivnosti.

---

## Dataset 2 — whuGAIT

**Puni naziv:** Deep Learning-Based Gait Recognition Using Smartphones in the Wild
**Autori:** Zou et al., Wuhan University
**Objavljeno:** IEEE Transactions on Information Forensics and Security, vol. 15, 2020.
**Dataset:** https://github.com/qinnzou/Gait-Recognition-Using-Smartphones (Google Drive)

### Tehničke karakteristike

| Parametar               | Vrijednost                                               |
| ----------------------- | -------------------------------------------------------- |
| Ispitanici              | 118 (20 s višednevnim prikupljanjem)                     |
| Frekvencija uzorkovanja | 50 Hz                                                    |
| Uređaj i pozicija       | Pametni telefon, slobodna drška                          |
| Senzori                 | Acc + Gyro (3-osni)                                      |
| Podskupovi              | 8 gotovih podskupova za različite evaluacijske scenarije |

### Zadatak

**Biometrijska identifikacija i autentifikacija osoba po hodu** — prepoznavanje _tko_ hoda na temelju individualnih karakteristika hodnog obrasca.

### Primjena

Originalni rad predlaže CNN+LSTM hibridnu arhitekturu s referentnim rezultatima (>93,5% točnosti identifikacije). Višednevno prikupljanje za 20 ispitanika omogućuje cross-day evaluaciju.

### Prednosti

- "In the wild" uvjeti — bez ograničenja pozicije uređaja
- Velik i dobro strukturiran dataset s 8 gotovih podskupova
- Atraktivna aplikacijska priča: pasivna biometrijska autentifikacija korisnika
- Referentni rezultati i kod dostupni za usporedbu

### Ograničenja

- Biometrijska identifikacija zahtjevniji ML problem od HAR klasifikacije — standardna višeklasna klasifikacija nije dovoljna za otvoreni skup korisnika; zahtijeva metric learning pristupe (Siamese mreže, triplet loss) i drugačije evaluacijske metrike (FAR, FRR, EER)
- Problem se može pojednostaviti na zatvoreni skup korisnika (5–10 osoba), što ga svodi na standardnu klasifikaciju, ali time se mijenja priroda aplikacije

### Moguća aplikacijska priča

Aplikacija koja korisnika prepoznaje po hodu — "hod kao lozinka" ili personalizacija sadržaja bez eksplicitne prijave.

---

## Dataset 3 — HAR-PMD

**Puni naziv:** Human Activity Recognition Dataset for Pedestrians with Mobility Disabilities
**Autori:** Woo, Hwang et al., Hanyang University, South Korea
**Objavljeno:** _Scientific Data_, vol. 13, br. 211, 2026.
**DOI rada:** https://doi.org/10.1038/s41597-025-06527-y
**Dataset:** https://doi.org/10.5281/zenodo.7939223 (CC BY 4.0, 7,3 GB)

### Tehničke karakteristike

| Parametar               | Vrijednost                                                                                                                                 |
| ----------------------- | ------------------------------------------------------------------------------------------------------------------------------------------ |
| Ispitanici              | 120                                                                                                                                        |
| Frekvencija uzorkovanja | ~60 Hz (stvarna ~59,6 Hz)                                                                                                                  |
| Uređaj i pozicija       | Android 9.0+, slobodan odabir ispitanika (ruka, džep, torba)                                                                               |
| Senzori                 | 13 senzora: linearni acc, žiroskop, magnetometar, gravitacija, orijentacija, barometar, rotacijski vektori, koraci, svjetlost, proksimitet |
| Format                  | CSV, 32 stupca, 1.440 datoteka ukupno                                                                                                      |
| Okoline                 | Indoor + outdoor (zasebne datoteke)                                                                                                        |

### Aktivnosti (6 klasa)

`still` · `walking` · `crutches` · `walker` · `manual_wheelchair` · `electric_wheelchair`

### ML benchmark u originalnom radu

Autori su usporedili 8 modela (DT, RF, XGBoost, SVM, MLP, CNN, LSTM, Transformer) uz user-dependent i user-independent evaluaciju. Postignuta točnost: **99,64%** (random) i **98,79%** (user-independent).

### Primjena

Klasifikacija vrste kretanja osoba s pomagalima i bez njih. Jedini javno dostupni dataset koji pokriva ovu populaciju. Indoor/outdoor podjela omogućuje analizu utjecaja okoline na točnost.

### Prednosti

- Originalna i medicinski relevantna tema s bogatom teorijskom podlogom
- Slobodna pozicija telefona — blisko realnoj upotrebi Flutter aplikacije
- Bogat skup senzora; za ML dovoljno acc+gyro+mag (sve dostupno u Flutteru)
- Detaljna metodološka dokumentacija u recenziranom radu (Scientific Data, Nature portfolio)
- Prostor za doprinos dobro definiran: optimizacija prozora, analiza senzorskih kombinacija, indoor/outdoor analiza

### Ograničenja

- Dataset prikupljen od zdravih ispitanika koji **simuliraju** kretanje s pomagalima (autori to sami navode kao ograničenje)
- Pozicija telefona nije zapisana unutar CSV datoteka — nije dostupna za analizu njezina utjecaja
- Live testiranje svih 6 klasa u aplikaciji zahtijeva pristup opremi (štake, hodalica, invalidska kolica)

### Moguća aplikacijska priča

Aplikacija koja klasificira vrstu kretanja u stvarnom vremenu za praćenje mobilnosti i rehabilitaciju. Uža ciljana skupina korisnika u usporedbi s općim HAR ili biometrijskim rješenjima.

---

## Usporedna tablica

| Kriterij                         |    MotionSense    |           whuGAIT           |      HAR-PMD      |
| -------------------------------- | :---------------: | :-------------------------: | :---------------: |
| Broj ispitanika                  |        24         |             118             |        120        |
| Slobodna pozicija telefona       |     ❌ (džep)     |             ✅              |        ✅         |
| Sirovi IMU signali               |        ✅         |             ✅              |        ✅         |
| Dostupnost                       |      GitHub       |        Google Drive         |  Zenodo (CC BY)   |
| Vrsta ML zadatka                 | HAR klasifikacija | Biometrijska identifikacija | HAR klasifikacija |
| ML zahtjevnost                   |       niska       |           visoka            |     umjerena      |
| Originalnost teme                |      srednja      |           visoka            |      visoka       |
| Literatura za usporedbu          |      bogata       |          dostupna           |    ograničena     |
| Medicinska relevantnost          |      srednja      |           srednja           |      visoka       |
| Testiranje aplikacije bez opreme |    ✅ potpuno     |         ✅ potpuno          |   ⚠️ djelomično   |
