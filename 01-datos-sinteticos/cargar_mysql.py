import getpass
from pathlib import Path

import pandas as pd
import pymysql

BASE = Path(__file__).resolve().parent
DATA = BASE / "data"
SQL = BASE / "sql" / "01_crear_modelo.sql"
LOTE = 5000

# (archivo CSV, tabla destino) en orden: primero dimensiones, luego hechos
CARGAS = [
    ("dim_fecha.csv", "dim_fecha"),
    ("tiendas.csv", "dim_tienda"),
    ("productos.csv", "dim_producto"),
    ("ventas.csv", "fact_ventas"),
    ("inventario_semanal.csv", "fact_inventario_semanal"),
    ("transferencias.csv", "fact_transferencias"),
    ("conteo_ciclico.csv", "fact_conteo_ciclico"),
]


def leer_sentencias(ruta):
    """Devuelve las sentencias SQL de un archivo, sin comentarios '--'."""
    lineas = [l for l in ruta.read_text(encoding="utf-8").splitlines()
              if not l.strip().startswith("--")]
    return [s.strip() for s in "\n".join(lineas).split(";") if s.strip()]


def filas_para_insertar(df):
    """Convierte el DataFrame en lista de tuplas, con NaN -> None (NULL)."""
    df = df.astype(object).where(df.notna(), None)
    return [tuple(f) for f in df.values.tolist()]


def main():
    host = input("Host de MySQL [localhost]: ").strip() or "localhost"
    puerto = int(input("Puerto [3306]: ").strip() or 3306)
    usuario = input("Usuario [root]: ").strip() or "root"
    clave = getpass.getpass("Contraseña de MySQL (no se mostrará): ")

    faltan = [c for c, _ in CARGAS if not (DATA / c).exists()]
    if faltan:
        raise SystemExit(f"Faltan archivos en data/: {faltan}. "
                         "Ejecuta primero generar_datos.py")

    conn = pymysql.connect(host=host, port=puerto, user=usuario,
                           password=clave, charset="utf8mb4")
    try:
        with conn.cursor() as cur:
            for sentencia in leer_sentencias(SQL):
                cur.execute(sentencia)
            conn.commit()
            print("Modelo creado en la base portafolio_retail.\n")

            for archivo, tabla in CARGAS:
                df = pd.read_csv(DATA / archivo)
                cols = ", ".join(df.columns)
                marcas = ", ".join(["%s"] * len(df.columns))
                insert = f"INSERT INTO {tabla} ({cols}) VALUES ({marcas})"
                filas = filas_para_insertar(df)
                for i in range(0, len(filas), LOTE):
                    cur.executemany(insert, filas[i:i + LOTE])
                conn.commit()
                print(f"{tabla:<26} {len(filas):>9,} filas cargadas")

            print("\nVerificación:")
            for _, tabla in CARGAS:
                cur.execute(f"SELECT COUNT(*) FROM {tabla}")
                print(f"{tabla:<26} {cur.fetchone()[0]:>9,}")
    finally:
        conn.close()


if __name__ == "__main__":
    main()
