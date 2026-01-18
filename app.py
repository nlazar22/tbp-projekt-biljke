import streamlit as st
import psycopg2
import pandas as pd
from datetime import datetime
import qrcode
from io import BytesIO
import urllib.parse

st.set_page_config(page_title="Moje Biljke", layout="wide")

def init_connection():
    return psycopg2.connect(
        host="localhost",
        database="biljke_db", 
        user="postgres",       
        password="postgres"        
    )

def run_query(query, params=None):
    conn = init_connection()
    try:
        if params:
            df = pd.read_sql(query, conn, params=params)
        else:
            df = pd.read_sql(query, conn)
        return df
    finally:
        conn.close()

def run_action(query, params):
    conn = init_connection()
    try:
        cur = conn.cursor()
        cur.execute(query, params)
        conn.commit()
        cur.close()
        return True
    except Exception as e:
        st.error(f"Greška u bazi: {e}")
        return False
    finally:
        conn.close()

st.sidebar.title("🌿 Izbornik")
opcija = st.sidebar.radio("Odaberi akciju:", 
    ["Nadzorna ploča", "Unesi novu biljku", "Zabilježi događaj", "Unesi mjerenje", "Generiraj QR kod"])

if opcija == "Nadzorna ploča":
    st.title("📊 Pregled stanja biljaka")
    
    st.subheader("🔔 Aktivni podsjetnici (Hitno!)")
    sql_podsjetnici = "SELECT * FROM podsjetnici WHERE rijeseno = FALSE ORDER BY datum_podsjetnika ASC"
    df_podsjetnici = run_query(sql_podsjetnici)
    
    if not df_podsjetnici.empty:
        st.warning("Imate neriješenih zadataka! Označi kvačicom desno kad riješiš.")

        uredena_tablica = st.data_editor(
            df_podsjetnici,
            column_config={
                "rijeseno": st.column_config.CheckboxColumn(
                    "Riješeno?",
                    help="Klikni za rješavanje zadatka",
                    default=False,
                ),
                "id": st.column_config.NumberColumn("ID", disabled=True),
                "biljka_id": st.column_config.NumberColumn("Biljka ID", disabled=True),
                "poruka": st.column_config.TextColumn("Poruka", disabled=True),
                "datum_podsjetnika": st.column_config.DateColumn("Datum", disabled=True),
            },
            hide_index=True,
            width="stretch",
            key="editor_podsjetnika" 
        )

        promjene = uredena_tablica[uredena_tablica["rijeseno"] == True]

        if not promjene.empty:
            for index, row in promjene.iterrows():
                run_action("UPDATE podsjetnici SET rijeseno = TRUE WHERE id = %s", (row['id'],))
                st.toast(f"✅ Zadatak #{row['id']} je riješen!")
            
            st.rerun()
    else:
        st.success("Nema aktivnih podsjetnika. Sve biljke su sretne! 🌱")

    st.markdown("---")
    
    st.subheader("📋 Glavni registar (View: pregled_statusa_biljaka)")
    df_view = run_query("SELECT * FROM pregled_statusa_biljaka")
    st.dataframe(df_view)

    st.subheader("📈 Statistika brige")
    df_stat = run_query("SELECT * FROM statistika_brige_o_biljkama")
    st.bar_chart(df_stat, x="nadimak", y="ukupno_dogadaja")

    st.markdown("---")
    st.subheader("🌡️ Kretanje temperature i vlage")
    
    query_graf = """
    SELECT p.id, b.nadimak, p.temperatura, p.vlaga_zraka, lower(p.period_vazenja) as vrijeme
    FROM povijest_stanja p
    JOIN biljke b ON p.biljka_id = b.id
    ORDER BY p.period_vazenja ASC
    """
    df_graf = run_query(query_graf)

    if not df_graf.empty:
        lista_biljaka = df_graf["nadimak"].unique()
        odabrana_za_graf = st.selectbox("Odaberi biljku za analizu:", lista_biljaka)
        
        podaci_za_prikaz = df_graf[df_graf["nadimak"] == odabrana_za_graf]

        podaci_za_prikaz = podaci_za_prikaz.set_index("vrijeme")

        col_g1, col_g2 = st.columns(2)
        
        with col_g1:
            st.write(f"Temperatura (°C) - {odabrana_za_graf}")
            st.line_chart(podaci_za_prikaz["temperatura"], color="#FF4B4B") 
            
        with col_g2:
            st.write(f"Vlaga zraka (%) - {odabrana_za_graf}")
            st.line_chart(podaci_za_prikaz["vlaga_zraka"], color="#0000FF") 
    else:
        st.info("Još nema unesenih mjerenja za prikaz grafa.") 

