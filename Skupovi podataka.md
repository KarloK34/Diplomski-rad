# Pregled skupova podataka za analizu hoda (Smartphone-only)

Ovaj dokument sadrži sistematizirani pregled dostupnih skupova podataka prikupljenih putem pametnih telefona, uz pripadajuće metode strojnog učenja i znanstvene radove.

---

## 📊 Brzi pregled datasetova

| Naziv dataseta | Autori | God. | Ispitanici | Primarni senzori | Freq. | Aktivnosti | Glavna primjena |
| :--- | :--- | :---: | :---: | :--- | :---: | :---: | :--- |
| **UCI HAR** | Reyes-Ortiz et al. | 2013 | 30 | Acc, Gyro | 50 Hz | 6 | HAR |
| **HAR AAL** | Davis, Owusu | 2016 | 30 | Acc, Gyro | 50 Hz | 6 | HAR / AAL |
| **WISDM v1.1** | Kwapisz et al. | 2010 | 36 | Acc | — | 6 | HAR |
| **WISDM Actitracker** | Lockhart et al. | 2011 | 563 | Acc | — | 6 | HAR / Biometrija |
| **WISDM v2.0** | G. Weiss | 2019 | 51 | Acc, Gyro | 20 Hz | 18 | HAR / Biometrija |
| **HHAR** | Blunck et al. | 2015 | 9 | Acc, Gyro | var. | 6 | HAR (hetero. uređaji) |
| **MotionSense** | Malekzadeh et al. | 2019 | 24 | Acc, Gyro | 50 Hz | 6 | HAR / Privatnost |
| **IDNet (SIGNET)** | Gadaleta, Rossi | 2016 | 50 | Acc, Gyro | — | Hod | Biometrija hoda |
| **whuGAIT** | Zou et al. | 2020 | 118 | Acc, Gyro | 50 Hz | Hod | Prepoznavanje hoda |
| **OU-ISIR Inertial Gait** | Ngo et al. | 2014 | 744 | Acc, Gyro | 100 Hz | 5 | Biometrija hoda |
| **Gait-Motion (IEEE)** | Singh et al. | 2024 | 24 | Acc, Gyro | 100 Hz | Hod (teren) | Prepoznavanje hoda |
| **Real-life HAR (UDC)** | Garcia-Gonzalez et al. | 2020 | 19 | Acc, Gyro, Mag, GPS | var. | 4 | HAR (realni uvjeti) |
| **SU-AIS BB-MAS** | Belman et al. | 2019 | 117 | Acc, Gyro, tipk., dodir | — | Hod + tipk. + kliz. | Bihevioralna biometrija |
| **FDA Open-Access Wearables** | FDA CDRH | 2024 | 20 | Acc, Gyro (iPhone + Samsung) | 100 Hz | Hod | Validacija metrika |
| **Acc+Gyro Mobile Phone (UCI 755)** | AlSahly et al. | 2022 | — | Acc, Gyro | — | 2 | Lokalizacija / HAR |
| **Figshare 390 Gait** | Abdulrahman et al. | 2025 | 390 | Acc, Gyro, Mag | 30 Hz | Hod | Biometrija hoda |
| **HAR-PMD** | Anonimni (peer review) | 2024 | 120 | 13 senzora (Acc, Gyro, Mag, Baro, Pedometer…) | — | 6 | HAR za osobe s invaliditetom |
| **WeAllWalk** | Flores, Manduchi | 2016 | 15 | Acc, Gyro, Mag (iPhone 6) | — | Hod | Navigacija / asistivne tehnologije |
| **MS Smartphone Dataset** | Gashi et al. | 2024 | 79 | Acc, Gyro (smartphone) | — | Slobodne aktivnosti | Praćenje multiple skleroze |
| **Multi-Sensor Android (ULISS)** | Grenier et al. | 2023 | — | Acc, Gyro, Mag, Baro, GPS | var. | Hod (outdoor/indoor) | Lokalizacija / HAR |
| **TOLIFE Wearables** | Zanoletti et al. | 2024 | 20 | Acc, Gyro (Samsung Galaxy A14) | — | Hod (3 brzine) | Estimacija brzine hoda |

---

## 📚 Detaljni pregled i povezani znanstveni radovi

### 1. UCI HAR — Human Activity Recognition Using Smartphones

* **Link na dataset:** https://archive.ics.uci.edu/dataset/240/human+activity+recognition+using+smartphones
* **Povezani rad:** *D. Anguita, A. Ghio, L. Oneto, X. Parra, J. L. Reyes-Ortiz: "A Public Domain Dataset for Human Activity Recognition using Smartphones"*
* **Link na rad:** https://www.esann.org/sites/default/files/proceedings/legacy/es2013-84.pdf

