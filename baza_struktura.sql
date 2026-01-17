CREATE TABLE vrste (
    id SERIAL PRIMARY KEY,
    naziv VARCHAR(100) NOT NULL,
    latinski_naziv VARCHAR(100),
    interval_zalijevanja_dani INTEGER NOT NULL, 
    idealna_temperatura_min INTEGER,
    idealna_temperatura_max INTEGER
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

INSERT INTO vrste (naziv, interval_zalijevanja_dani) VALUES 
('Monstera', 7),
('Fikus', 10),
('Kaktus', 20),
('Orhideja', 5);