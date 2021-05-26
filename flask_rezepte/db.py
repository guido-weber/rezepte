import os
from sqlalchemy import create_engine, MetaData, select

url = os.getenv("REZEPTE_DB_URL")
engine = create_engine(url, echo=True, future=True)
meta = MetaData(bind=engine)
meta.reflect()

tbl_rezepte = meta.tables["tbl_rezepte"]

def rezept_liste():
    with engine.begin() as conn:
        stmt = select(tbl_rezepte.c.rezept_id, tbl_rezepte.c.bezeichnung).order_by(tbl_rezepte.c.bezeichnung)
        return conn.execute(stmt)