**Sažetak rada:**
> 30 ispitanika u dobi 19–48 godina nosilo je Samsung Galaxy S II pričvršćen na struku. Zabilježeno je 6 aktivnosti svakodnevnog života (ADL). Surovi signal obrađen je kliznim prozorima od 2,56 s s 50% preklapanjem (128 uzoraka/prozor) te Butterworth niskopropusnim filtrom za odvajanje tjelesnog od gravitacijskog ubrzanja.

**Tehnički detalji:**
* **Uređaj i položaj:** Samsung Galaxy S II, struk
* **Uzorkovana frekvencija:** 50 Hz
* **Ispitanici / uzorci:** 30 / 10.299
* **Feature Extraction:** 561 značajka iz vremenske i frekvencijske domene — *mean, std, MAD, max, min, SMA, energy, IQR, signal entropy, autoregresijski koeficijenti, kut između vektora*
* **ML Modeli:** SVM (hardware-friendly multiclass), MLP, Random Forest
* **Aktivnosti:** Hodanje, hodanje uz stube, hodanje niz stube, sjedenje, stajanje, ležanje
* **Primjena:** HAR u stvarnom vremenu, asistirano stanovanje (AAL)

---

### 2. HAR AAL — Smartphone Dataset for HAR in Ambient Assisted Living

* **Link na dataset:** https://archive.ics.uci.edu/dataset/364/smartphone+dataset+for+human+activity+recognition+har+in+ambient+assisted+living+aal
* **Povezani rad:** *K. Davis, E. Owusu: "Smartphone Dataset for Human Activity Recognition (HAR) in Ambient Assisted Living (AAL)"*

**Sažetak rada:**
> Proširenje UCI HAR dataseta s naglaskom na stariju populaciju (22–79 godina). Svaki ispitanik izvodio je 6 aktivnosti po 60 sekundi, s pametnim telefonom pričvršćenim na struku.

**Tehnički detalji:**
* **Uređaj i položaj:** Pametni telefon, struk
* **Uzorkovana frekvencija:** 50 Hz
* **Ispitanici / uzorci:** 30 / 5.744
* **Feature Extraction:** 561 značajka (identično UCI HAR)
* **ML Modeli:** Isti pristup kao UCI HAR
* **Aktivnosti:** Hodanje, hodanje uz stube, hodanje niz stube, sjedenje, stajanje, ležanje
* **Primjena:** AAL sustavi za praćenje aktivnosti starijih osoba

---

### 3. WISDM v1.1 — Activity Recognition Dataset

* **Link na dataset:** https://www.cis.fordham.edu/wisdm/dataset.php
* **Povezani rad:** *J. R. Kwapisz, G. M. Weiss, S. A. Moore: "Activity Recognition using Cell Phone Accelerometers"*
* **Objavljen u:** ACM SIGKDD Explorations Newsletter, Vol. 12(2), 2011 (prezentirano na KDD-10)

**Sažetak rada:**
> Jedan od prvih radova koji demonstrira prepoznavanje aktivnosti isključivo pomoću akcelerometra mobitela. Podaci su prikupljeni od 36 korisnika koji su mobitel nosili u džepu. Sirovi signali transformirani su u statističke značajke unutar vremenskih prozora.

**Tehnički detalji:**
* **Uređaj i položaj:** Mobitel (akcelerometar), džep
* **Ispitanici / uzorci:** 36 / 1.098.207 sirovih → 5.424 transformiranih
* **Feature Extraction:** 46 statističkih značajki — *mean, std, koeficijenti bimodalne distribucije, avg absolute diff, avg resultant acceleration, time between peaks*
* **ML Modeli:** J48 Decision Tree, MLP Neural Network, Logistic Regression
* **Aktivnosti:** Hodanje, trčanje, hodanje uz/niz stube, sjedenje, stajanje
* **Primjena:** Prepoznavanje aktivnosti na mobitelu, temelj za kasniji WISDM Actitracker

---

### 4. WISDM Actitracker

* **Link na dataset:** https://www.cis.fordham.edu/wisdm/dataset.php
* **Povezani rad:** *J. W. Lockhart, G. M. Weiss et al.: "Design Considerations for the WISDM Smart Phone-Based Sensor Mining Architecture"*
* **Objavljen u:** KDD Workshop on Knowledge Discovery in Health Informatics, 2011; AAAI Workshop, 2012

**Sažetak rada:**
> Crowdsourced dataset prikupljen putem Android aplikacije Actitracker od 563 korisnika. Zbog crowdsourcinga dataset je znatno veći od v1.1, ali uključuje i neanotirane uzorke. Istraživanje istražuje i bihevioralne biometrijske obrasce.

