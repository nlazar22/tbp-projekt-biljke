# 🌱 Moje Biljke

> **Pametni sustav za održavanje sobnog bilja pokretan Aktivnim i Temporalnim bazama podataka.**

[![PostgreSQL](https://img.shields.io/badge/PostgreSQL-18-336791?style=flat&logo=postgresql)](https://www.postgresql.org/)
[![Python](https://img.shields.io/badge/Python-3.10+-3776AB?style=flat&logo=python)](https://www.python.org/)
[![Streamlit](https://img.shields.io/badge/Streamlit-App-FF4B4B?style=flat&logo=streamlit)](https://streamlit.io/)
[![VS Code](https://img.shields.io/badge/Editor-VS%20Code-007ACC?style=flat&logo=visualstudiocode)](https://code.visualstudio.com/)
[![License](https://img.shields.io/badge/License-GPL%203.0-blue.svg)](./LICENSE)

## 📖 O Projektu

**Moje Biljke** nije samo obična aplikacija za vođenje evidencije. Ovo je sustav koji koristi napredne paradigme inženjerstva baza podataka kako bi **aktivno** brinuo o vašim biljkama.

Umjesto da korisnik sam računa kada treba zaliti biljku, **baza podataka to radi sama**. Sustav koristi triggere, pohranjene procedure i temporalne tipove podataka kako bi automatizirao brigu i omogućio analizu povijesnih uvjeta.

## ✨ Ključne Funkcionalnosti

### 🧠 Pametna Baza (Backend)
* **Aktivna Baza Podataka (ECA pravila):** SQL triggeri automatski kreiraju podsjetnike za zalijevanje, gnojenje i presađivanje na temelju unesenih događaja.
* **IoT Simulacija & Alarmi:** Unosom temperature i vlage (simulacija senzora), baza automatski provjerava idealne uvjete za specifičnu vrstu i aktivira alarm ako su uvjeti opasni.
* **Temporalni podaci:** Korištenje `TSTZRANGE` tipa podataka za precizno praćenje povijesti mikroklimatskih uvjeta bez gubitka podataka.

### 🖥️ Korisničko Sučelje (Frontend)
* **Streamlit Dashboard:** Pregledna nadzorna ploča s aktivnim zadacima.
* **Interaktivni Grafovi:** Vizualizacija kretanja temperature i vlage kroz vrijeme.
* **QR Kod Generator:** Generiranje naljepnica koje vode na savjete za njegu specifične vrste.
* **CSV Izvoz:** Mogućnost preuzimanja podataka za daljnju analizu.

## 🛠️ Tehnologije

* **Baza podataka:** PostgreSQL 18 (PL/pgSQL, Triggers, Views)
* **Backend/Frontend:** Python, Streamlit
* **Editor:** Visual Studio Code (VS Code)
* **Biblioteke:** `sqlalchemy`, `pandas`, `psycopg2`, `qrcode`

## 💻 Razvojno Okruženje (VS Code)

Projekt je u potpunosti razvijan i testiran unutar **Visual Studio Code** editora. Struktura projekta prilagođena je za rad s VS Code integriranim terminalom.

Za najbolje iskustvo:
1. Otvorite glavnu mapu projekta u **VS Code-u**.
2. Koristite integrirani terminal (`Ctrl` + `` ` ``) za aktivaciju okruženja i pokretanje servera.

## 🚀 Instalacija i Pokretanje

### 1. Priprema Baze Podataka
Prvo je potrebno kreirati praznu bazu podataka (npr. `biljke_db`) na vašem PostgreSQL serveru. Nakon toga, tablice i funkcije možete kreirati na jedan od dva načina:

**Opcija A: Putem SQL Editora (Preporučeno za pgAdmin)**
1. Otvorite datoteku `baza_struktura.sql` u bilo kojem tekstualnom editoru.
2. Kopirajte **cijeli sadržaj** datoteke.
3. Otvorite svoj SQL alat (npr. **pgAdmin 4**, DBeaver).
4. Desni klik na vašu novu bazu -> **Query Tool**.
5. Zalijepite kod i pritisnite **Execute** (Run).

**Opcija B: Putem terminala**
Ako preferirate komandnu liniju:
```sql
psql -U postgres -d biljke_db -f baza_struktura.sql

---
*Created by Nikola Lazar, 2026.*