elif opcija == "Unesi novu biljku":
    st.title("🌱 Nova biljka")
    
    vrste = run_query("SELECT id, naziv FROM vrste")
    odabrana_vrsta = st.selectbox("Odaberi vrstu:", vrste["naziv"])
    vrsta_id = int(vrste[vrste["naziv"] == odabrana_vrsta]["id"].values[0])
    
    nadimak = st.text_input("Nadimak biljke (npr. Uredski Fikus):")
    slika = st.text_input("URL Slike (opcionalno):")
    
    if st.button("Spremi biljku"):
        if run_action("INSERT INTO biljke (vrsta_id, nadimak, slika_url) VALUES (%s, %s, %s)", (vrsta_id, nadimak, slika)):
            st.success(f"Biljka '{nadimak}' je uspješno dodana!")

elif opcija == "Zabilježi događaj":
    st.title("💧 Zabilježi brigu")
    st.info("Kada ovdje uneseš 'Zalijevanje', baza će automatski kreirati podsjetnik za idući put (Trigger)!")
    
    biljke = run_query("SELECT id, nadimak FROM biljke")
    if not biljke.empty:
        odabrana_biljka = st.selectbox("Odaberi biljku:", biljke["nadimak"])
        biljka_id = int(biljke[biljke["nadimak"] == odabrana_biljka]["id"].values[0])
        
        tip = st.selectbox("Što si radio?", ["Zalijevanje", "Gnojenje", "Presađivanje"])
        napomena = st.text_area("Napomena:")
        
        if st.button("Spremi događaj"):
            if run_action("INSERT INTO dogadaji (biljka_id, tip_dogadaja, napomena) VALUES (%s, %s, %s)", (biljka_id, tip, napomena)):
                st.success("Događaj spremljen! Provjeri 'Nadzornu ploču' da vidiš je li kreiran podsjetnik.")
    else:
        st.error("Prvo moraš unijeti neku biljku!")

elif opcija == "Unesi mjerenje":
    st.title("🌡️ Unos stanja okoliša")
    st.info("Ako uneseš lošu temperaturu, baza će odmah kreirati HITNI alarm!")
    
    biljke = run_query("SELECT id, nadimak FROM biljke")
    if not biljke.empty:
        odabrana_biljka = st.selectbox("Odaberi biljku:", biljke["nadimak"])
        biljka_id = int(biljke[biljke["nadimak"] == odabrana_biljka]["id"].values[0])
        
        temp = st.number_input("Temperatura (°C):", value=22.0)
        vlaga = st.number_input("Vlaga zraka (%):", value=50)
        
        if st.button("Spremi mjerenje"):
            if run_action("INSERT INTO povijest_stanja (biljka_id, temperatura, vlaga_zraka, period_vazenja) VALUES (%s, %s, %s, tstzrange(current_timestamp, null))", (biljka_id, temp, vlaga)):
                st.success("Mjerenje zabilježeno.")
                
                alarmi = run_query("SELECT * FROM podsjetnici WHERE rijeseno = FALSE AND poruka LIKE 'HITNO%'")
                if not alarmi.empty:
                    st.error("⚠️ PAŽNJA! Baza je detektirala loše uvjete i kreirala alarm!")
                    st.table(alarmi)

    else:
        st.error("Nema biljaka.")

elif opcija == "Generiraj QR kod":
    st.title("🖨️ Isprintaj naljepnice za tegle")
    st.info("Skeniranjem QR koda otvorit će se Google pretraga za ovu biljku!")
    
    biljke = run_query("SELECT id, nadimak, vrsta_id FROM biljke")
    
    vrste = run_query("SELECT id, naziv FROM vrste")
    
    if not biljke.empty:
        odabrana_biljka_nadimak = st.selectbox("Odaberi biljku za naljepnicu:", biljke["nadimak"])
        
        biljka_red = biljke[biljke["nadimak"] == odabrana_biljka_nadimak].iloc[0]
        vrsta_naziv = vrste[vrste["id"] == biljka_red["vrsta_id"]]["naziv"].values[0]
        
        if st.button("Generiraj QR Kod"):
            pojam_za_pretragu = f"{vrsta_naziv} njega i savjeti"
            siguran_pojam = urllib.parse.quote(pojam_za_pretragu)
            web_link = f"https://www.google.com/search?q={siguran_pojam}"
            
            img = qrcode.make(web_link)
            buffer = BytesIO()
            img.save(buffer, format="PNG")
            img_bytes = buffer.getvalue()
            
            col1, col2 = st.columns([1, 2])
            with col1:
                st.image(img_bytes, caption=f"Skeniraj me!", width=200)
            
            with col2:
                st.success(f"Kod vodi na Google pretragu za: '{vrsta_naziv}'")
                st.download_button(
                    label="⬇️ Preuzmi naljepnicu",
                    data=img_bytes,
                    file_name=f"qr_{odabrana_biljka_nadimak}.png",
                    mime="image/png"
                )
    else:
        st.error("Nemaš unesenih biljaka u bazi.")