**Tehnički detalji:**
* **Uređaj i položaj:** Pametni telefon (akcelerometar), džep
* **Ispitanici / uzorci:** 563 / ~2.980.765 označenih sirovih uzoraka
* **Feature Extraction:** 46 statističkih značajki (isti pristup kao WISDM v1.1)
* **ML Modeli:** J48, MLP
* **Aktivnosti:** Hodanje, trčanje, hodanje uz/niz stube, sjedenje, stajanje, ležanje
* **Primjena:** HAR i biometrijska identifikacija korisnika

---

### 5. WISDM v2.0 — Smartphone and Smartwatch Activity and Biometrics Dataset

* **Link na dataset:** https://archive.ics.uci.edu/dataset/507/wisdm+smartphone+and+smartwatch+activity+and+biometrics+dataset
* **Povezani rad:** *G. M. Weiss: "WISDM Smartphone and Smartwatch Activity and Biometrics Dataset"*

**Sažetak rada:**
> Nadogradnja WISDM kolekcije s dodavanjem pametnog sata. 51 ispitanik izvodio je 18 aktivnosti po 3 minute, s uređajima na zapešću i u džepu. Dataset je namijenjen i za HAR i za bihevioralno biometrijsko modeliranje.

**Tehnički detalji:**
* **Uređaj i položaj:** Pametni telefon (džep) + pametni sat (zapešće)
* **Uzorkovana frekvencija:** 20 Hz
* **Ispitanici / uzorci:** 51 / 15.630.426
* **Feature Extraction:** Sirov signal; isporučeni i primjeri s prozorima od 10 s
* **ML Modeli:** Klizni prozori (sliding window) — pripremljeno za CNN/LSTM
* **Aktivnosti:** 18 aktivnosti (hod, trčanje, bicikl, aktivnosti s loptom, pisanje, tipkanje i dr.)
* **Primjena:** HAR i bihevioralna biometrija

---

### 6. HHAR — Heterogeneity Activity Recognition Dataset

* **Link na dataset:** https://archive.ics.uci.edu/dataset/344/heterogeneity+activity+recognition
* **Povezani rad:** *H. Blunck, S. Bhattacharya, T. S. Prentow, M. B. Kjærgaard, A. Dey: "The Heterogeneity Activity Recognition Challenge"*

**Sažetak rada:**
> Dataset je dizajniran za benchmarking HAR algoritama na heterogenim uređajima. 9 korisnika nosilo je 4 pametna sata i 8 pametnih telefona istovremeno, što rezultira razlikama u frekvencijama uzorkovanja ovisno o modelu uređaja.

**Tehnički detalji:**
* **Uređaj i položaj:** 8 pametnih telefona + 4 pametna sata, različiti položaji
* **Uzorkovana frekvencija:** Varijabilna — maksimalna moguća za svaki uređaj
* **Ispitanici / uzorci:** 9 / 43.930.257
* **Feature Extraction:** 16 sirovih značajki (acc x/y/z, gyro x/y/z, timestamp, device, model, user, gt, index)
* **ML Modeli:** Razni (dataset namijenjen benchmarkingu)
* **Aktivnosti:** Bicikliranje, sjedenje, stajanje, hodanje, penjanje uz/niz stube
* **Primjena:** Benchmarking HAR algoritama na heterogenim uređajima

---

### 7. MotionSense

* **Link na dataset:** https://github.com/mmalekzadeh/motion-sense
* **Povezani rad:** *M. Malekzadeh, R. G. Clegg, A. Cavallaro, H. Haddadi: "Mobile Sensor Data Anonymization"*
* **Objavljen u:** ACM/IEEE International Conference on Internet of Things Design and Implementation (IoTDI), 2019

**Sažetak rada:**
> Istraživanje privatnosti senzorskih podataka s pametnog telefona. Dataset pokazuje da je iz HAR signala moguće zaključiti i osjetljive biometrijske podatke (spol, identitet korisnika), što motivira potrebu za anonimizacijom podataka.

**Tehnički detalji:**
* **Uređaj i položaj:** iPhone 6s (Core Motion framework), džep hlača
* **Uzorkovana frekvencija:** 50 Hz
* **Ispitanici:** 24 (različita dob, spol, težina, visina)
* **Feature Extraction:** 12 značajki — *attitude (roll, pitch, yaw), gravity (x, y, z), rotation rate (x, y, z), user acceleration (x, y, z)*
* **ML Modeli:** CNN, LSTM, k-NN
* **Aktivnosti:** Hodanje niz/uz stube, hodanje, trčanje, sjedenje, stajanje
* **Primjena:** HAR, zaštita privatnosti senzorskih podataka, biometrijska identifikacija

