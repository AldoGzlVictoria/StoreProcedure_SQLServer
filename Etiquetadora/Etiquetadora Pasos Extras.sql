/*
	La siguiente documentacion es de apoyo para el correcto funcionamieto de los SP de distribucion de mercacia para su correcto etiquetado,
	los cuales requieren de un UDTT (Tipo de Tabla Definido por el Usuario) el que nos permitira pasar una tabla cargada con informacion entre
	SP y realizar el procesamiento de informacion correctamente.

	De igual manera la creacion de Indices virtuales (NONCLUSTERED) para el eficiencia de consulta en los querys
*/

/* Creacion de indices para las tablas de mayor carga */
DROP INDEX IX_AGV_PRR ON dbo.temp_sag_pre_recibo_lga_cdt_prove;
CREATE NONCLUSTERED INDEX IX_AGV_PRR ON dbo.tabla_order_compra (id_prove, id_orden,id_tienda) INCLUDE (id_articulo,piezas);
DROP INDEX IX_AGV_CMP ON dbo.sag_componentes;
CREATE NONCLUSTERED INDEX IX_AGV_CMP ON dbo.cat_componentes (id_componente);
DROP INDEX IX_AGV_PVT ON sag_pre_recibo_lga_cdt_pivot
CREATE NONCLUSTERED INDEX IX_AGV_PVT ON tabla_pivote (id_prove, id_orden);

/*Creacion de la estructura para variables tipo tabla */
CREATE TYPE TypeBultos AS TABLE (
    Tienda INT,
    Bulto_Com INT DEFAULT 0,
    Bulto_Gen INT DEFAULT 0,
    Bulto_Ttl INT DEFAULT 0,
    Tipo_Ord BIT
);
GO

/*Validacion y reseteo de la estructura de tabla y SP*/
-- Valida si existe el Type
SELECT 
	OBJECT_NAME(object_id) AS SP_Name
FROM sys.parameters
WHERE user_type_id = TYPE_ID('TypeBultos');
--1ro Borras los SP que la utilizan
DROP PROCEDURE spSIG_PRR_DEV_DIST_SKUyPZAS;
DROP PROCEDURE spSIG_PRR_DEV_DIST_CMP;
DROP PROCEDURE spSIG_PRR_DEV_DIST_MIXTO;
--2do Borras el tipo
DROP TYPE TypeBultosUsuario;
GO;




