import os
from sqlalchemy import create_engine, select, Column, ForeignKey, Integer, String, Numeric, UnicodeText
from sqlalchemy.orm import sessionmaker, declarative_base, relationship, deferred, undefer, selectinload

url = os.getenv("REZEPTE_DB_URL")
engine = create_engine(url, echo=True, future=True)

Session = sessionmaker(engine, future=True)
Base = declarative_base()

class Rezept(Base):
    __tablename__ = "tbl_rezepte"

    rezept_id = Column(Integer, primary_key=True)
    bezeichnung = Column(String(200))
    anleitung = deferred(Column(UnicodeText))

    tags = relationship("RezeptTag", back_populates="rezept", lazy="selectin", order_by="RezeptTag.tag")
    teile = relationship("RezeptTeil", back_populates="rezept", cascade="all, delete-orphan", order_by="RezeptTeil.reihenfolge")
    zutaten = relationship("RezeptZutat", back_populates="rezept", cascade="all, delete-orphan")

class RezeptTag(Base):
    __tablename__ = "tbl_rezept_tags"

    rezept_id = Column(Integer, ForeignKey('tbl_rezepte.rezept_id'), primary_key=True)
    tag = Column(String(50), primary_key=True)

    rezept = relationship("Rezept", back_populates="tags")

class RezeptTeil(Base):
    __tablename__ = "tbl_rezept_teile"

    rezept_teil_id = Column(Integer, primary_key=True)
    rezept_id = Column(Integer, ForeignKey('tbl_rezepte.rezept_id'))
    bezeichnung = Column(String(200))
    reihenfolge = Column(Integer)

    rezept = relationship("Rezept", back_populates="teile")
    zutaten = relationship("RezeptZutat", back_populates="rezept_teil", cascade="all, delete-orphan", order_by="RezeptZutat.reihenfolge")

class RezeptZutat(Base):
    __tablename__ = "tbl_rezept_zutaten"

    rezept_zutat_id = Column(Integer, primary_key=True)
    rezept_id = Column(Integer, ForeignKey('tbl_rezepte.rezept_id'))
    rezept_teil_id = Column(Integer, ForeignKey('tbl_rezept_teile.rezept_teil_id'))
    zutat = Column(String(50))
    reihenfolge = Column(Integer)
    menge = Column(Numeric(10, 2))
    mengeneinheit = Column(String(20))
    bemerkung = Column(String(100))

    rezept = relationship("Rezept", back_populates="zutaten")
    rezept_teil = relationship("RezeptTeil", back_populates="zutaten")

def rezept_liste() -> list[Rezept]:
    with Session() as session:
        return session.query(Rezept).order_by(Rezept.bezeichnung).limit(50).all()

def rezept_details(rezept_id: int) -> Rezept:
    with Session() as session:
        query = (session.query(Rezept)
            .options(undefer(Rezept.anleitung))
            .options(selectinload(Rezept.teile).selectinload(RezeptTeil.zutaten))
            .where(Rezept.rezept_id == rezept_id))
        return query.one_or_none()