---

### 8. IDNet — Smartphone-based Gait Recognition Dataset (SIGNET)

* **Link na stranicu:** https://signet.dei.unipd.it/research/human-sensing/
* **Preuzimanje dataseta:** https://signet.dei.unipd.it/wearables/IDNet_dataset.tar.gz (802 MB)
* **Povezani rad:** *M. Gadaleta, M. Rossi: "IDNet: Smartphone-based Gait Recognition with Convolutional Neural Networks"*
* **Objavljen u:** Pattern Recognition, Vol. 74, pp. 25–37, 2018

**Sažetak rada:**
> IDNet sustav koristi CNN za prepoznavanje hoda izravno iz sirovih IMU signala pametnog telefona u džepu hlača. Postiže stope pogrešne klasifikacije manje od 0,15% u manje od 5 ciklusa hoda, što ga svrstava među tada najuspješnije sustave biometrijske autentifikacije hodom.

**Tehnički detalji:**
* **Uređaj i položaj:** Pametni telefon (Acc + Gyro), prednji džep hlača
* **Ispitanici:** 50, višestruke sesije prikupljanja, različiti tereni i odjevni predmeti
* **Feature Extraction:** Sirovi signal → CNN ulaz (bez ručne ekstrakcije značajki)
* **ML Modeli:** Konvolucijska neuronska mreža (CNN)
* **Aktivnosti:** Slobodna šetnja u stvarnom okruženju
* **Primjena:** Biometrijska autentifikacija korisnika na temelju hoda

---

### 9. whuGAIT — Wuhan University Gait Dataset

* **Link na dataset:** https://github.com/qinnzou/Gait-Recognition-Using-Smartphones
* **Povezani rad:** *Q. Zou, Y. Wang, Y. Zhao, Q. Wang, Q. Li: "Deep Learning-Based Gait Recognition Using Smartphones in the Wild"*
* **Objavljen u:** IEEE Transactions on Information Forensics and Security, Vol. 15, pp. 3197–3212, 2020

**Sažetak rada:**
> Dataset prikuplja hod u "stvarnim uvjetima" (in the wild) bez restrikcija pozicije ili orijentacije telefona. Uključuje 8 podskupova za različite scenarije: identifikaciju, autentifikaciju, višednevno prikupljanje i cross-day evaluaciju.

**Tehnički detalji:**
* **Uređaj i položaj:** Pametni telefon (Acc + Gyro, 3-osni), slobodna drška
* **Uzorkovana frekvencija:** 50 Hz
* **Ispitanici:** 118 (20 s višednevnim prikupljanjem, 98 jednodnevnih)
* **Feature Extraction:** Segmentacija ciklusa hoda → deep learning ulaz
* **ML Modeli:** CNN, LSTM, GAN-based augmentacija
* **Aktivnosti:** Slobodna šetnja bez ograničenja
* **Primjena:** Prepoznavanje i autentifikacija hoda u stvarnim uvjetima

---

### 10. OU-ISIR Inertial Gait Database

* **Link na dataset:** http://www.am.sanken.osaka-u.ac.jp/BiometricDB/InertialGait.html
* **Povezani rad:** *T. T. Ngo, Y. Makihara, H. Nagahara, Y. Mukaigawa, Y. Yagi: "The largest inertial sensor-based gait database and performance evaluation of gait-based personal authentication"*
* **Objavljen u:** Pattern Recognition, Vol. 47, No. 1, pp. 228–237, 2014

**Sažetak rada:**
> U trenutku objave najveća inercijalna baza hoda na svijetu, prikupljena na javnom događaju u Tokiju. Uključuje 744 ispitanika u dobi 2–78 godina s ravnomjernom rodnom raspodjelom. Pokriva 5 vrsta terena i pruža referentne rezultate za vrednovanje biometrijskih sustava hoda.

**Tehnički detalji:**
* **Uređaj i položaj:** 3 IMU senzora + smartphone (Motorola ME860), struk / ruksak
* **Uzorkovana frekvencija:** 100 Hz
* **Ispitanici:** 744 (389 M, 355 Ž), dob 2–78 god.
* **Format podataka:** Gyro (Gx, Gy, Gz) [rad/s] + Acc (Ax, Ay, Az) [g]
* **Feature Extraction:** Wavelet transformacija, GEI (Gait Energy Image), deep značajke
* **ML Modeli:** CNN, GEI-based prepoznavanje, DTW
* **Aktivnosti:** Ravna šetnja, gore/dolje stepenice, gore/dolje nagib
* **Primjena:** Osobna autentifikacija hodom; benchmark za inercijalne biometrijske sustave

