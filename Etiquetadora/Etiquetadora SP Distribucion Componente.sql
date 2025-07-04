USE [NuevaDB]
GO
/****** Object:  StoredProcedure [dbo].[spSIG_PRR_DEV_DIST_CMP]    Script Date: 01/07/2025 10:36:06 a. m. ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER PROCEDURE [dbo].[spSIG_PRR_DEV_DIST_CMP] (@BultoXTda TypeBultos READONLY,@Prove INT,@NumPedido INT)
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
			DECLARE @acron VARCHAR(10);

			/*Delcaramos nuestra variable Tabla para almacenar el Type que se recibe*/
			DECLARE @BultoCMP TABLE (
				Tienda INT,
				Bulto_Com INT DEFAULT 0,
				Bulto_Ttl INT DEFAULT 0
			);
			DECLARE @RepCMP TABLE (
				Tienda INT,
				enl_art INT,
				Piezas INT,
				BultoUser INT,
				acronimo VARCHAR(10),
				no_etiqueta INT
			);
			DECLARE @PreILPN TABLE(
				Tienda INT,
				enl_art INT,
				Piezas INT,
				BultoUser INT,
				acronimo VARCHAR(10),
				no_etiqueta INT
			);
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
			/*Cargamos la informacion recibida de @BultoXTda*/
			INSERT INTO @BultoCMP (Tienda,Bulto_Com,Bulto_Ttl)
			SELECT Tienda,Bulto_Com,Bulto_Ttl FROM @BultoXTda;


			/*	Obetenemos el acronimo y ultima etiqueta de este. */
			
			SELECT
				@acron = b.acronimo
			FROM tabla_pivote a
			JOIN tabla_acronimo b ON a.acronimo = b.acronimo
			WHERE a.cod_pro = @Prove AND a.num_ped = @NumPedido

			/*Comienza con la distribucion de bultos y asignacion de etiquetas para componentes.*/
			/*Se carga informacion del acronimo y ultima etiqueta generada.*/
			;WITH acron AS (
				SELECT
					a.cod_pro, 
					a.num_ped,
					b.acronimo,
					b.no_etiqueta
				FROM tabla_pivote a
				JOIN tabla_acronimo b ON a.acronimo = b.acronimo
				WHERE a.cod_pro = @Prove AND a.num_ped = @NumPedido
			)
			/*Cargamos a @RepCMP la informacion que se procesara para las distribuciones*/
			INSERT INTO @RepCMP (Tienda,enl_art,Piezas,BultoUser,acronimo,no_etiqueta)
			SELECT 
				b.Tienda,
				a.enl_art,
				a.uni_p,
				b.Bulto_Ttl,
				c.acronimo,
				c.no_etiqueta
			FROM temporal_tabla a
			INNER JOIN @BultoCMP b ON a.cod_pto = b.Tienda
			INNER JOIN acron c ON a.num_ped = c.num_ped AND a.cod_pro = c.cod_pro
			WHERE a.cod_pro = @Prove AND a.num_ped = @NumPedido
			/*Obtenemos los registros por SKU y Tienda que se necesitaran*/
			;WITH Maximos AS (
				SELECT 
					Tienda,
					enl_art,
					Piezas,
					BultoUser,
					acronimo,
					no_etiqueta
				FROM @RepCMP
			),Numbers AS (
				SELECT TOP (SELECT MAX(Piezas) FROM Maximos)
					ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS Number
				FROM master.dbo.spt_values
			)
			/*Lo Cargamos a una tabla preeliminar para almacenar la informacion*/
			INSERT INTO @PreILPN (Tienda,enl_art,Piezas,BultoUser,acronimo,no_etiqueta)
			SELECT 
				m.Tienda,
				m.enl_art,
				1 AS Piezas,
				m.BultoUser,
				m.acronimo,
				m.no_etiqueta
			FROM Maximos m
			CROSS APPLY Numbers n
			WHERE n.Number <= m.Piezas
			ORDER BY m.Tienda, m.enl_art
			/*Obtenemos el incrementable de la etiqueta para posteriormente sumarlo a la etiqueta obtenida*/
			;WITH NumILPN AS (
				SELECT 
					Tienda,
					enl_art,
					Piezas,
					BultoUser,
					acronimo,
					no_etiqueta,
					ROW_NUMBER() OVER (ORDER BY Tienda, enl_art) AS incremento_etiqueta
				FROM @PreILPN
			)
			/*Cargamos a una variable Tabla para obtener etiqueta por etiqueta para cada bulto*/
			INSERT INTO @CNCT_ILPN(cod_pro,num_ped,Tienda,enl_art,Piezas,BultoAct,BultoUser,acronimo,no_etiqueta)
			SELECT
				@Prove,
				@NumPedido,
				Tienda,
				enl_art,
				Piezas,
				(ROW_NUMBER() OVER(PARTITION BY Tienda ORDER BY Tienda,enl_art) -1) % BultoUser + 1 AS BultoAct,
				BultoUser,
				acronimo,
				(SELECT MAX(no_etiqueta) FROM @PreILPN) + incremento_etiqueta AS no_etiqueta
			FROM NumILPN
			ORDER BY Tienda, enl_art;

			/*Actualizamos la ultima etiqueta creada*/
			UPDATE tabla_acronimo
			SET no_etiqueta = (SELECT MAX(no_etiqueta) FROM @CNCT_ILPN)
			WHERE acronimo = @acron;


			/*Realizaremos la carga en la tabla de ILPN*/
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

			/*Finaliza con la distribucion de bultos y asignacion de etiquetas para componentes.*/
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