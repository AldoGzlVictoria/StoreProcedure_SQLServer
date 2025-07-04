USE [NuevaDB]
GO
/****** Object:  StoredProcedure [dbo].[spSIG_PRR_DEV_DIST_SKUyPZAS]    Script Date: 01/07/2025 10:36:11 a. m. ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER PROCEDURE [dbo].[spSIG_PRR_DEV_DIST_SKUyPZAS] (@BultoXTda TypeBultos READONLY,@Prove INT,@NumPedido INT)
AS
BEGIN
    SET NOCOUNT ON;
	SET DEADLOCK_PRIORITY LOW;
	DECLARE @RetryCount INT = 0;
	DECLARE @MaxRetries INT = 5;
	DECLARE @Success BIT = 0;
	WHILE @RetryCount < @MaxRetries AND @Success = 0
	BEGIN
		BEGIN TRY
			BEGIN TRANSACTION;
			/*Bloquemos el acronimo a que se va a cargar en las etiquetas ILPN*/
			SELECT acronimo, no_etiqueta FROM tabla_acronimo WITH (ROWLOCK, XLOCK)
			WHERE acronimo IN (SELECT acronimo FROM tabla_pivote WHERE cod_pro = @Prove AND num_ped = @NumPedido);
			/*Declaramos la variables que vamos a utilizar*/
			DECLARE @acron VARCHAR(10), 
				@no_etiqueta INT;
			/*	Se declaran las variables tipo tabla para el flujo de Bultos por SKU */
			DECLARE @BultoSKU TABLE (
				Tienda INT,
				Bulto_Gen INT DEFAULT 0,
				Bulto_Ttl INT DEFAULT 0,
				TipoOC BIT
			);
			DECLARE @RepSKU TABLE (
				Tienda INT,
				enl_art INT,
				Piezas INT,
				BultoUser INT,
				acronimo VARCHAR(10),
				no_etiqueta INT
			);
			DECLARE @PreSKU TABLE(
				Tienda INT,
				enl_art INT,
				Piezas INT,
				BultoAct INT,
				BultoUser INT,
				acronimo VARCHAR(10),
				no_etiqueta INT
			);
			/*	Se declaran las variables tipo tabla para el flujo de Bultos por Piezas */
			DECLARE @BultoPZS TABLE (
				Tienda INT,
				Bulto_Gen INT DEFAULT 0,
				Bulto_Ttl INT DEFAULT 0,
				TipoOC BIT
			);
			DECLARE @RepPZS TABLE (
				Tienda INT,
				enl_art INT,
				Piezas INT,
				BultoUser INT,
				acronimo VARCHAR(10),
				no_etiqueta INT
			);
			DECLARE @PrePZS TABLE(
				Tienda INT,
				enl_art INT,
				Piezas INT,
				BultoAct INT,
				BultoUser INT,
				acronimo VARCHAR(10),
				no_etiqueta INT
			);
			/* Se declara la variabla tipo tabla para combinar los flujos de SKU y Piezas */
			DECLARE @CNCT_ILPN TABLE (
				cod_pro VARCHAR(20),
				num_ped INT,
				Tienda INT,
				enl_art VARCHAR(50),
				Piezas INT,
				BultoAct INT,
				BultoUser INT,
				acronimo VARCHAR(10),
				no_etiqueta INT
			);
			/*	Cargamos la informacion para comenzar con las distribuciones correspondientes */
			INSERT INTO @BultoSKU (Tienda,Bulto_Gen,Bulto_Ttl,TipoOC)
			SELECT 
				Tienda,Bulto_Gen,Bulto_Ttl,Tipo_Ord 
			FROM @BultoXTda 
			WHERE Tipo_Ord = 1
			INSERT INTO @BultoPZS (Tienda,Bulto_Gen,Bulto_Ttl,TipoOC)
			SELECT 
				Tienda,Bulto_Gen,Bulto_Ttl,Tipo_Ord 
			FROM @BultoXTda 
			WHERE Tipo_Ord = 0
			/*	Obetenemos el acronimo y ultima etiqueta de este. */
			SELECT
				@acron = b.acronimo,
				@no_etiqueta = b.no_etiqueta
			FROM tabla_pivote a
			JOIN tabla_acronimo b ON a.acronimo = b.acronimo
			WHERE a.cod_pro = @Prove AND a.num_ped = @NumPedido

			INSERT INTO @RepPZS (Tienda,enl_art,Piezas,BultoUser,acronimo,no_etiqueta)
			SELECT 
				b.Tienda,
				a.enl_art,
				a.uni_p,
				b.Bulto_Ttl,
				@acron AS acronimo,
				@no_etiqueta AS no_etiqueta
			FROM temporal_tabla a
			INNER JOIN @BultoPZS b ON a.cod_pto = b.Tienda
			WHERE a.cod_pro = @Prove AND a.num_ped = @NumPedido

			INSERT INTO @RepSKU (Tienda,enl_art,Piezas,BultoUser,acronimo,no_etiqueta)
			SELECT 
				b.Tienda,
				a.enl_art,
				a.uni_p,
				b.Bulto_Ttl,
				@acron AS acronimo,
				@no_etiqueta AS no_etiqueta
			FROM temporal_tabla a
			INNER JOIN @BultoSKU b ON a.cod_pto = b.Tienda
			WHERE a.cod_pro = @Prove AND a.num_ped = @NumPedido

			/*_____________________________________________________________________________________________________________________________
				Cargada la informacion de la OC y el acronimos / no de etiqueta comezamos con los procesamientos de cada uno de los flujos.
			_____________________________________________________________________________________________________________________________*/

			/* ###################################################
				Distribucion por SKU
			###################################################### */
			;WITH DistSKU AS (
				SELECT 
					Tienda,
					enl_art,
					Piezas,
					BultoUser,
					acronimo,
					no_etiqueta,
					CEILING((ROW_NUMBER() OVER (PARTITION BY Tienda ORDER BY enl_art) * CAST(BultoUser AS FLOAT))/COUNT(*) OVER (PARTITION BY Tienda)) AS BultoAct
				FROM @RepSKU
			)
			INSERT INTO @PreSKU (Tienda,enl_art,Piezas,BultoAct,BultoUser,acronimo,no_etiqueta)
			SELECT 
				Tienda,
				enl_art,
				Piezas,
				BultoAct,
				BultoUser,
				acronimo,
				no_etiqueta
			FROM DistSKU
			/* ###################################################
				Distribucion por PIEZAS
			###################################################### */
			;WITH articulosPzas AS (
				SELECT
					Tienda,
					enl_art,
					Piezas,
					BultoUser,
					acronimo,
					no_etiqueta,
					SUM(Piezas) OVER (PARTITION BY Tienda ORDER BY enl_art ROWS UNBOUNDED PRECEDING) AS AcuPiezas
				FROM @RepPZS
			),RangoArti AS (
				SELECT
					Tienda,
					enl_art,
					Piezas,
					acronimo,
					no_etiqueta,
					BultoUser,
					AcuPiezas,
					(AcuPiezas - Piezas + 1) AS IniPos,
					AcuPiezas AS FinPos
				FROM articulosPzas
			),Totales AS (
				SELECT 
					Tienda,
					MAX(AcuPiezas) AS PiezasporTienda,
					MAX(BultoUser) AS BultoUser
				FROM articulosPzas
				GROUP BY Tienda
			),Numbers AS (
				SELECT TOP (1000)
				   ROW_NUMBER() OVER(ORDER BY (SELECT NULL)) AS BultoAct
				FROM master.dbo.spt_values
			),Bultos AS (
				SELECT
					 t.Tienda,
					 n.BultoAct,
					 t.BultoUser,
					 t.PiezasporTienda,
					 (t.PiezasporTienda / t.BultoUser) AS Piezas, 
					 (t.PiezasporTienda % t.BultoUser) AS resto,
					 CASE 
					   WHEN n.BultoAct <= (t.PiezasporTienda % t.BultoUser)
					   THEN (t.PiezasporTienda / t.BultoUser) + 1
					   ELSE (t.PiezasporTienda / t.BultoUser)
					 END AS PiezasEquitativas
				FROM Totales t
				JOIN Numbers n ON n.BultoAct <= t.BultoUser
			),RangosporBulto AS (
				SELECT 
					 Tienda,
					 BultoAct,
					 BultoUser,
					 PiezasEquitativas,
					 SUM(PiezasEquitativas) OVER (PARTITION BY Tienda ORDER BY BultoAct ROWS UNBOUNDED PRECEDING) AS FinBulto,
					 SUM(PiezasEquitativas) OVER (PARTITION BY Tienda ORDER BY BultoAct ROWS UNBOUNDED PRECEDING) - PiezasEquitativas + 1 AS IniBulto
				FROM Bultos
			), DistPzas AS (
			SELECT 
			   ar.Tienda,
			   ar.enl_art,
			   CASE 
				   WHEN (CASE WHEN ar.FinPos < br.FinBulto THEN ar.FinPos ELSE br.FinBulto END)
						- (CASE WHEN ar.IniPos > br.IniBulto THEN ar.IniPos ELSE br.IniBulto END) + 1 > 0
				   THEN (CASE WHEN ar.FinPos < br.FinBulto THEN ar.FinPos ELSE br.FinBulto END)
						- (CASE WHEN ar.IniPos > br.IniBulto THEN ar.IniPos ELSE br.IniBulto END) + 1
				   ELSE 0
			   END AS Piezas,
			   br.BultoAct,
			   br.BultoUser,
			   ar.acronimo,
			   ar.no_etiqueta
			FROM RangoArti ar
			JOIN RangosporBulto br 
			   ON ar.Tienda = br.Tienda
			   AND (CASE WHEN ar.FinPos < br.FinBulto THEN ar.FinPos ELSE br.FinBulto END)
				   - (CASE WHEN ar.IniPos > br.IniBulto THEN ar.IniPos ELSE br.IniBulto END) + 1 > 0
			)

			INSERT INTO @PrePZS (Tienda,enl_art,Piezas,BultoAct,BultoUser,acronimo,no_etiqueta)
			SELECT 
				Tienda,
				enl_art,
				Piezas,
				BultoAct,
				BultoUser,
				acronimo,
				no_etiqueta
			FROM DistPzas
			/* ###################################################
				Asignacion de Etiquetas ILPN
			###################################################### */
			;WITH ILPN AS(
				SELECT
					Tienda,
					enl_art,
					Piezas,
					BultoAct,
					BultoUser,
					acronimo,
					no_etiqueta
				FROM @PrePZS
				UNION ALL 
				SELECT
					Tienda,
					enl_art,
					Piezas,
					BultoAct,
					BultoUser,
					acronimo,
					no_etiqueta
				FROM @PreSKU
			),incrementos AS (
				-- Obtiene para cada registro su incremento local (secuencia reiniciada para cada tienda)
				SELECT
					Tienda,
					enl_art,
					Piezas,
					BultoAct,
					BultoUser,
					acronimo,
					no_etiqueta,
					BultoAct AS incremento
				FROM ILPN
			),StoreSummary AS (
				-- Para cada tienda se obtiene la cantidad de registros (equivalente al máximo de incremento)
				SELECT
					Tienda,
					MAX(incremento) AS countStore
				FROM incrementos
				GROUP BY Tienda
			),
			StoreOffsets AS (
				-- Para cada tienda (ordenadas por Tienda) se calcula el offset acumulado de las tiendas anteriores.
				-- Para la primera tienda, el offset será NULL (lo transformamos a 0).
				SELECT 
					Tienda,
					SUM(countStore) OVER (ORDER BY Tienda ROWS BETWEEN UNBOUNDED PRECEDING AND 1 PRECEDING) AS offsetVal
				FROM StoreSummary
			), IncCorregido AS (
			SELECT 
				li.Tienda,
				li.enl_art,
				li.Piezas,
				li.BultoAct,
				li.BultoUser,
				li.acronimo,
				li.no_etiqueta,
				-- El incremento corregido es el local (inicia en 1 para cada tienda) más el offset acumulado de las tiendas anteriores.
				li.incremento + ISNULL(so.offsetVal, 0) AS incremento_corregido
			FROM incrementos li
			LEFT JOIN StoreOffsets so ON li.Tienda = so.Tienda
			) 
			INSERT INTO @CNCT_ILPN (cod_pro,num_ped,Tienda,enl_art,Piezas,BultoAct,BultoUser,acronimo,no_etiqueta)
			SELECT
				@Prove,
				@NumPedido,
				Tienda,
				enl_art,
				Piezas,
				BultoAct,
				BultoUser,
				acronimo,
				no_etiqueta + incremento_corregido AS no_etiqueta 
			FROM IncCorregido ORDER BY Tienda, BultoAct

			
			UPDATE tabla_acronimo
			SET no_etiqueta = (SELECT MAX(no_etiqueta) FROM @CNCT_ILPN)
			WHERE acronimo = @acron;
		
			INSERT INTO tabla_etiquetas (cod_emp,fecha_gen,fecha_env,estatus,cod_fam2,tienda_no_paq,cod_pro,sku,unidades,num_ped,ilpn,cod_pro_oc)
			SELECT
				1 AS cod_emp,
				GETDATE(),
				'1999-01-01 00:00:00.000',
				'1' estatus,
				CONCAT('SRS', c.cod_fam2) AS cod_fam2,
				CONCAT('SRS', CAST(a.Tienda AS VARCHAR), '-', CAST(a.BultoAct AS VARCHAR), '-', CAST(a.BultoUser AS VARCHAR)) AS tienda_no_paq,
				CONCAT('SRS', a.cod_pro) AS cod_pro,
				CONCAT('SRS', a.enl_art) AS sku,
				a.Piezas,
				CAST(a.num_ped AS VARCHAR) AS num_ped,
				acronimo + RIGHT('000000000' + CAST(no_etiqueta AS VARCHAR(10)), 10),
				'SRS0000'
			FROM @CNCT_ILPN a 
			INNER JOIN proveedores b
				ON a.cod_pro = b.cod_pro
			INNER JOIN estructura_comercial c
				ON c.cod_fam1 = b.cod_fam1
				AND c.cod_fam2 = b.cod_fam2
				AND c.cod_fam3 = ' '
				AND c.cod_fam4 = ' '
				AND c.cod_fam5 = ' '
			/*Finaliza con la distribucion de bultos y asignacion de etiquetas.*/
			COMMIT TRANSACTION;
			SET @Success = 1;
		END TRY
		BEGIN CATCH
			DELETE FROM tabla_pivote
			WHERE cod_pro = @Prove
			AND num_ped = @NumPedido;

			IF @@TRANCOUNT > 0
				ROLLBACK TRANSACTION;

			IF ERROR_NUMBER() = 1205 -->> Deadlock
			BEGIN
				SET @RetryCount = @RetryCount + 1;
				WAITFOR DELAY '00:00:05';
			END
			ELSE
			BEGIN
				THROW;
			END
		END CATCH;
	END;
END;