---

### 11. Gait-Motion — Smartphone Sensor-Based Gait Recognition Dataset (IEEE DataPort)

* **Link na dataset:** https://ieee-dataport.org/documents/gait-motion-smartphone-sensor-based-gait-recognition-dataset
* **Povezani rad:** *S. Singh, N. A. Choudhury, B. Soni: "An Efficient Ensemble Framework for Human Gait Recognition Using CNN-LSTM With Extra Tree Classifier and Smartphone Sensors in Real-World Environment"*
* **Objavljen u:** IEEE Sensors Letters, 2024. DOI: https://doi.org/10.1109/LSENS.2024.3435719

**Sažetak rada:**
> Tri Android pametna telefona montirana u prednjem džepu koristila su se za prikupljanje hoda po raznolikim terenima. Ensemble pristup kombinira CNN-LSTM s Extra Tree klasifikatorom za robusno prepoznavanje hoda.

**Tehnički detalji:**
* **Uređaj i položaj:** 3 Android pametna telefona, prednji džep (vertikalna orijentacija)
* **Uzorkovana frekvencija:** 100 Hz
* **Ispitanici:** 24 (14 žena, 10 muškaraca, svi stariji od 18 god., min. 50 kg)
* **Feature Extraction:** Segmentacija signala hoda, surovi signali za CNN-LSTM ulaz
* **ML Modeli:** CNN-LSTM + Extra Tree Classifier (ensemble)
* **Aktivnosti:** Hod po ravnoj podlozi, nagnutom terenu (gore i dolje), 3 minute po ispitaniku
* **Primjena:** Prepoznavanje hoda u stvarnom okruženju s više uređaja

---

### 12. Real-life HAR Dataset (UDC)

* **Link na dataset:** https://lbd.udc.es/research/real-life-HAR-dataset/
* **Povezani rad:** *D. Garcia-Gonzalez, D. Rivero, E. Fernandez-Blanco, M. R. Luaces: "A Public Domain Dataset for Real-life Human Activity Recognition Using Smartphone Sensors"*
* **Objavljen u:** Sensors (MDPI), 2020

**Sažetak rada:**
> Dataset prikuplja podatke u nekontroliranim, stvarnim uvjetima — bez fiksne orijentacije ili pozicije telefona. Ispitanici su koristili vlastite Android uređaje s varijabilnom frekvencijom uzorkovanja, što odražava stvarne uvjete uporabe mobilnih aplikacija.

**Tehnički detalji:**
* **Uređaj i položaj:** Osobni Android pametni telefon, slobodna pozicija i orijentacija
* **Uzorkovana frekvencija:** Varijabilna (ovisno o uređaju, Android OS)
* **Ispitanici:** 19
* **Senzori:** Akcelerometar, žiroskop, magnetometar, GPS
* **Feature Extraction:** Više verzija podataka (sirovi, očišćeni, prilagođeni, s ekstrahiranim značajkama)
* **Aktivnosti:** Neaktivno, aktivno, hodanje, vožnja
* **Primjena:** HAR u stvarnim uvjetima bez eksperimentalnih restrikcija

---

### 13. SU-AIS BB-MAS — Behavioral Biometrics Multi-device and Multi-Activity Dataset

* **Link na dataset:** https://ieee-dataport.org/open-access/su-ais-bb-mas-syracuse-university-and-assured-information-security-behavioral
* **Povezani rad:** *A. K. Belman, V. V. Phoha: "Leveraging Phone-based Behavioral Biometrics for Gait and Biometric Authentication"*
* **Objavljen u:** ACM Transactions on Privacy and Security, Vol. 23(1), Article 4, 2020; arXiv:1912.02736

**Sažetak rada:**
> Višemodalni dataset koji obuhvaća biometrijske podatke s više uređaja (mobitela, tableta, stolnog računala). Posebnost je kombinacija modaliteta: hod (Acc + Gyro), tipkanje (keystroke dynamics) i klizanje (swipe dynamics), što omogućuje istraživanje višemodalne kontinuirane autentifikacije.

**Tehnički detalji:**
* **Uređaj i položaj:** Pametni telefon (u ruci i u džepu), tablet (u ruci), stolno računalo
* **Ispitanici:** 117
* **Ukupni uzorci:** 57,1M acc + 57,1M gyro + 3,5M tipkovnička + 1,7M swipe
* **Aktivnosti:** Hod (ravno, uz/niz stube), tipkanje slobodnog i zadanog teksta, klizanje
* **Feature Extraction:** Sirovi signali + statistički prozori za svaki modalitet
* **Primjena:** Višemodalna bihevioralna biometrija i kontinuirana autentifikacija korisnika

