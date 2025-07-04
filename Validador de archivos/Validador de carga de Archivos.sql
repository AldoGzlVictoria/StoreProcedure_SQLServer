﻿USE [NewDB]
GO
/****** Object:  StoredProcedure [dbo].[sp_valida_carga_archivos]    Script Date: 01/07/2025 11:00:40 a. m. ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER PROC [dbo].[sp_valida_carga_archivos] 
AS
BEGIN
	SET NOCOUNT ON
	DECLARE @bulk varchar(1000)
	DECLARE @DESC VARCHAR(6) = 'aa'
	DECLARE @sCountCol varchar(50)
	DECLARE @siCont		int
	DECLARE @sCont		varchar(25)
	DECLARE @error varchar(8000)
	DECLARE @success varchar(1000)
	DECLARE @DIVISION VARCHAR(100)
	DECLARE @NOMBRE VARCHAR(100)
	DECLARE @DIA_ANIO_ACTUAL VARCHAR(100)
	DECLARE @DIA_ANIO_PASADO VARCHAR(100)
	DECLARE @PORCENTAJE_DIA VARCHAR(100)
	DECLARE @MES_ANIO_ACTUAL VARCHAR(100)
	DECLARE @MES_ANIO_PASADO VARCHAR(100)
	DECLARE @PORCENTAJE_MES VARCHAR(100)
	DECLARE @COLUMN_NAME VARCHAR(50)
	DECLARE @SKU VARCHAR(16)
	DECLARE @DESCRIPCION VARCHAR(15)
	DECLARE @REGISTRO VARCHAR(1000)

	IF OBJECT_ID(N'dbo.tabla_orde_compra', N'U') IS NOT NULL  
	BEGIN
	   DROP TABLE [dbo].[tabla_orde_compra];  
	END
	IF OBJECT_ID(N'dbo.tabla_ventas_actual', N'U') IS NOT NULL  
	BEGIN
	   DROP TABLE [dbo].[tabla_ventas_actual];  
	END
	IF OBJECT_ID(N'dbo.tabla_ventas_mes_pasado', N'U') IS NOT NULL  
	BEGIN
	   DROP TABLE [dbo].[tabla_ventas_mes_pasado];  
	END
	
	CREATE TABLE tabla_orde_compra
	(
		EMI VARCHAR(15) NULL
		,FOLIO VARCHAR(30) NULL
		,DIV VARCHAR(15) NULL
		,REC VARCHAR(15) NULL
		,com_999 VARCHAR(15) NULL
		,DOCUMENTO VARCHAR(30) NULL
		,C_E VARCHAR(30) NULL
		,FECHA VARCHAR(30) NULL
		,SKU VARCHAR(15) NULL
		,EAN VARCHAR(30) NULL
		,REL VARCHAR(30) NULL
		,DESCRIPCION VARCHAR(100) NULL
		,PZAS VARCHAR(30) NULL
		,COSTO VARCHAR(30) NULL
		,NAT VARCHAR(1) NULL
		,CIERRA VARCHAR(15) NULL
		,TDA VARCHAR(15) NULL
	)
  
	CREATE TABLE tabla_ventas_actual
	(
		DIVISION VARCHAR(8) NULL
		,NOMBRE VARCHAR(50) NULL
		,DIA_ANIO_ACTUAL VARCHAR(20) NULL
		,DIA_ANIO_PASADO VARCHAR(20) NULL
		,PORCENTAJE_DIA VARCHAR(20) NULL
		,MES_ANIO_ACTUAL VARCHAR(30) NULL
		,MES_ANIO_PASADO VARCHAR(30) NULL
		,PORCENTAJE_MES VARCHAR(30) NULL
	)
  
	CREATE TABLE tabla_ventas_mes_pasado
	(
		DIVISION VARCHAR(8) NULL
		,NOMBRE VARCHAR(50) NULL
		,DIA_ANIO_ACTUAL VARCHAR(20) NULL
		,DIA_ANIO_PASADO VARCHAR(20) NULL
		,PORCENTAJE_DIA VARCHAR(20) NULL
		,MES_ANIO_ACTUAL VARCHAR(30) NULL
		,MES_ANIO_PASADO VARCHAR(30) NULL
		,PORCENTAJE_MES VARCHAR(30) NULL
	)

	--&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&--
		/*
			SE REALIZA LA VALIDACION DE LA CARGA DEL ARCHIVO archivo_orde_compra.txt
		*/
	--&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&--
	BEGIN TRY
		--&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&--
		BEGIN TRY
			SET @bulk =  'BULK INSERT tabla_orde_compra
				FROM ''//Ruta del Archivo Prueba/archivo_orde_compra.txt''
				WITH
				(
					FIRSTROW = 2,
   					FIELDTERMINATOR = ''	'',
					KEEPNULLS
   				)'
				EXECUTE (@bulk)
		END TRY
		BEGIN CATCH
			RAISERROR('La Carga del archivo tabla_orde_compra.txt falló, favor de validar', 16, 1);
			RETURN @@ERROR
		END CATCH
		--&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&--
		DECLARE C_OC CURSOR FOR
			SELECT 
			SKU,
			DESCRIPCION
		FROM tabla_orde_compra
		OPEN C_OC
		FETCH NEXT FROM C_OC INTO @SKU,@DESCRIPCION
		WHILE(@@FETCH_STATUS = 0)
		BEGIN
			SET @sCont = 8
			WHILE (@sCont <= 12)
			BEGIN
				--- #### --- #### --- #### --- #### --- #### --- ####
				SET @REGISTRO = CASE 
					WHEN @sCont = 8 THEN @SKU 
					ELSE @DESCRIPCION END
				--- #### --- #### --- #### --- #### --- #### --- ####
				IF((ISNULL(@REGISTRO,'NO_DATA') = 'NO_DATA') OR (ISNULL(@REGISTRO,'NO_DATA') <> 'aa' AND @sCont = 12))
				BEGIN
					BEGIN TRY
						SELECT @COLUMN_NAME = COLUMN_NAME FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME = 'tabla_orde_compra' AND ORDINAL_POSITION = @sCont
						SET @error = CASE 
							WHEN @sCont = 8 THEN 'EL ARCHIVO SE CARGO PERO EL CAMPO: ' + @COLUMN_NAME + ' SE ENCUENTRA VACIO, EN EL REGISTRO: ' + ERROR_LINE() 
							ELSE 'SE CARGO EL ARCHIVO PERO EL CAMPO: ' + @COLUMN_NAME + ' NO TRAE LA DESCRIPCION ACORDADA CON EL AREA DE AUDITORIA' END
						RAISERROR(@error,16,1)
						RETURN @@ERROR;
					END TRY
					BEGIN CATCH
						INSERT INTO tabla_valida_carga_log
						SELECT
							'ERROR',
							ERROR_PROCEDURE(),
							'tabla_orde_compra',
							ERROR_MESSAGE(),
							GETDATE()
					END CATCH
				END
				--- #### --- #### --- #### --- #### --- #### --- ####
				SET @sCont = @sCont + 4
			END
			FETCH NEXT FROM C_OC INTO @SKU,@DESCRIPCION
		END
		CLOSE C_OC
		DEALLOCATE C_OC
		--&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&--
		IF ((SELECT COUNT(*) FROM tabla_valida_carga_log WHERE flag_error = 'ERROR' AND tabla_error = 'tabla_orde_compra' AND CONVERT(VARCHAR,fecha_error,23) = CONVERT(VARCHAR,GETDATE(),23)) = 0)
		BEGIN
			SET @success = 'El archivo tabla_orde_compra.txt se cargo correctamente.'
			RAISERROR(@success,17,1) ;
			RETURN @@ERROR;
		END
		--&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&--
	END TRY
	BEGIN CATCH
		INSERT INTO tabla_valida_carga_log
		SELECT
			CASE WHEN ERROR_SEVERITY() = 17 THEN 'OK'
			ELSE 'ERROR'
			END ERROR,
			ERROR_PROCEDURE(),
			'tabla_orde_compra',
			ERROR_MESSAGE(),
			GETDATE()				
	END CATCH

	--&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&--
		/*
			SE REALIZA LA VALIDACION DE LA CARGA DEL ARCHIVO archivo_ventas_mes_pasado.txt
		*/
	--&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&--

	BEGIN TRY
		--&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&--
		BEGIN TRY
			SET @bulk =  'BULK INSERT tabla_ventas_mes_pasado
						FROM ''//Ruta del Archivo Prueba/archivo_ventas_mes_pasado.txt''
						WITH
						(
    						FIRSTROW = 2,
   							FIELDTERMINATOR = ''	'',
							KEEPNULLS
						)'
			EXECUTE (@bulk)
		END TRY
		BEGIN CATCH
			RAISERROR('La carga del archivo tabla_ventas_mes_pasado.txt falló, favor de validar', 16, 1);
			RETURN @@ERROR
		END CATCH
		--&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&--
		DECLARE VTA_MES CURSOR FOR
			SELECT 
				DIVISION
				,NOMBRE
				,DIA_ANIO_ACTUAL
				,DIA_ANIO_PASADO
				,PORCENTAJE_DIA
				,MES_ANIO_ACTUAL
				,MES_ANIO_PASADO
				,PORCENTAJE_MES
			FROM tabla_ventas_mes_pasado
		OPEN VTA_MES
		FETCH NEXT FROM VTA_MES INTO @DIVISION,@NOMBRE,@DIA_ANIO_ACTUAL,@DIA_ANIO_PASADO,@PORCENTAJE_DIA,@MES_ANIO_ACTUAL,@MES_ANIO_PASADO,@PORCENTAJE_MES
		WHILE(@@FETCH_STATUS = 0)
		BEGIN
			SET @sCont = 1
			WHILE (@sCont <= 8)
			BEGIN
				--- #### --- #### --- #### --- #### --- #### --- ####
				SET @REGISTRO = CASE 
					WHEN @sCont = 1 THEN @DIVISION 
					WHEN @sCont = 2 THEN @NOMBRE 		
					WHEN @sCont = 3 THEN @DIA_ANIO_ACTUAL 		
					WHEN @sCont = 4 THEN @DIA_ANIO_PASADO 		
					WHEN @sCont = 5 THEN @PORCENTAJE_DIA 		
					WHEN @sCont = 6 THEN @MES_ANIO_ACTUAL 		
					WHEN @sCont = 7 THEN @MES_ANIO_PASADO 		
					ELSE @PORCENTAJE_MES END
				--- #### --- #### --- #### --- #### --- #### --- ####
				IF(ISNULL(@REGISTRO,'NO_DATA') = 'NO_DATA' AND @NOMBRE NOT LIKE 'Cat.%')
				BEGIN
					BEGIN TRY
						SELECT @COLUMN_NAME = COLUMN_NAME FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME = 'tabla_ventas_mes_pasado' AND ORDINAL_POSITION = @sCont
						SET @error = 'EL ARCHIVO SE CARGO PERO LA COLUMNA: ' + @COLUMN_NAME + ' SE ENCUENTRA VACIA, DE LA DIVISION: ' + @DIVISION + ' ' + @NOMBRE
						--CASE 
						--	WHEN @NOMBRE LIKE 'Cat.%' THEN 'EL REGISTRO DE LA COLUMNA: ' + @COLUMN_NAME + ' NO ES VALIDA ' 
						--	ELSE 'EL ARCHIVO SE CARGO PERO LA COLUMNA: ' + @COLUMN_NAME + ' SE ENCUENTRA VACIA, DE LA DIVISION: ' + @DIVISION + ' ' + @NOMBRE END
						RAISERROR(@error,16,1)
						RETURN @@ERROR;
					END TRY
					BEGIN CATCH
						INSERT INTO tabla_valida_carga_log
						SELECT
							--CASE WHEN ERROR_MESSAGE() LIKE '%NO ES VALIDA%' THEN 'OK' ELSE 'ERROR' END ERROR,
							'ERROR',
							ERROR_PROCEDURE(),
							'tabla_ventas_mes_pasado',
							ERROR_MESSAGE(),
							GETDATE()
					END CATCH
				END
				--- #### --- #### --- #### --- #### --- #### --- ####
				SET @sCont = @sCont + 1
			END
			FETCH NEXT FROM VTA_MES INTO @DIVISION,@NOMBRE,@DIA_ANIO_ACTUAL,@DIA_ANIO_PASADO,@PORCENTAJE_DIA,@MES_ANIO_ACTUAL,@MES_ANIO_PASADO,@PORCENTAJE_MES
		END
		CLOSE VTA_MES
		DEALLOCATE VTA_MES
		--&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&--
		IF ((SELECT COUNT(*) FROM tabla_valida_carga_log WHERE flag_error = 'ERROR' AND tabla_error = 'tabla_ventas_mes_pasado' AND CONVERT(VARCHAR,fecha_error,23) = CONVERT(VARCHAR,GETDATE(),23)) = 0)
		BEGIN
			SET @success = 'El archivo tabla_ventas_mes_pasado.txt se cargo correctamente.'
			RAISERROR(@success,17,1) ;
			RETURN @@ERROR;
		END
		--&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&--
	END TRY
	BEGIN CATCH
		INSERT INTO tabla_valida_carga_log
		SELECT
			CASE WHEN ERROR_SEVERITY() = 17 THEN 'OK'
			ELSE 'ERROR'
			END ERROR,
			ERROR_PROCEDURE(),
			'tabla_ventas_mes_pasado',
			ERROR_MESSAGE(),
			GETDATE()
	END CATCH

	--&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&--
		/*
			SE REALIZA LA VALIDACION DE LA CARGA DEL ARCHIVO archivo_ventas_actual.txt
		*/
	--&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&--
	 SET @bulk = ''
	 BEGIN TRY
		--&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&--
		BEGIN TRY	
			SET @bulk =  'BULK INSERT tabla_ventas_actual
						FROM ''//Ruta del Archivo Prueba/archivo_ventas_actual.txt''
						WITH
						(
    						FIRSTROW = 2,
    						FIELDTERMINATOR = ''	''
   						)'
			EXECUTE (@bulk)
		END TRY
		BEGIN CATCH
			RAISERROR('La carga del archivo tabla_ventas_actual.txt falló, favor de validar', 16, 1);
			RETURN @@ERROR
		END CATCH
		--&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&--
		DECLARE VTA_SEM CURSOR FOR
			SELECT 
				DIVISION
				,NOMBRE
				,DIA_ANIO_ACTUAL
				,DIA_ANIO_PASADO
				,PORCENTAJE_DIA
				,MES_ANIO_ACTUAL
				,MES_ANIO_PASADO
				,PORCENTAJE_MES
			FROM tabla_ventas_actual
		OPEN VTA_SEM
		FETCH NEXT FROM VTA_SEM INTO @DIVISION,@NOMBRE,@DIA_ANIO_ACTUAL,@DIA_ANIO_PASADO,@PORCENTAJE_DIA,@MES_ANIO_ACTUAL,@MES_ANIO_PASADO,@PORCENTAJE_MES
		WHILE(@@FETCH_STATUS = 0)
		BEGIN
			SET @sCont = 1
			WHILE (@sCont <= 8)
			BEGIN
				--- #### --- #### --- #### --- #### --- #### --- ####
				SET @REGISTRO = CASE 
					WHEN @sCont = 1 THEN @DIVISION 
					WHEN @sCont = 2 THEN @NOMBRE 		
					WHEN @sCont = 3 THEN @DIA_ANIO_ACTUAL 		
					WHEN @sCont = 4 THEN @DIA_ANIO_PASADO 		
					WHEN @sCont = 5 THEN @PORCENTAJE_DIA 		
					WHEN @sCont = 6 THEN @MES_ANIO_ACTUAL 		
					WHEN @sCont = 7 THEN @MES_ANIO_PASADO 		
					ELSE @PORCENTAJE_MES END
				--- #### --- #### --- #### --- #### --- #### --- ####
				IF(ISNULL(@REGISTRO,'NO_DATA') = 'NO_DATA' AND @NOMBRE NOT LIKE 'Cat.%')
				BEGIN
					BEGIN TRY
						SELECT @COLUMN_NAME = COLUMN_NAME FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME = 'tabla_ventas_actual' AND ORDINAL_POSITION = @sCont
						SET @error = 'EL ARCHIVO SE CARGO PERO LA COLUMNA: ' + @COLUMN_NAME + ' SE ENCUENTRA VACIA, DE LA DIVISION: ' + @DIVISION + ' ' + @NOMBRE
						--CASE 
						--	WHEN @NOMBRE LIKE 'Cat.%' THEN 'EL REGISTRO DE LA COLUMNA: ' + @COLUMN_NAME + ' NO ES VALIDA ' 
						--	ELSE 'EL ARCHIVO SE CARGO PERO LA COLUMNA: ' + @COLUMN_NAME + ' SE ENCUENTRA VACIA, DE LA DIVISION: ' + @DIVISION + ' ' + @NOMBRE END
						RAISERROR(@error,16,1)
						RETURN @@ERROR;
					END TRY
					BEGIN CATCH
						INSERT INTO tabla_valida_carga_log
						SELECT
							-- CASE WHEN ERROR_MESSAGE() LIKE '%NO ES VALIDA%' THEN 'OK' ELSE 'ERROR' END ERROR,
							'ERROR',
							ERROR_PROCEDURE(),
							'tabla_ventas_actual',
							ERROR_MESSAGE(),
							GETDATE()
					END CATCH
				END
				--- #### --- #### --- #### --- #### --- #### --- ####
				SET @sCont = @sCont + 1
			END
			FETCH NEXT FROM VTA_SEM INTO @DIVISION,@NOMBRE,@DIA_ANIO_ACTUAL,@DIA_ANIO_PASADO,@PORCENTAJE_DIA,@MES_ANIO_ACTUAL,@MES_ANIO_PASADO,@PORCENTAJE_MES
		END
		CLOSE VTA_SEM
		DEALLOCATE VTA_SEM
		--&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&--
		IF ((SELECT COUNT(*) FROM tabla_valida_carga_log WHERE flag_error = 'ERROR' AND tabla_error = 'tabla_ventas_actual' AND CONVERT(VARCHAR,fecha_error,23) = CONVERT(VARCHAR,GETDATE(),23)) = 0)
		BEGIN
			SET @success = 'El archivo tabla_ventas_actual.txt se cargo correctamente.'
			RAISERROR(@success,17,1) ;
			RETURN @@ERROR;
		END
		--&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&--
	END TRY
	BEGIN CATCH
		INSERT INTO tabla_valida_carga_log
		SELECT
			CASE WHEN ERROR_SEVERITY() = 17 THEN 'OK'
			ELSE 'ERROR'
			END ERROR,
			ERROR_PROCEDURE(),
			'tabla_ventas_actual',
			ERROR_MESSAGE(),
			GETDATE()
	END CATCH

	--&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&--
		/*
			SE REALIZA LA VALIDACION DE LA CARGA DEL ARCHIVO tabla_ventas_acumuladas.txt
		*/
	--&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&--
	IF((DAY(GETDATE())) <= 15 )
	BEGIN
		IF OBJECT_ID(N'dbo.tabla_ventas_acumuladas', N'U') IS NOT NULL  
		BEGIN
		   DROP TABLE [dbo].[tabla_ventas_acumuladas];  
		END
		CREATE TABLE tabla_ventas_acumuladas
		(
			DIVISION VARCHAR(8) NULL
			,NOMBRE VARCHAR(50) NULL
			,DIA_ANIO_ACTUAL VARCHAR(20) NULL
			,DIA_ANIO_PASADO VARCHAR(20) NULL
			,PORCENTAJE_DIA VARCHAR(20) NULL
			,MES_ANIO_ACTUAL VARCHAR(30) NULL
			,MES_ANIO_PASADO VARCHAR(30) NULL
			,PORCENTAJE_MES VARCHAR(30) NULL
		)

		SET @bulk = ''
		 BEGIN TRY
			--&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&--
			BEGIN TRY	
				SET @bulk =  'BULK INSERT tabla_ventas_acumuladas
							FROM ''//Ruta del Archivo Prueba/archivo_ventas_acumuladas.txt''
							WITH
							(
    							FIRSTROW = 2,
    							FIELDTERMINATOR = ''	''
   							)'
				EXECUTE (@bulk)
			END TRY
			BEGIN CATCH
				RAISERROR('La carga del archivo archivo_ventas_acumuladas.txt falló, favor de validar', 16, 1);
				RETURN @@ERROR
			END CATCH
			--&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&--
			DECLARE VTA_ACU CURSOR FOR
				SELECT 
					DIVISION
					,NOMBRE
					,DIA_ANIO_ACTUAL
					,DIA_ANIO_PASADO
					,PORCENTAJE_DIA
					,MES_ANIO_ACTUAL
					,MES_ANIO_PASADO
					,PORCENTAJE_MES
				FROM tabla_ventas_acumuladas
			OPEN VTA_ACU
			FETCH NEXT FROM VTA_ACU INTO @DIVISION,@NOMBRE,@DIA_ANIO_ACTUAL,@DIA_ANIO_PASADO,@PORCENTAJE_DIA,@MES_ANIO_ACTUAL,@MES_ANIO_PASADO,@PORCENTAJE_MES
			WHILE(@@FETCH_STATUS = 0)
			BEGIN
				SET @sCont = 1
				WHILE (@sCont <= 8)
				BEGIN
					--- #### --- #### --- #### --- #### --- #### --- ####
					SET @REGISTRO = CASE 
						WHEN @sCont = 1 THEN @DIVISION 
						WHEN @sCont = 2 THEN @NOMBRE 		
						WHEN @sCont = 3 THEN @DIA_ANIO_ACTUAL 		
						WHEN @sCont = 4 THEN @DIA_ANIO_PASADO 		
						WHEN @sCont = 5 THEN @PORCENTAJE_DIA 		
						WHEN @sCont = 6 THEN @MES_ANIO_ACTUAL 		
						WHEN @sCont = 7 THEN @MES_ANIO_PASADO 		
						ELSE @PORCENTAJE_MES END
					--- #### --- #### --- #### --- #### --- #### --- ####
					IF(ISNULL(@REGISTRO,'NO_DATA') = 'NO_DATA' AND @NOMBRE NOT LIKE 'Cat.%')
					BEGIN
						BEGIN TRY
							SELECT @COLUMN_NAME = COLUMN_NAME FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME = 'tabla_ventas_acumuladas' AND ORDINAL_POSITION = @sCont
							SET @error = 'EL ARCHIVO SE CARGO PERO LA COLUMNA: ' + @COLUMN_NAME + ' SE ENCUENTRA VACIA, DE LA DIVISION: ' + @DIVISION + ' ' + @NOMBRE
							--CASE 
							--	WHEN @NOMBRE LIKE 'Cat.%' THEN 'EL REGISTRO DE LA COLUMNA: ' + @COLUMN_NAME + ' NO ES VALIDA ' 
							--	ELSE 'EL ARCHIVO SE CARGO PERO LA COLUMNA: ' + @COLUMN_NAME + ' SE ENCUENTRA VACIA, DE LA DIVISION: ' + @DIVISION + ' ' + @NOMBRE END
							RAISERROR(@error,16,1)
							RETURN @@ERROR;
						END TRY
						BEGIN CATCH
							INSERT INTO tabla_valida_carga_log
							SELECT
								--CASE WHEN ERROR_MESSAGE() LIKE '%NO ES VALIDA%' THEN 'OK' ELSE 'ERROR' END ERROR,
								'ERROR',
								ERROR_PROCEDURE(),
								'tabla_ventas_acumuladas',
								ERROR_MESSAGE(),
								GETDATE()
						END CATCH
					END
					--- #### --- #### --- #### --- #### --- #### --- ####
					SET @sCont = @sCont + 1
				END
				FETCH NEXT FROM VTA_ACU INTO @DIVISION,@NOMBRE,@DIA_ANIO_ACTUAL,@DIA_ANIO_PASADO,@PORCENTAJE_DIA,@MES_ANIO_ACTUAL,@MES_ANIO_PASADO,@PORCENTAJE_MES
			END
			CLOSE VTA_ACU
			DEALLOCATE VTA_ACU
			--&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&--
			IF ((SELECT COUNT(*) FROM tabla_valida_carga_log WHERE flag_error = 'ERROR' AND tabla_error = 'tabla_ventas_acumuladas' AND CONVERT(VARCHAR,fecha_error,23) = CONVERT(VARCHAR,GETDATE(),23)) = 0)
			BEGIN
				SET @success = 'El archivo tabla_ventas_acumuladas.txt se cargo correctamente.'
				RAISERROR(@success,17,1) ;
				RETURN @@ERROR;
			END
			--&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&--
		END TRY
		BEGIN CATCH
			INSERT INTO tabla_valida_carga_log
			SELECT
				CASE WHEN ERROR_SEVERITY() = 17 THEN 'OK'
				ELSE 'ERROR'
				END ERROR,
				ERROR_PROCEDURE(),
				'tabla_ventas_acumuladas',
				ERROR_MESSAGE(),
				GETDATE()
		END CATCH
	END
	--&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&--
		/*
			CONSULTA PARA EL ENVIO DEL CORREO
		*/
	--&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&--
	SELECT
		CASE 
			WHEN tabla_error = 'tabla_ventas_actual' THEN 'tabla_ventas_actual.txt'
			WHEN tabla_error = 'tabla_ventas_acumuladas' THEN 'tabla_ventas_acumuladas.txt'
			WHEN tabla_error = 'tabla_ventas_mes_pasado' THEN 'tabla_ventas_mes_pasado.txt'
			ELSE 'tabla_orde_compra.txt' END AS Archivo,
		mensaje_error,
		flag_error
	FROM tabla_valida_carga_log 
	WHERE CONVERT(VARCHAR,fecha_error,23) = CONVERT(VARCHAR,GETDATE(),23)
	ORDER BY flag_error DESC
	--&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&--
END

