
USE portafolio_retail;

-- =====================================================================
-- 1. ¿Cómo evolucionan las ventas mes a mes?  (CTE + LAG)
-- =====================================================================
WITH ventas_mes AS (
    SELECT f.anio,
           f.mes,
           f.nombre_mes,
           SUM(v.cantidad)                                          AS unidades,
           SUM(v.cantidad * v.precio_unitario * (1 - v.descuento_pct)) AS ventas_netas
    FROM fact_ventas v
    JOIN dim_fecha f ON f.fecha = v.fecha
    GROUP BY f.anio, f.mes, f.nombre_mes
)
SELECT anio,
       nombre_mes,
       unidades,
       ROUND(ventas_netas, 2) AS ventas_netas,
       ROUND(100.0 * (ventas_netas - LAG(ventas_netas) OVER (ORDER BY anio, mes))
             / LAG(ventas_netas) OVER (ORDER BY anio, mes), 1) AS variacion_mensual_pct
FROM ventas_mes
ORDER BY anio, mes;

-- =====================================================================
-- 2. ¿Qué productos concentran las ventas?  (Pareto con suma acumulada)
-- =====================================================================
WITH ventas_producto AS (
    SELECT p.id_producto,
           p.nombre_producto,
           p.categoria,
           SUM(v.cantidad * v.precio_unitario * (1 - v.descuento_pct)) AS ventas_netas
    FROM fact_ventas v
    JOIN dim_producto p ON p.id_producto = v.id_producto
    GROUP BY p.id_producto, p.nombre_producto, p.categoria
)
SELECT RANK() OVER (ORDER BY ventas_netas DESC)                       AS ranking,
       nombre_producto,
       categoria,
       ROUND(ventas_netas, 2)                                          AS ventas_netas,
       ROUND(100.0 * SUM(ventas_netas) OVER (ORDER BY ventas_netas DESC)
             / SUM(ventas_netas) OVER (), 1)                           AS pct_acumulado
FROM ventas_producto
ORDER BY ranking
LIMIT 20;

-- =====================================================================
-- 3. ¿Qué tienda vende más dentro de su formato?  (RANK con PARTITION BY)
-- =====================================================================
WITH ventas_tienda AS (
    SELECT t.nombre_tienda,
           t.formato,
           SUM(v.cantidad * v.precio_unitario * (1 - v.descuento_pct)) AS ventas_netas
    FROM fact_ventas v
    JOIN dim_tienda t ON t.id_tienda = v.id_tienda
    GROUP BY t.nombre_tienda, t.formato
)
SELECT formato,
       nombre_tienda,
       ROUND(ventas_netas, 2) AS ventas_netas,
       RANK() OVER (PARTITION BY formato ORDER BY ventas_netas DESC) AS ranking_en_formato
FROM ventas_tienda
ORDER BY formato, ranking_en_formato;

-- =====================================================================
-- 4. ¿Cuánto pesa cada categoría en las ventas de cada mes?
-- =====================================================================
WITH ventas_cat_mes AS (
    SELECT f.mes,
           f.nombre_mes,
           p.categoria,
           SUM(v.cantidad * v.precio_unitario * (1 - v.descuento_pct)) AS ventas_netas
    FROM fact_ventas v
    JOIN dim_fecha f    ON f.fecha = v.fecha
    JOIN dim_producto p ON p.id_producto = v.id_producto
    GROUP BY f.mes, f.nombre_mes, p.categoria
)
SELECT mes,
       nombre_mes,
       categoria,
       ROUND(ventas_netas, 2) AS ventas_netas,
       ROUND(100.0 * ventas_netas / SUM(ventas_netas) OVER (PARTITION BY mes), 1) AS participacion_pct
FROM ventas_cat_mes
ORDER BY mes, participacion_pct DESC;

-- =====================================================================
-- 5. ¿Qué categorías dejan más margen?
-- =====================================================================
SELECT p.categoria,
       ROUND(SUM(v.cantidad * v.precio_unitario * (1 - v.descuento_pct)), 2)           AS ventas_netas,
       ROUND(SUM(v.cantidad * p.costo_unitario), 2)                                    AS costo_total,
       ROUND(SUM(v.cantidad * v.precio_unitario * (1 - v.descuento_pct))
             - SUM(v.cantidad * p.costo_unitario), 2)                                  AS margen,
       ROUND(100.0 * (SUM(v.cantidad * v.precio_unitario * (1 - v.descuento_pct))
             - SUM(v.cantidad * p.costo_unitario))
             / SUM(v.cantidad * v.precio_unitario * (1 - v.descuento_pct)), 1)         AS margen_pct
FROM fact_ventas v
JOIN dim_producto p ON p.id_producto = v.id_producto
GROUP BY p.categoria
ORDER BY margen DESC;