---

### 14. FDA Open-Access Wearables Dataset

* **Link na stranicu:** https://cdrh-rst.fda.gov/open-access-wearables-dataset-evaluate-factors-impacting-accuracy-smartphone-gait-metrics
* **Preuzimanje dataseta:** https://www.synapse.org/#!Synapse:syn51664250
* **Objavio:** U.S. Food and Drug Administration — Center for Devices and Radiological Health (FDA CDRH), 2024

**Sažetak:**
> Dataset prikupljen s ciljem procjene faktora koji utječu na točnost metrika hoda izmjerenih pametnim telefonima. Koristi iPhone 10 i Samsung Galaxy S22 kao test uređaje, a referentni signal dolazi od kliničkih IMU senzora (Xsens) i tlačnog poda (Zeno Walkway). Svrha je regulatorna validacija nosljivih medicinskih uređaja.

**Tehnički detalji:**
* **Uređaji i položaji:** iPhone 10 + Samsung Galaxy S22 (donji dio leđa i desno bedro); 2× Xsens MTw Awinda (referenca); Zeno Walkway (referentni pritisni pod)
* **Uzorkovana frekvencija:** 100 Hz (IMU senzori i Zeno Walkway)
* **Ispitanici / pokusi:** 20 zdravih ispitanika / 374 pokusa (od 400 planiranih)
* **Aktivnosti:** Hod u ravnoj liniji i zakrivljenim putanjama, različite pozicije i orijentacije telefona
* **Primjena:** Regulatorna validacija točnosti metrika hoda pametnih telefona za medicinsku primjenu

---

### 15. Accelerometer + Gyro Mobile Phone Dataset (UCI 755)

* **Link na dataset:** https://archive.ics.uci.edu/dataset/755/accelerometer+gyro+mobile+phone+dataset
* **Povezani rad:** *A. AlSahly, M. Hassan, K. Saleem, A. Alabrah, J. Rodrigues: "Handheld Device-Based Indoor Localization with Zero Infrastructure (HDIZI)"*
* **Objavljen u:** Sensors (Basel), 2022. DOI: https://doi.org/10.3390/s22176513

**Sažetak rada:**
> Dataset prikupljen za istraživanje indoor lokalizacije bez infrastrukture koristeći isključivo IMU senzore pametnog telefona. Uključuje 2 aktivnosti (stajanje i hodanje) i 8 sirovih značajki, bez nedostajućih vrijednosti.

**Tehnički detalji:**
* **Uređaj i položaj:** Pametni telefon (Acc + Gyro), u ruci
* **Uzorci / značajke:** 31.991 / 8 (accX, accY, accZ, gyroX, gyroY, gyroZ, timestamp, Activity)
* **Licenca:** Creative Commons Attribution 4.0 International
* **Feature Extraction:** Sirovi signali
* **Aktivnosti:** Stajanje, hodanje
* **Primjena:** Indoor lokalizacija bez infrastrukture, detekcija aktivnosti

---

### 16. Smartphone-Based Gait Recognition Dataset — 390 Participants (Figshare)

* **Link na dataset:** https://figshare.com/articles/dataset/30597743
* **Povezani rad:** *L. S. Abdulrahman, A. T. Sabir, H. S. Maghdid: "A biometric dataset for unconditioned gait identification using onboard smartphone sensors"*
* **Objavljen u:** Frontiers in Computer Science, 2026. DOI: https://doi.org/10.3389/fcomp.2026.1752141

**Sažetak rada:**
> Jedan od najvećih javno dostupnih skupova podataka za biometrijsku identifikaciju hodom pametnim telefonom. Naglasak je na nekontroliranim uvjetima: ispitanici su sami držali telefon u dominantnoj ruci bez propisane orijentacije. Dataset je prikupljan na Sveučilištu Koya (Irak) od rujna 2024. do siječnja 2025.

**Tehnički detalji:**
* **Uređaj i položaj:** Samsung Galaxy A53, slobodna drška u dominantnoj ruci (bez fiksne orijentacije)
* **Uzorkovana frekvencija:** 30 Hz
* **Ispitanici / pokusi:** 390 (61% M, 39% Ž, 18–51 god.) / 3.900 (10 pokusa × 390 ispitanika)
* **Senzori:** Akcelerometar (3-osni), žiroskop (3-osni), magnetometar (3-osni)
* **Ukupna prijeđena udaljenost:** 46,8 km (svi ispitanici zajedno)
* **Hodna staza:** 12 m, ravna podloga, vlastiti tempo
* **Feature Extraction:** ~250–400 vremenskih uzoraka po osi po pokusu
* **Primjena:** Biometrijska identifikacija hodom u nekontroliranim, realnim uvjetima; kontinuirana autentifikacija, detekcija padova, praćenje pokretljivosti

