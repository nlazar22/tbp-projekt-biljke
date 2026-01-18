-- =============================================
-- 1. KREIRANJE TABLICA 
-- =============================================

CREATE TABLE vrste (
    id SERIAL PRIMARY KEY,
    naziv VARCHAR(100) NOT NULL,
    latinski_naziv VARCHAR(100),
    interval_zalijevanja_dani INTEGER NOT NULL, 
    idealna_temperatura_min INTEGER,
    idealna_temperatura_max INTEGER,
    interval_gnojenja_dani INT DEFAULT 30,
    interval_presadivanja_dani INT DEFAULT 365
);

CREATE TABLE biljke (
    id SERIAL PRIMARY KEY,
    vrsta_id INTEGER REFERENCES vrste(id),
    nadimak VARCHAR(50) NOT NULL, 
    datum_sadnje DATE DEFAULT CURRENT_DATE,
    slika_url TEXT 
);

CREATE TABLE povijest_stanja (
    id SERIAL PRIMARY KEY,
    biljka_id INTEGER REFERENCES biljke(id) ON DELETE CASCADE,
    lokacija VARCHAR(100), 
    temperatura DECIMAL(4,1),
    vlaga_zraka INTEGER,
    period_vazenja TSTZRANGE NOT NULL 
);

CREATE TABLE dogadaji (
    id SERIAL PRIMARY KEY,
    biljka_id INTEGER REFERENCES biljke(id) ON DELETE CASCADE,
    tip_dogadaja VARCHAR(20) CHECK (tip_dogadaja IN ('Zalijevanje', 'Gnojenje', 'Presađivanje')),
    datum_vrijeme TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    napomena TEXT
);

CREATE TABLE podsjetnici (
    id SERIAL PRIMARY KEY,
    biljka_id INTEGER REFERENCES biljke(id) ON DELETE CASCADE,
    poruka VARCHAR(200),
    datum_podsjetnika DATE,
    rijeseno BOOLEAN DEFAULT FALSE
);

-- Optimizacija pretraživanja događaja po biljci (za brzi JOIN)
CREATE INDEX idx_dogadaji_biljka_id ON dogadaji(biljka_id);

-- Optimizacija pretraživanja podsjetnika po datumu (za brzi dohvat onoga što je danas hitno)
CREATE INDEX idx_podsjetnici_datum ON podsjetnici(datum_podsjetnika);

-- Optimizacija povijesti stanja (jer će tu biti najviše zapisa)
CREATE INDEX idx_povijest_biljka_id ON povijest_stanja(biljka_id);

-- =============================================
-- 2. POGLEDI 
-- =============================================

--Pregled statusa biljaka s nadolazećim podsjetnicima
CREATE OR REPLACE VIEW pregled_statusa_biljaka AS
SELECT b.id AS biljka_id,
    b.nadimak,
    v.naziv AS vrsta,
    b.slika_url AS slika_biljke,
    p.datum_podsjetnika AS iduce_zalijevanje,
    p.poruka
   FROM biljke b
     JOIN vrste v ON b.vrsta_id = v.id
     LEFT JOIN podsjetnici p ON b.id = p.biljka_id
WHERE p.rijeseno = false OR p.id IS NULL;

--Statistika brige o biljkama
CREATE OR REPLACE VIEW statistika_brige_o_biljkama AS
SELECT b.nadimak,
    v.naziv AS vrsta,
    count(d.id) AS ukupno_dogadaja,
    max(d.datum_vrijeme) AS zadnja_aktivnost
   FROM biljke b
     JOIN vrste v ON b.vrsta_id = v.id
     LEFT JOIN dogadaji d ON b.id = d.biljka_id
GROUP BY b.id, b.nadimak, v.naziv;
  
-- =============================================
-- 3. AUTOMATSKI PODSJETNIK (Zalijevanje, Gnojenje, Presađivanje)
-- =============================================

CREATE OR REPLACE FUNCTION generiraj_iduci_podsjetnik() RETURNS TRIGGER AS $$
DECLARE
    v_interval INT;
    v_poruka TEXT;
    v_nadimak_biljke TEXT;