-- =====================================================================
-- 6. ¿Se vende más en fin de semana?  (promedio diario por tipo de día)
-- =====================================================================
WITH ventas_dia AS (
    SELECT f.fecha,
           f.es_fin_de_semana,
           SUM(v.cantidad * v.precio_unitario * (1 - v.descuento_pct)) AS ventas_netas
    FROM fact_ventas v
    JOIN dim_fecha f ON f.fecha = v.fecha
    GROUP BY f.fecha, f.es_fin_de_semana
)
SELECT CASE WHEN es_fin_de_semana = 1 THEN 'Fin de semana' ELSE 'Lunes a viernes' END AS tipo_dia,
       COUNT(*)                         AS dias,
       ROUND(AVG(ventas_netas), 2)      AS ventas_promedio_por_dia
FROM ventas_dia
GROUP BY es_fin_de_semana
ORDER BY es_fin_de_semana;

-- =====================================================================
-- 7. ¿Qué tiendas sufren más quiebres de stock?
-- =====================================================================
SELECT t.nombre_tienda,
       t.formato,
       COUNT(*)                                   AS registros_semanales,
       SUM(i.quiebre_stock)                       AS quiebres,
       ROUND(100.0 * SUM(i.quiebre_stock) / COUNT(*), 2) AS tasa_quiebre_pct
FROM fact_inventario_semanal i
JOIN dim_tienda t ON t.id_tienda = i.id_tienda
GROUP BY t.nombre_tienda, t.formato
ORDER BY tasa_quiebre_pct DESC;

-- =====================================================================
-- 8. Rotación de inventario por categoría (aproximada)
--    rotación = unidades vendidas / stock promedio semanal de la categoría
-- =====================================================================
WITH unidades AS (
    SELECT p.categoria, SUM(v.cantidad) AS unidades_vendidas
    FROM fact_ventas v
    JOIN dim_producto p ON p.id_producto = v.id_producto
    GROUP BY p.categoria
),
stock AS (
    SELECT p.categoria,
           SUM(i.stock_sistema) / COUNT(DISTINCT i.fecha_corte) AS stock_promedio_semanal
    FROM fact_inventario_semanal i
    JOIN dim_producto p ON p.id_producto = i.id_producto
    GROUP BY p.categoria
)
SELECT u.categoria,
       u.unidades_vendidas,
       ROUND(s.stock_promedio_semanal, 0)                    AS stock_promedio_semanal,
       ROUND(u.unidades_vendidas / s.stock_promedio_semanal, 2) AS rotacion_anual,
       ROUND(365 / (u.unidades_vendidas / s.stock_promedio_semanal), 0) AS dias_de_inventario
FROM unidades u
JOIN stock s ON s.categoria = u.categoria
ORDER BY rotacion_anual DESC;

-- =====================================================================
-- 9. Exactitud del inventario: conteo cíclico (sistema vs. físico)
-- =====================================================================
SELECT t.nombre_tienda,
       COUNT(*)                                                    AS conteos,
       SUM(CASE WHEN c.diferencia <> 0 THEN 1 ELSE 0 END)          AS conteos_con_diferencia,
       ROUND(100.0 * SUM(CASE WHEN c.diferencia <> 0 THEN 1 ELSE 0 END) / COUNT(*), 1) AS pct_con_diferencia,
       SUM(c.diferencia)                                           AS diferencia_neta_unidades,
       SUM(ABS(c.diferencia))                                      AS diferencia_absoluta_unidades
FROM fact_conteo_ciclico c
JOIN dim_tienda t ON t.id_tienda = c.id_tienda
GROUP BY t.nombre_tienda
ORDER BY pct_con_diferencia DESC;

-- =====================================================================
-- 10. Transferencias entre tiendas: tránsito e incidencias por destino
-- =====================================================================
WITH trf AS (
    SELECT td.nombre_tienda AS tienda_destino,
           x.estado,
           x.horas_cierre_incidencia,
           DATEDIFF(x.fecha_recepcion, x.fecha_envio) AS dias_transito
    FROM fact_transferencias x
    JOIN dim_tienda td ON td.id_tienda = x.tienda_destino
)
SELECT tienda_destino,
       COUNT(*)                                                       AS transferencias,
       ROUND(AVG(dias_transito), 1)                                   AS dias_transito_promedio,
       ROUND(100.0 * SUM(CASE WHEN estado = 'Recibida con incidencia' THEN 1 ELSE 0 END)
             / COUNT(*), 1)                                           AS pct_con_incidencia,
       ROUND(AVG(horas_cierre_incidencia), 1)                         AS horas_promedio_cierre_incidencia
FROM trf
GROUP BY tienda_destino
ORDER BY pct_con_incidencia DESC;