---

### 17. HAR-PMD — Human Activity Recognition Dataset for Pedestrians with Mobility Disabilities

* **Link na dataset:** https://zenodo.org/records/7939223
* **Autori:** Anonimni (u tijeku recenzija za Scientific Data)
* **Verzija:** v2, objavljeno rujna 2024.
* **Licenca:** Creative Commons Attribution 4.0 International (CC BY 4.0)

**Sažetak:**
> Dataset posebno dizajniran za prepoznavanje aktivnosti osoba s poteškoćama kretanja. 120 sudionika podijeljeno je u dvije grupe: 60 nosi isključivo pametni telefon, a 60 telefon i pametni sat. Obuhvaća 6 aktivnosti pješaka, uključujući kretanje s pomagalima za hod i invalidskim kolicima, u unutarnjim i vanjskim okolinama. Ukupno 14.400 minuta mjerenja.

**Tehnički detalji:**
* **Uređaj i položaj:** Android pametni telefon (13 senzora) + pametni sat (5 senzora, podskup ispitanika)
* **Ispitanici / ukupno trajanje:** 120 / 14.400 minuta
* **Senzori pametnog telefona:** Linearno ubrzanje, žiroskop, magnetometar, gravitacija, vektor rotacije, barometar, brojač koraka i dr. (ukupno 13 senzora)
* **Format podataka:** CSV, strukturirano po osobi / aktivnosti / okolini
* **Aktivnosti:** Mirovanje, hodanje (indoor), hodanje (outdoor), hodanje s štakama/hodalicama, ručna invalidska kolica, električna invalidska kolica
* **Primjena:** HAR za osobe s invaliditetom, adaptivna asistivna tehnologija, praćenje pokretljivosti

---

### 18. WeAllWalk — Annotated Inertial Sensor Time Series from Blind Walkers

* **Link na dataset:** https://datadryad.org/stash/dataset/doi:10.7291/D17P46
* **Povezani rad:** *G. Flores, R. Manduchi: "WeAllWalk: An Annotated Data Set of Inertial Sensor Time Series from Blind Walkers"*
* **Objavljen u:** Proceedings of the 18th International ACM SIGACCESS Conference on Computers and Accessibility (ASSETS 2016), pp. 141–150, Reno, NV, SAD

**Sažetak rada:**
> Dataset prikuplja podatke inercijalnih senzora od slijepih sudionika koji hodaju unaprijed određenim rutama kroz dva objekta kampusa UCSC. 10 slijepih sudionika (7 s bijelim štapom, 1 s vodičem psom, 2 izmjenično) i 5 videćih. Podaci s iPhonea 6 (Acc, Gyro, Mag) dostupni su odvojeno od MetaWear CPRO senzora.

**Tehnički detalji:**
* **Uređaj i položaj:** iPhone 6 (triaksijalni Acc, Gyro, Mag) + MetaWear CPRO (Acc, Gyro) — 2 uređaja po ispitaniku
* **Ispitanici:** 15 (10 slijepih + 5 videćih)
* **Anotacija:** Po lokaciji i aktivnosti (ravni hodnici, okretaji, prolaz kroz vrata, prepreke)
* **Okoline:** 2 objekta kampusa UCSC, unutarnji prostori
* **Feature Extraction:** Vremenski nizi sirovih IMU signala
* **Primjena:** Asistivna navigacija za slijepe i slabovidne osobe, indoor lokalizacija, analiza hoda u stvarnim uvjetima

---

### 19. MS Smartphone Dataset — Modeling Multiple Sclerosis using Mobile and Wearable Sensor Data

* **Link na dataset:** https://zenodo.org/records/10497826
* **Link na rad:** https://doi.org/10.1038/s41746-024-01025-8
* **Povezani rad:** *S. Gashi, P. Oldrati, M. Moebus et al.: "Modeling multiple sclerosis using mobile and wearable sensor data"*
* **Objavljen u:** npj Digital Medicine, Vol. 7, Article 64, 2024

**Sažetak rada:**
> Dugoročna studija praćenja osoba s multiplom sklerozom (MS) i zdravih kontrola u prirodnim uvjetima. Podaci s pametnog telefona (Acc, Gyro) odvojeni su od podataka nosivog senzora (Everion pametna narukvica). Prikupljano 2 tjedna po ispitaniku, ukupno 489 dana podataka o slobodnim životnim aktivnostima. Cilj je modeliranje simptoma MS-a i praćenje napredovanja bolesti.