BEGIN
    SELECT nadimak INTO v_nadimak_biljke FROM biljke WHERE id = NEW.biljka_id;

    IF NEW.tip_dogadaja = 'Zalijevanje' THEN
        SELECT interval_zalijevanja_dani INTO v_interval 
        FROM vrste v JOIN biljke b ON b.vrsta_id = v.id WHERE b.id = NEW.biljka_id;
        
        v_poruka := 'Vrijeme je za zalijevanje: ' || v_nadimak_biljke;
        
        INSERT INTO podsjetnici (biljka_id, poruka, datum_podsjetnika, rijeseno)
        VALUES (NEW.biljka_id, v_poruka, CURRENT_DATE + v_interval, FALSE);

    ELSIF NEW.tip_dogadaja = 'Gnojenje' THEN
        SELECT interval_gnojenja_dani INTO v_interval 
        FROM vrste v JOIN biljke b ON b.vrsta_id = v.id WHERE b.id = NEW.biljka_id;

        v_poruka := 'Dodaj gnojivo za: ' || v_nadimak_biljke;

        INSERT INTO podsjetnici (biljka_id, poruka, datum_podsjetnika, rijeseno)
        VALUES (NEW.biljka_id, v_poruka, CURRENT_DATE + v_interval, FALSE);

    ELSIF NEW.tip_dogadaja = 'Presađivanje' THEN
        SELECT interval_presadivanja_dani INTO v_interval 
        FROM vrste v JOIN biljke b ON b.vrsta_id = v.id WHERE b.id = NEW.biljka_id;

        v_poruka := 'Vrijeme za veću teglu (presađivanje): ' || v_nadimak_biljke;

        INSERT INTO podsjetnici (biljka_id, poruka, datum_podsjetnika, rijeseno)
        VALUES (NEW.biljka_id, v_poruka, CURRENT_DATE + v_interval, FALSE);

    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_auto_kreiranje_podsjetnika ON dogadaji;

CREATE TRIGGER trg_auto_kreiranje_podsjetnika
AFTER INSERT ON dogadaji
FOR EACH ROW
EXECUTE FUNCTION generiraj_iduci_podsjetnik();

-- =============================================
-- 4. PROVJERA TEMPERATURE
-- =============================================

  CREATE OR REPLACE FUNCTION provjeri_uvjete_biljke() RETURNS TRIGGER AS $$
DECLARE
    min_temp INTEGER;
    max_temp INTEGER;
    biljka_naziv VARCHAR;
BEGIN
    SELECT v.idealna_temperatura_min, v.idealna_temperatura_max, b.nadimak
    INTO min_temp, max_temp, biljka_naziv
    FROM biljke b
    JOIN vrste v ON b.vrsta_id = v.id
    WHERE b.id = NEW.biljka_id;

    IF NEW.temperatura < min_temp OR NEW.temperatura > max_temp THEN
        
        INSERT INTO podsjetnici (biljka_id, poruka, datum_podsjetnika, rijeseno)
        VALUES (
            NEW.biljka_id, 
            'HITNO: Temperatura opasna za ' || biljka_naziv || '! (' || NEW.temperatura || '°C)', 
            CURRENT_DATE, 
            FALSE
        );
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_provjera_uvjeta ON povijest_stanja;

CREATE TRIGGER trg_provjera_uvjeta
AFTER INSERT ON povijest_stanja
FOR EACH ROW
EXECUTE FUNCTION provjeri_uvjete_biljke();

-- =============================================
-- 5. PROCEDURA ZA ODRŽAVANJE
-- =============================================

CREATE OR REPLACE PROCEDURE ocisti_stare_podsjetnike()
LANGUAGE plpgsql
AS $$
BEGIN
    DELETE FROM podsjetnici 
    WHERE rijeseno = TRUE 
    AND datum_podsjetnika < CURRENT_DATE - INTERVAL '30 days';
    
    RAISE NOTICE 'Stari podsjetnici su očišćeni.';
END;
$$;

