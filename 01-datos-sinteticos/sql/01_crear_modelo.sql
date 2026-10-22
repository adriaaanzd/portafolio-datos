-- 01_crear_modelo.sql
-- Modelo estrella para el análisis de retail e inventarios.
-- Dimensiones: dim_fecha, dim_tienda, dim_producto
-- Hechos: fact_ventas, fact_inventario_semanal, fact_transferencias, fact_conteo_ciclico

CREATE DATABASE IF NOT EXISTS portafolio_retail
    CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

USE portafolio_retail;

SET FOREIGN_KEY_CHECKS = 0;
DROP TABLE IF EXISTS fact_conteo_ciclico;
DROP TABLE IF EXISTS fact_transferencias;
DROP TABLE IF EXISTS fact_inventario_semanal;
DROP TABLE IF EXISTS fact_ventas;
DROP TABLE IF EXISTS dim_producto;
DROP TABLE IF EXISTS dim_tienda;
DROP TABLE IF EXISTS dim_fecha;
SET FOREIGN_KEY_CHECKS = 1;

-- ------------------------------------------------------------ DIMENSIONES

CREATE TABLE dim_fecha (
    fecha             DATE         NOT NULL,
    anio              SMALLINT     NOT NULL,
    mes               TINYINT      NOT NULL,
    nombre_mes        VARCHAR(20)  NOT NULL,
    semana_iso        TINYINT      NOT NULL,
    dia_semana        TINYINT      NOT NULL,
    nombre_dia        VARCHAR(20)  NOT NULL,
    es_fin_de_semana  TINYINT      NOT NULL,
    PRIMARY KEY (fecha)
) ENGINE = InnoDB;

CREATE TABLE dim_tienda (
    id_tienda      INT          NOT NULL,
    nombre_tienda  VARCHAR(60)  NOT NULL,
    distrito       VARCHAR(60)  NOT NULL,
    formato        VARCHAR(20)  NOT NULL,
    PRIMARY KEY (id_tienda)
) ENGINE = InnoDB;

CREATE TABLE dim_producto (
    id_producto      INT            NOT NULL,
    sku              VARCHAR(20)    NOT NULL,
    nombre_producto  VARCHAR(80)    NOT NULL,
    categoria        VARCHAR(40)    NOT NULL,
    marca            VARCHAR(40)    NOT NULL,
    costo_unitario   DECIMAL(10,2)  NOT NULL,
    precio_unitario  DECIMAL(10,2)  NOT NULL,
    PRIMARY KEY (id_producto),
    UNIQUE KEY uq_producto_sku (sku)
) ENGINE = InnoDB;

-- ------------------------------------------------------------------ HECHOS

CREATE TABLE fact_ventas (
    id_venta         INT            NOT NULL,
    fecha            DATE           NOT NULL,
    id_tienda        INT            NOT NULL,
    id_producto      INT            NOT NULL,
    cantidad         INT            NOT NULL,
    precio_unitario  DECIMAL(10,2)  NOT NULL,
    descuento_pct    DECIMAL(4,2)   NOT NULL,
    PRIMARY KEY (id_venta),
    KEY idx_ventas_fecha (fecha),
    KEY idx_ventas_tienda (id_tienda),
    KEY idx_ventas_producto (id_producto),
    CONSTRAINT fk_ventas_fecha    FOREIGN KEY (fecha)       REFERENCES dim_fecha (fecha),
    CONSTRAINT fk_ventas_tienda   FOREIGN KEY (id_tienda)   REFERENCES dim_tienda (id_tienda),
    CONSTRAINT fk_ventas_producto FOREIGN KEY (id_producto) REFERENCES dim_producto (id_producto)
) ENGINE = InnoDB;

-- fecha_corte es el domingo de cada semana; la última semana cae en enero de
-- 2026, por eso esta tabla no tiene llave foránea hacia dim_fecha.
CREATE TABLE fact_inventario_semanal (
    id_inventario     INT      NOT NULL,
    fecha_corte       DATE     NOT NULL,
    id_tienda         INT      NOT NULL,
    id_producto       INT      NOT NULL,
    stock_sistema     INT      NOT NULL,
    stock_maximo      INT      NOT NULL,
    punto_reposicion  INT      NOT NULL,
    quiebre_stock     TINYINT  NOT NULL,
    PRIMARY KEY (id_inventario),
    KEY idx_inv_fecha (fecha_corte),
    KEY idx_inv_tienda_producto (id_tienda, id_producto),
    CONSTRAINT fk_inv_tienda   FOREIGN KEY (id_tienda)   REFERENCES dim_tienda (id_tienda),
    CONSTRAINT fk_inv_producto FOREIGN KEY (id_producto) REFERENCES dim_producto (id_producto)
) ENGINE = InnoDB;

CREATE TABLE fact_transferencias (
    id_transferencia         INT           NOT NULL,
    fecha_envio              DATE          NOT NULL,
    tienda_origen            INT           NOT NULL,
    tienda_destino           INT           NOT NULL,
    id_producto              INT           NOT NULL,
    cantidad                 INT           NOT NULL,
    estado                   VARCHAR(30)   NOT NULL,
    fecha_recepcion          DATE          NULL,
    horas_cierre_incidencia  DECIMAL(6,1)  NULL,
    PRIMARY KEY (id_transferencia),
    KEY idx_trf_envio (fecha_envio),
    KEY idx_trf_estado (estado),
    CONSTRAINT fk_trf_origen   FOREIGN KEY (tienda_origen)  REFERENCES dim_tienda (id_tienda),
    CONSTRAINT fk_trf_destino  FOREIGN KEY (tienda_destino) REFERENCES dim_tienda (id_tienda),
    CONSTRAINT fk_trf_producto FOREIGN KEY (id_producto)    REFERENCES dim_producto (id_producto)
) ENGINE = InnoDB;

CREATE TABLE fact_conteo_ciclico (
    id_conteo      INT   NOT NULL,
    fecha_conteo   DATE  NOT NULL,
    id_tienda      INT   NOT NULL,
    id_producto    INT   NOT NULL,
    stock_sistema  INT   NOT NULL,
    stock_fisico   INT   NOT NULL,
    diferencia     INT   NOT NULL,
    PRIMARY KEY (id_conteo),
    KEY idx_conteo_fecha (fecha_conteo),
    CONSTRAINT fk_conteo_fecha    FOREIGN KEY (fecha_conteo) REFERENCES dim_fecha (fecha),
    CONSTRAINT fk_conteo_tienda   FOREIGN KEY (id_tienda)    REFERENCES dim_tienda (id_tienda),
    CONSTRAINT fk_conteo_producto FOREIGN KEY (id_producto)  REFERENCES dim_producto (id_producto)
) ENGINE = InnoDB;