**Tehnički detalji:**
* **Uređaj i položaj:** Osobni pametni telefon (Acc, Gyro) + Everion pametna narukvica (Biofurmis)
* **Ispitanici:** 79 (55 MS pacijenata + 24 zdrave kontrole)
* **Trajanje studije:** 2 tjedna po ispitaniku; ukupno 489 dana prikupljanja
* **Aktivnosti / uvjeti:** Slobodne životne aktivnosti u prirodnom okruženju (naturalistic)
* **Feature Extraction:** Aktivnost, zaključavanje ekrana, mobilnost — sirovi i agregirani signali
* **Primjena:** Praćenje neuroloških bolesti pametnim telefonom, dugoročno praćenje pokretljivosti, digitalni biomarkeri

---

### 20. Multi-Sensor Dataset — Android Smart Devices and ULISS (Outdoor & Indoor)

* **Link na dataset:** https://zenodo.org/records/8340005
* **Povezani rad:** *A. Grenier, E. S. Lohan, A. Ometov, J. Nurmi: "Towards Smarter Positioning through Analyzing Raw GNSS and Multi-Sensor Data from Android Devices: A Dataset and an Open-Source Application"*
* **Objavljen u:** Electronics (MDPI), Vol. 12(23), 4781, 2023. DOI: https://doi.org/10.3390/electronics12234781
* **Licenca:** Creative Commons Attribution 4.0 International (CC BY 4.0)

**Sažetak rada:**
> Dataset prikuplja IMU, GNSS i barometarske podatke Android pametnih telefona u višestrukim okolinama otvorenog i zatvorenog prostora. Podaci su prikupljeni prilagođenom Android aplikacijom "Mimir" koja omogućuje kontrolu frekvencije uzorkovanja. Posebna pažnja posvećena je načinu nošenja telefona (tipkanje, ljuljanje, džep) i podaci su odvojeni od pametnog sata.

**Tehnički detalji:**
* **Uređaj i položaj:** Android pametni telefon, više načina nošenja (džep, ljuljanje, tipkanje) + pametni sat (odvojene datoteke)
* **Uzorkovana frekvencija:** Varijabilna, kontrolirana aplikacijom
* **Veličina dataseta:** ~670,5 MB
* **Senzori:** Akcelerometar, žiroskop, magnetometar, barometar, brojač koraka, GNSS/GPS
* **Okoline:** Otvoreni prostor, urbani kanjon, lagani indoor, duboki indoor
* **Alat za prikupljanje:** Android aplikacija "Mimir" (open-source)
* **Primjena:** Indoor/outdoor lokalizacija, PDR (Pedestrian Dead Reckoning), HAR, analiza utjecaja položaja nošenja telefona

---

### 21. TOLIFE Wearables — Gait Speed Dataset (Samsung Galaxy A14)

* **Link na dataset:** https://zenodo.org/records/11091279
* **Povezani rad:** *M. Zanoletti et al.: "Combining Different Wearable Devices to Assess Gait Speed in Real-World Settings"*
* **Objavljen u:** Sensors (MDPI), Vol. 24(10), 3205, 2024. DOI: https://doi.org/10.3390/s24103205
* **Kontekst:** EU Horizon projekt TOLIFE (praćenje COPD pacijenata)

**Sažetak rada:**
> Dataset koji direktno cilja estimaciju brzine hoda isključivo sa pametnim telefonom u džepu, uz zlatni standard iz Xsens AWINDA sustava. 20 zdravih ispitanika izvodilo je modificirani šestominutni test hoda (6MWT) na tri brzine (spora, srednja, brza). Datoteke su odvojene po uređaju (telefon, sat, cipele), što olakšava izoliranu analizu telefona.

**Tehnički detalji:**
* **Uređaj i položaj:** Samsung Galaxy A14, lijevi prednji džep
* **Referentni sustav:** Xsens AWINDA (17 bežičnih IMU senzora) — zlatni standard
* **Ostali uređaji:** Samsung Galaxy Watch 5 (zapešće), pametne cipele s IMU i tlačnim senzorima
* **Ispitanici:** 20 zdravih (11 ž, 9 m, prosječna dob 27,6 god.)
* **Protokol:** Modificirani 6MWT na tri brzine hoda
* **Senzori telefona:** Akcelerometar, žiroskop, senzori orijentacije
* **Datoteke:** Odvojene po uređaju (phone / watch / shoes) — CSV format
* **Primjena:** Estimacija brzine hoda u stvarnim uvjetima, COPD praćenje, validacija pametnog telefona kao medicinskog uređaja za analizu hoda
