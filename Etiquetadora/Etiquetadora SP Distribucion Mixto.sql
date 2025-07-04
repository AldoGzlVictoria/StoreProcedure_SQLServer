USE [NuevaDB]
GO
/****** Object:  StoredProcedure [dbo].[spSIG_PRR_DEV_DIST_MIXTO]    Script Date: 01/07/2025 10:36:09 a. m. ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER PROCEDURE [dbo].[spSIG_PRR_DEV_DIST_MIXTO] (@BultoXTda TypeBultos READONLY,@Prove INT,@NumPedido INT)
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
				@no_etiqueta INT,
				@cod_pro_oc INT,
				@cod_fam2 VARCHAR(4);
			/*	Se declaran las variables tipo tabla para el flujo de Bultos por Componente */
			DECLARE @BultoCMP TABLE (
				Tienda INT,
				Bulto_Com INT DEFAULT 0,
				Bulto_Ttl INT DEFAULT 0
			);
			DECLARE @RepCMP TABLE (
				Tienda INT,
				enl_art INT,
				Piezas INT,
				BultoCMP INT,
				BultoUser INT,
				acronimo VARCHAR(10),
				no_etiqueta INT
			);
			DECLARE @PreCMP TABLE(
				Tienda INT,
				enl_art INT,
				Piezas INT,
				BultoAct INT,
				BultoCMP INT,
				acronimo VARCHAR(10),
				no_etiqueta INT
			);
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
				BultoGTX INT,
				BultoUser INT,
				acronimo VARCHAR(10),
				no_etiqueta INT
			);
			DECLARE @PreSKU TABLE(
				Tienda INT,
				enl_art INT,
				Piezas INT,
				BultoAct INT,
				BultoSKU INT,
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
				BultoGTX INT,
				BultoUser INT,
				acronimo VARCHAR(10),
				no_etiqueta INT
			);
			DECLARE @PrePZS TABLE(
				Tienda INT,
				enl_art INT,
				Piezas INT,
				BultoAct INT,
				BultoPzas INT,
				acronimo VARCHAR(10),
				no_etiqueta INT
			);
			/* Se declara la variabla tipo tabla para combinar los flujos de SKU y Piezas */
			DECLARE @C_ILPN TABLE (
				Tienda INT,
				enl_art INT,
				Piezas INT,
				BultoAct INT,
				BultoUser INT,
				acronimo VARCHAR(10),
				no_etiqueta INT
			);
			DECLARE @CNCT_ILPN TABLE (
				cod_pro VARCHAR(10),
				num_ped VARCHAR(10),
				Tienda VARCHAR(5),
				enl_art VARCHAR(15),
				Piezas VARCHAR(5),
				BultoAct VARCHAR(5),
				BultoUser VARCHAR(5),
				acronimo VARCHAR(10),
				no_etiqueta INT
			);

			SELECT 
				*
				,Tienda
				,Bulto_Com
				,Bulto_Gen
				,Bulto_Ttl
				,Tipo_Ord
			FROM  @BultoXTda

			/*	Cargamos la informacion para comenzar con las distribuciones correspondientes */
			INSERT INTO @BultoCMP (Tienda,Bulto_Com,Bulto_Ttl)
			SELECT 
				Tienda,Bulto_Com, Bulto_Ttl
			FROM @BultoXTda
			WHERE Bulto_Com <> 0

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
			
			;WITH pro_div AS(
			SELECT DISTINCT
				CASE WHEN a.cod_pro_oc = 0 THEN a.cod_pro ELSE a.cod_pro_oc END cod_pro_oc
			FROM temporal_tabla a
			WHERE a.cod_pro = @Prove
			AND a.num_ped =  @NumPedido
			)

			SELECT 
				@cod_pro_oc = a.cod_pro_oc
				,@cod_fam2 = b.cod_fam2
			FROM pro_div a
				INNER JOIN proveedores b
					ON  b.cod_pro = a.cod_pro_oc
				INNER JOIN estructura_comercial c
					ON c.cod_fam1 = b.cod_fam1
					AND c.cod_fam2 = b.cod_fam2
					AND c.cod_fam3 = '    '
					AND c.cod_fam4 = '    '
					AND c.cod_fam5 = '    '
			

			INSERT INTO @RepCMP (Tienda,enl_art,Piezas,BultoCMP,BultoUser,acronimo,no_etiqueta)
			SELECT 
				b.Tienda,
				a.enl_art,
				a.uni_p,
				b.Bulto_Com,
				b.Bulto_Ttl,
				@acron AS acronimo,
				@no_etiqueta AS no_etiqueta
			FROM temporal_tabla a
			INNER JOIN @BultoCMP b ON a.cod_pto = b.Tienda
			WHERE a.cod_pro = @Prove AND a.num_ped = @NumPedido
			AND a.enl_art IN (SELECT enl_art_comp FROM sag_componentes)

			INSERT INTO @RepPZS (Tienda,enl_art,Piezas,BultoGTX,BultoUser,acronimo,no_etiqueta)
			SELECT 
				b.Tienda,
				a.enl_art,
				a.uni_p,
				b.Bulto_Gen,
				b.Bulto_Ttl,
				@acron AS acronimo,
				@no_etiqueta AS no_etiqueta
			FROM temporal_tabla a
			INNER JOIN @BultoPZS b ON a.cod_pto = b.Tienda
			WHERE a.cod_pro = @Prove AND a.num_ped = @NumPedido
			AND a.enl_art NOT IN (SELECT enl_art_comp FROM sag_componentes )

			INSERT INTO @RepSKU (Tienda,enl_art,Piezas,BultoGTX,BultoUser,acronimo,no_etiqueta)
			SELECT 
				b.Tienda,
				a.enl_art,
				a.uni_p,
				b.Bulto_Gen,
				b.Bulto_Ttl,
				@acron AS acronimo,
				@no_etiqueta AS no_etiqueta
			FROM temporal_tabla a
			INNER JOIN @BultoSKU b ON a.cod_pto = b.Tienda
			WHERE a.cod_pro = @Prove AND a.num_ped = @NumPedido
			AND a.enl_art NOT IN (SELECT enl_art_comp FROM sag_componentes )

			
			/*_____________________________________________________________________________________________________________________________
				Cargada la informacion de la OC y el acronimos / no de etiqueta comezamos con los procesamientos de cada uno de los flujos.
			_____________________________________________________________________________________________________________________________*/

			/* ###################################################
				Distribucion por Componente
			###################################################### */
			;WITH Maximos AS (
				SELECT 
					Tienda,
					enl_art,
					Piezas,
					BultoCMP,
					BultoUser,
					acronimo,
					no_etiqueta
				FROM @RepCMP
			),Numbers AS (
				SELECT TOP (SELECT MAX(Piezas) FROM Maximos)
					ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS Number
				FROM master.dbo.spt_values
			)
			INSERT INTO @PreCMP (Tienda,enl_art,Piezas,BultoAct,BultoCMP,acronimo,no_etiqueta)
			SELECT 
				m.Tienda,
				m.enl_art,
				1 AS Piezas,
				ROW_NUMBER() OVER(PARTITION BY Tienda ORDER BY m.Tienda) AS BultoAct,
				m.BultoUser,
				m.acronimo,
				m.no_etiqueta
			FROM Maximos m
			CROSS APPLY Numbers n
			WHERE n.Number <= m.Piezas
			ORDER BY m.Tienda, m.enl_art
			/* ###################################################
				Distribucion por SKU
			###################################################### */
			;WITH DistSKU AS (
				SELECT 
					Tienda,
					enl_art,
					Piezas,
					BultoUser,
					BultoGTX,
					acronimo,
					no_etiqueta,
					CEILING((ROW_NUMBER() OVER (PARTITION BY Tienda ORDER BY enl_art) * CAST(BultoGTX AS FLOAT))/COUNT(*) OVER (PARTITION BY Tienda)) AS BultoAct
				FROM @RepSKU
			)
			INSERT INTO @PreSKU (Tienda,enl_art,Piezas,BultoAct,BultoSKU,acronimo,no_etiqueta)
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
					--BultoUser,
					BultoGTX,
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
					BultoGTX,
					--BultoUser,
					AcuPiezas,
					(AcuPiezas - Piezas + 1) AS IniPos,
					AcuPiezas AS FinPos
				FROM articulosPzas
			),Totales AS (
				SELECT 
					Tienda,
					MAX(AcuPiezas) AS PiezasporTienda,
					MAX(BultoGTX) AS BultoGTX
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
					 t.BultoGTX,
					 t.PiezasporTienda,
					 (t.PiezasporTienda / t.BultoGTX) AS Piezas, 
					 (t.PiezasporTienda % t.BultoGTX) AS resto,
					 CASE 
					   WHEN n.BultoAct <= (t.PiezasporTienda % t.BultoGTX)
					   THEN (t.PiezasporTienda / t.BultoGTX) + 1
					   ELSE (t.PiezasporTienda / t.BultoGTX)
					 END AS PiezasEquitativas
				FROM Totales t
				JOIN Numbers n ON n.BultoAct <= t.BultoGTX
			),RangosporBulto AS (
				SELECT 
					 Tienda,
					 BultoAct,
					 BultoGTX,
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
			   br.BultoGTX,
			   ar.acronimo,
			   ar.no_etiqueta
			FROM RangoArti ar
			JOIN RangosporBulto br 
			   ON ar.Tienda = br.Tienda
			   -- Solo consideramos los casos en que hay solapamiento
			   AND (CASE WHEN ar.FinPos < br.FinBulto THEN ar.FinPos ELSE br.FinBulto END)
				   - (CASE WHEN ar.IniPos > br.IniBulto THEN ar.IniPos ELSE br.IniBulto END) + 1 > 0
			--ORDER BY ar.Tienda, br.BultoAct, ar.enl_art
			)

			INSERT INTO @PrePZS (Tienda,enl_art,Piezas,BultoAct,BultoPzas,acronimo,no_etiqueta)
			SELECT 
				a.Tienda,
				a.enl_art,
				a.Piezas,
				a.BultoAct,
				b.BultoUser,
				a.acronimo,
				a.no_etiqueta
			FROM DistPzas a
			INNER JOIN @RepPZS b ON a.Tienda = b.Tienda AND a.enl_art = b.enl_art
			/* ###################################################
				Union de los Flujos SKU, PZAS y CMP
			###################################################### */
			;WITH MaxBulto AS (
				SELECT Tienda, MAX(BultoAct) AS UltimoBultoAct
				FROM @PreCMP
				GROUP BY Tienda
			), UnionSKU AS(
				SELECT 
					c.Tienda,
					c.enl_art,
					c.Piezas,
					c.BultoAct, -- Se mantiene igual en @PreCMP
					c.BultoCMP AS BultoReferencia,
					c.acronimo,
					c.no_etiqueta
				FROM @PreCMP c
				UNION ALL
				SELECT 
					s.Tienda,
					s.enl_art,
					s.Piezas,
					s.BultoAct + COALESCE(m.UltimoBultoAct, 0) AS BultoAct, -- Se suma el último BultoAct de @PreCMP
					s.BultoSKU AS BultoReferencia,
					s.acronimo,
					s.no_etiqueta
				FROM @PreSKU s
				INNER JOIN MaxBulto m ON s.Tienda = m.Tienda
			), UnionPZS AS (
				SELECT 
					c.Tienda,
					c.enl_art,
					c.Piezas,
					c.BultoAct, -- Se mantiene igual en @PreCMP
					c.BultoCMP AS BultoReferencia,
					c.acronimo,
					c.no_etiqueta
				FROM @PreCMP c
				UNION ALL
				SELECT 
					s.Tienda,
					s.enl_art,
					s.Piezas,
					s.BultoAct + COALESCE(m.UltimoBultoAct, 0) AS BultoAct, -- Se suma el último BultoAct de @PreCMP
					s.BultoPzas AS BultoReferencia,
					s.acronimo,
					s.no_etiqueta
				FROM @PrePZS s
				INNER JOIN MaxBulto m ON s.Tienda = m.Tienda
			), PreILPN AS (
				SELECT * FROM UnionSKU
				--UNION ALL
				UNION
				SELECT * FROM UnionPZS
				--UNION ALL
				UNION
				SELECT * FROM @PreSKU WHERE Tienda NOT IN (SELECT Tienda FROM @PreCMP)
				--UNION ALL
				UNION
				SELECT * FROM @PrePZS WHERE Tienda NOT IN (SELECT Tienda FROM @PreCMP)
			)
			INSERT INTO @C_ILPN (Tienda,enl_art,Piezas,BultoAct,BultoUser,acronimo,no_etiqueta)
			SELECT 
				--DISTINCT
				Tienda,
				enl_art,
				Piezas,
				BultoAct,
				BultoReferencia AS BultoUser,
				acronimo,
				no_etiqueta
			FROM PreILPN
			ORDER BY Tienda,BultoAct
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
				FROM @C_ILPN
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
		
			SELECT
				*
				INTO #Consolidado
			FROM @CNCT_ILPN
			--GROUP BY cod_pro,num_ped,Tienda,enl_art,Piezas,BultoAct,BultoUser,acronimo,no_etiqueta
		
			UPDATE #Consolidado
			SET BultoUser = (SELECT MAX(BultoAct) FROM @CNCT_ILPN WHERE BultoUser = 1)
			FROM #Consolidado a
				INNER JOIN @CNCT_ILPN b
					ON b.Tienda = a.Tienda
			WHERE a.BultoUser = 1


			INSERT INTO tabla_etiquetas (cod_emp,fecha_gen,fecha_env,estatus,cod_fam2,tienda_no_paq,cod_pro,sku,unidades,num_ped,ilpn,cod_pro_oc)
			SELECT
				1 AS cod_emp,
				GETDATE(),
				'1999-01-01 00:00:00.000',
				'1' estatus,
				CONCAT('SRS', @cod_fam2) AS cod_fam2,
				CONCAT('SRS', CAST(a.Tienda AS VARCHAR), '-', CAST(a.BultoAct AS VARCHAR), '-', CAST(a.BultoUser AS VARCHAR)) AS tienda_no_paq,
				CONCAT('SRS', a.cod_pro) AS cod_pro,
				CONCAT('SRS', a.enl_art) AS sku,
				a.Piezas,
				CAST(a.num_ped AS VARCHAR) AS num_ped,
				acronimo + RIGHT('000000000' + CAST(no_etiqueta AS VARCHAR(10)), 10),
				CONCAT('SRS',@cod_pro_oc) AS cod_pro_oc
			FROM @CNCT_ILPN a 
			
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