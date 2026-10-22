from pathlib import Path

import numpy as np
import pandas as pd

SEED = 42
ANIO = 2025
N_PRODUCTOS = 200
N_LINEAS_POR_TIENDA_DIA = 60   # líneas de venta promedio por tienda y día
OUT = Path("data")

rng = np.random.default_rng(SEED)
OUT.mkdir(exist_ok=True)

# ---------------------------------------------------------------- tiendas
tiendas = pd.DataFrame({
    "id_tienda": range(1, 13),
    "nombre_tienda": [f"Tienda {n}" for n in [
        "San Borja", "Miraflores", "San Isidro", "Surco", "La Molina", "Jesús María",
        "Lince", "Magdalena", "San Miguel", "Los Olivos", "Callao", "Ate"]],
    "distrito": ["San Borja", "Miraflores", "San Isidro", "Surco", "La Molina", "Jesús María",
                 "Lince", "Magdalena", "San Miguel", "Los Olivos", "Callao", "Ate"],
    "formato": ["Grande", "Mediana", "Mediana", "Grande", "Grande", "Pequeña",
                "Pequeña", "Pequeña", "Mediana", "Grande", "Mediana", "Mediana"],
})
peso_formato = {"Grande": 1.4, "Mediana": 1.0, "Pequeña": 0.6}
tiendas["peso_ventas"] = tiendas["formato"].map(peso_formato)

# -------------------------------------------------------------- productos
categorias = {
    "Electrohogar": (150, 900),
    "Calzado": (60, 350),
    "Ropa": (30, 250),
    "Hogar": (25, 400),
    "Juguetes": (20, 200),
    "Deportes": (40, 450),
}
filas = []
for i in range(1, N_PRODUCTOS + 1):
    cat = list(categorias)[(i - 1) % len(categorias)]
    lo, hi = categorias[cat]
    precio = round(float(rng.uniform(lo, hi)), 2)
    costo = round(precio * float(rng.uniform(0.55, 0.78)), 2)
    filas.append((i, f"SKU-{i:04d}", f"{cat} {i:03d}", cat,
                  f"Marca {int(rng.integers(1, 16))}", costo, precio))
productos = pd.DataFrame(filas, columns=[
    "id_producto", "sku", "nombre_producto", "categoria", "marca",
    "costo_unitario", "precio_unitario"])

# popularidad: pocos productos venden mucho, muchos venden poco
popularidad = rng.pareto(1.6, N_PRODUCTOS) + 1
popularidad = popularidad / popularidad.sum()

# ------------------------------------------------------------------ fechas
dias = pd.date_range(f"{ANIO}-01-01", f"{ANIO}-12-31", freq="D")
dim_fecha = pd.DataFrame({
    "fecha": dias,
    "anio": dias.year,
    "mes": dias.month,
    "nombre_mes": dias.month_name(),
    "semana_iso": dias.isocalendar().week.astype(int).values,
    "dia_semana": dias.dayofweek + 1,
    "nombre_dia": dias.day_name(),
    "es_fin_de_semana": (dias.dayofweek >= 5).astype(int),
})

# ------------------------------------------------------------------ ventas
def factor_dia(d):
    f = 1.0
    if d.dayofweek >= 5:
        f *= 1.35
    if d.month == 11:
        f *= 1.3          # Cyber / Black Friday
    if d.month == 12:
        f *= 1.6          # Navidad
    if d.month in (1, 2):
        f *= 0.9
    return f

bloques = []
for d in dias:
    for _, t in tiendas.iterrows():
        n = rng.poisson(N_LINEAS_POR_TIENDA_DIA * t["peso_ventas"] * factor_dia(d))
        if n == 0:
            continue
        prod_ids = rng.choice(productos["id_producto"].values, size=n, p=popularidad)
        bloques.append(pd.DataFrame({
            "fecha": d,
            "id_tienda": t["id_tienda"],
            "id_producto": prod_ids,
            "cantidad": rng.choice([1, 2, 3, 4], size=n, p=[0.72, 0.18, 0.07, 0.03]),
        }))
ventas = pd.concat(bloques, ignore_index=True)
ventas = ventas.merge(productos[["id_producto", "precio_unitario"]], on="id_producto")
ventas["descuento_pct"] = rng.choice([0, 0.05, 0.10, 0.20, 0.30], size=len(ventas),
                                     p=[0.70, 0.12, 0.10, 0.06, 0.02])
ventas = ventas.sort_values(["fecha", "id_tienda"]).reset_index(drop=True)
ventas.insert(0, "id_venta", np.arange(1, len(ventas) + 1))
ventas = ventas[["id_venta", "fecha", "id_tienda", "id_producto",
                 "cantidad", "precio_unitario", "descuento_pct"]]

# -------------------------------------------------------------- inventario
# Foto semanal del stock del sistema por tienda y producto.
# Se repone al máximo cuando el stock baja del punto de reposición.
ventas["semana"] = ventas["fecha"].dt.to_period("W-SUN").apply(lambda p: p.start_time)
semanas = sorted(ventas["semana"].unique())
v_sem = (ventas.groupby(["semana", "id_tienda", "id_producto"])["cantidad"]
         .sum().unstack(["id_tienda", "id_producto"]).reindex(semanas).fillna(0))
