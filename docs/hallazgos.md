# Hallazgos del análisis SQL

> Los datos son **sintéticos** (generados con `generar_datos.py`), por lo que estos hallazgos
> sirven para demostrar el método de análisis, no describen una empresa real.
> Período: 2025 · 12 tiendas · 200 productos · 6 categorías.

## Resumen

Las ventas netas de 2025 suman 103.3 M, con un margen bruto de 33.1 M (32.0 %).
Noviembre y diciembre concentran el 23 % de las ventas del año.
El formato de la tienda explica las ventas mucho más que la tienda en sí.

## Ventas

**1. Evolución mensual.** De enero a octubre las ventas se mantienen estables (promedio de
7.96 M al mes). En noviembre suben 30.2 % frente a octubre (10.69 M) y en diciembre
otro 21.8 % (13.02 M, el pico del año). Febrero es el mes más bajo (6.78 M, −8.6 %).

**2. Concentración por producto.** Los 10 productos principales (5 % del catálogo) generan
el 33.4 % de las ventas y los 20 principales (10 %), el 47 %. Cinco de los diez primeros
son de Electrohogar. El producto Electrohogar 163 lidera con 5.3 % de las ventas.

**3. Ranking por formato.** Las tiendas del mismo formato venden casi igual: la diferencia
entre la primera y la última de las Grandes es de solo 1.3 % (La Molina 11.75 M frente a
Surco 11.59 M). Por formato, las Grandes venden ~11.7 M, las Medianas ~8.3 M y las
Pequeñas ~5.0 M. El formato pesa mucho más que la ubicación.

**4. Mix de categorías.** El peso de cada categoría casi no cambia durante el año:
Electrohogar ~38–39 %, Deportes ~19 %, Calzado ~15–16 %, Hogar ~10–11 %, Ropa ~9 % y
Juguetes ~6 %. El aumento de noviembre y diciembre es parejo en todas las categorías.

**5. Margen por categoría.** Electrohogar aporta el mayor margen en valor (12.85 M, 39 % del
margen total). Ropa tiene el mayor margen porcentual (34.5 %) y Juguetes el menor (29.8 %).
Los márgenes de las demás categorías están entre 31.5 % y 32.3 %.

**6. Fin de semana.** Las ventas diarias promedio son 33.5 % más altas en fin de semana
(344,880) que de lunes a viernes (258,353).

## Inventario y operaciones

**7. Quiebres de stock.** La tasa de quiebre general es 1.45 % de los registros semanales.
Es mayor en las tiendas Grandes (1.65 %) y Medianas (1.52 %) que en las Pequeñas (1.07 %).
San Borja tiene la tasa más alta (1.86 %) y Jesús María la más baja (1.03 %). Las tiendas
de más volumen necesitan una reposición más ágil.

**8. Rotación de inventario.** La rotación anual es alta y pareja entre categorías (16.2 a
17.6 veces, unas 21 a 23 días de inventario). Deportes rota más rápido y Hogar más lento.
Es una aproximación basada en el stock promedio semanal.

**9. Exactitud del inventario.** De 6,000 conteos cíclicos, 427 (7.1 %) tuvieron diferencia
entre sistema y físico, con 990 unidades de diferencia absoluta. La diferencia neta es de
−230 unidades: en 10 de las 12 tiendas el stock físico es menor al del sistema. Los Olivos
(9.5 %) y Miraflores (9.4 %) tienen el mayor porcentaje de conteos con diferencia;
Lince tiene el menor (5.7 %).

**10. Transferencias entre tiendas.** De 3,000 transferencias, el 14.1 % se recibió con
incidencia. El tránsito promedio es de 2.8 días y casi no varía entre tiendas (2.6 a 3.0).
San Miguel tiene el mayor porcentaje de incidencias (17.3 %) y San Isidro el menor (11.0 %).
Cerrar una incidencia toma entre 29 horas (Callao) y 41 horas (Miraflores).

## Recomendaciones

1. Reforzar el abastecimiento y el stock de seguridad antes de noviembre y diciembre.
2. Dar prioridad de reposición a los productos principales y a las tiendas Grandes y Medianas.
3. Reforzar el conteo cíclico en Los Olivos y Miraflores, y revisar el proceso de recepción
   en San Miguel para reducir incidencias.

## Limitaciones

- Datos simulados: algunas diferencias entre tiendas (consultas 3, 7 y 10) son pequeñas y
  pueden deberse al azar del generador.
- La rotación (consulta 8) es una aproximación y resulta alta frente a lo habitual en retail.
- El Pareto se calculó solo sobre los 20 productos principales.