pares = pd.MultiIndex.from_product([tiendas["id_tienda"], productos["id_producto"]],
                                   names=["id_tienda", "id_producto"])
v_sem = v_sem.reindex(columns=pares, fill_value=0)

media_sem = v_sem.mean().values
stock_max = np.maximum(8, np.ceil(media_sem * 4)).astype(int)
punto_rep = np.ceil(stock_max * 0.30).astype(int)
stock = stock_max.copy()

registros = []
for semana in semanas:
    vend = v_sem.loc[semana].values
    stock = np.maximum(stock - vend, 0)
    # la reposición llega con retraso aleatorio: a veces se rompe el stock
    repone = (stock <= punto_rep) & (rng.random(len(stock)) < 0.80)
    stock = np.where(repone, stock_max, stock)
    registros.append(pd.DataFrame({
        "fecha_corte": semana + pd.Timedelta(days=6),
        "id_tienda": pares.get_level_values("id_tienda"),
        "id_producto": pares.get_level_values("id_producto"),
        "stock_sistema": stock.astype(int),
        "stock_maximo": stock_max,
        "punto_reposicion": punto_rep,
    }))
inventario = pd.concat(registros, ignore_index=True)
inventario["quiebre_stock"] = (inventario["stock_sistema"] == 0).astype(int)
inventario.insert(0, "id_inventario", np.arange(1, len(inventario) + 1))
ventas = ventas.drop(columns="semana")

# ---------------------------------------------------------- transferencias
n_trf = 3000
origen = rng.choice(tiendas["id_tienda"], size=n_trf)
destino = rng.choice(tiendas["id_tienda"], size=n_trf)
mismo = origen == destino
destino[mismo] = (destino[mismo] % 12) + 1
f_envio = rng.choice(dias[:-10], size=n_trf)
dias_transito = rng.choice([1, 2, 3, 4, 5, 7, 10], size=n_trf,
                           p=[0.30, 0.28, 0.17, 0.10, 0.07, 0.05, 0.03])
estado = rng.choice(["Recibida", "Recibida con incidencia", "En tránsito"],
                    size=n_trf, p=[0.82, 0.14, 0.04])
transferencias = pd.DataFrame({
    "id_transferencia": np.arange(1, n_trf + 1),
    "fecha_envio": pd.to_datetime(f_envio),
    "tienda_origen": origen,
    "tienda_destino": destino,
    "id_producto": rng.choice(productos["id_producto"], size=n_trf, p=popularidad),
    "cantidad": rng.integers(1, 40, size=n_trf),
    "estado": estado,
})
transferencias["fecha_recepcion"] = transferencias["fecha_envio"] + pd.to_timedelta(dias_transito, unit="D")
transferencias.loc[transferencias["estado"] == "En tránsito", "fecha_recepcion"] = pd.NaT
transferencias["horas_cierre_incidencia"] = np.where(
    transferencias["estado"] == "Recibida con incidencia",
    rng.gamma(2.5, 14, size=n_trf).round(1), np.nan)
transferencias = transferencias.sort_values("fecha_envio").reset_index(drop=True)
transferencias["id_transferencia"] = np.arange(1, n_trf + 1)

# ---------------------------------------------------------- conteo cíclico
n_cnt = 6000
cnt_tienda = rng.choice(tiendas["id_tienda"], size=n_cnt)
cnt_prod = rng.choice(productos["id_producto"], size=n_cnt)
cnt_fecha = pd.to_datetime(rng.choice(dias, size=n_cnt))
stock_sis = rng.integers(0, 60, size=n_cnt)
tiene_dif = rng.random(n_cnt) < 0.08           # ~8% de conteos con diferencia
dif = np.where(tiene_dif, rng.choice([-5, -3, -2, -1, 1, 2, 3], size=n_cnt), 0)
stock_fis = np.maximum(stock_sis + dif, 0)
conteo = pd.DataFrame({
    "id_conteo": np.arange(1, n_cnt + 1),
    "fecha_conteo": cnt_fecha,
    "id_tienda": cnt_tienda,
    "id_producto": cnt_prod,
    "stock_sistema": stock_sis,
    "stock_fisico": stock_fis,
})
conteo["diferencia"] = conteo["stock_fisico"] - conteo["stock_sistema"]
conteo = conteo.sort_values("fecha_conteo").reset_index(drop=True)
conteo["id_conteo"] = np.arange(1, n_cnt + 1)

# ----------------------------------------------------------------- guardar
tiendas = tiendas.drop(columns="peso_ventas")
salidas = {
    "tiendas": tiendas, "productos": productos, "dim_fecha": dim_fecha,
    "ventas": ventas, "inventario_semanal": inventario,
    "transferencias": transferencias, "conteo_ciclico": conteo,
}
for nombre, df in salidas.items():
    df.to_csv(OUT / f"{nombre}.csv", index=False, encoding="utf-8")
    print(f"{nombre:<20} {len(df):>9,} filas")

print("\nListo. Archivos guardados en:", OUT.resolve())
