USE [NuevaDB]
GO
/****** Object:  StoredProcedure [dbo].[spSIG_PRR_DEV_DIST]    Script Date: 01/07/2025 09:50:32 a. m. ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER PROCEDURE [dbo].[spSIG_PRR_DEV_DIST] 
    @Proveedor VARCHAR(8),
    @NumPedido VARCHAR(8)
AS
BEGIN
	SET NOCOUNT ON;
	/* 🔹 Se declaran variables locales 🔹 */
	DECLARE @TipoOC VARCHAR(2),
		@Query VARCHAR(800),
		@Params NVARCHAR(800);
	/* 🔹 Variable tipo tabla basada en "TypeBultos" y "TypeBultosUsuario" 🔹 */
	DECLARE @BultoXTda TypeBultos;
	/* 🔹 Variables tipo tabla y temporales🔹 */
	DECLARE @Conteos TABLE (
		Tienda INT,
		PC_Gex INT,
		Pzas_CMP INT
	);
	DECLARE @Tipo TABLE (
		Tipo VARCHAR(1)
	);
	CREATE TABLE #BultosUsuario (
		[cod_pro] [INT] NOT NULL,
		[num_ped] [INT] NOT NULL,
		[cod_pto] [INT] NOT NULL,
		[no_paq_pzs] [INT] NOT NULL,
		[rdo_pq_pzs] [BIT] NOT NULL
	);

	SET @Query = 'INSERT INTO #BultosUsuario (cod_pro,num_ped,cod_pto,no_paq_pzs,rdo_pq_pzs) SELECT cod_pro,num_ped,cod_pto,no_paq_pzs,rdo_pq_pzs FROM nuevo_prefijo_reb_' + @NumPedido + ' WITH (NOLOCK) '
	EXEC (@Query)

	SET @Query = 'DROP TABLE nuevo_prefijo_reb_' + @NumPedido
	EXEC (@Query)

	DELETE FROM #BultosUsuario WHERE no_paq_pzs = 0;
	/* CTE para calcular información sobre artículos Genéricos/Textiles y Componentes
		Este CTE (BltTda) obtiene información sobre el conteo y la sumatoria de piezas de los artículos, diferenciando entre artículos genéricos/textiles y componentes.
		🔹PC_Gex (Cantidad de artículos o sumatoria de piezas de artículos genéricos/textiles):
			* Si el tipo seleccionado por el usuario (rdo_pq_pzs = 1) y el artículo no está en la tabla de componentes (sag_componentes), se cuenta la cantidad de artículos (COUNT(enl_art)).
			* Si el tipo seleccionado (rdo_pq_pzs = 0) y el artículo no está en la tabla de componentes (sag_componentes), se obtiene la sumatoria de las piezas (SUM(uni_p)).
			* - Si el tipo seleccionado por el usuario (rdo_pq_pzs = 1) y el artículo no está en la tabla de componentes (sag_componentes), se cuenta la cantidad de artículos (COUNT(enl_art)).
			* Si ninguna condición se cumple, el valor es 0.
		🔹Pzas_Comp (Sumatoria de piezas de artículos tipo componente):
			* Si el artículo existe en la tabla de componentes (sag_componentes), se obtiene la sumatoria de las piezas (SUM(uni_p)).
			* Si el artículo no es un componente, el valor es 0.
	*/
	;WITH BltTda AS (
		SELECT 
			a.cod_pto AS Tienda,
			CASE WHEN b.rdo_pq_pzs = 1 AND NOT EXISTS (SELECT 1 FROM NuevaTablaComponentes WHERE enl_art_comp = a.enl_art) THEN ISNULL(COUNT(a.enl_art),0)
				WHEN b.rdo_pq_pzs = 0 AND NOT EXISTS (SELECT 1 FROM NuevaTablaComponentes WHERE enl_art_comp = a.enl_art) THEN ISNULL(SUM(a.uni_p),0)
				ELSE 0
			END AS PC_Gex,
			CASE 
				WHEN EXISTS (SELECT 1 FROM NuevaTablaComponentes WHERE enl_art_comp = a.enl_art) THEN ISNULL(SUM(a.uni_p),0)
				ELSE 0 
			END AS Pzas_Comp
		FROM temp_nueva_pre_recibo_prove_dev a
		JOIN #BultosUsuario b 
			ON a.cod_pro = b.cod_pro
			AND a.num_ped = b.num_ped
			AND a.cod_pto = b.cod_pto
		WHERE a.cod_pro = @Proveedor
			AND a.num_ped = @NumPedido
		GROUP BY a.cod_pto, b.rdo_pq_pzs, a.enl_art
	)
	/* 🔹 Insercion de informacion del CTE "BltTda" a variable tipo tabla @Conteos 🔹 */
	INSERT INTO @Conteos (Tienda, PC_Gex, Pzas_CMP)
	SELECT 
		Tienda,
		SUM(PC_Gex) AS PC_Gex,
		SUM(Pzas_Comp) AS Pzas_CMP
	FROM BltTda
	GROUP BY Tienda;
	/* CTE para calcular los bultos para artículos Genéricos/Textiles y Componentes
		Este CTE calcula la cantidad de bultos asignados a los artículos tipo Componente y tipo Genérico/Textil, siguiendo reglas específicas para cada tipo
		🔹 Bulto_Com (bultos asignados a artículos tipo Componente):
			* Si la sumatoria de las piezas de los componentes (Pzas_Comp) es 0, se asigna 0 bultos.
			* Si el número de bultos asignados (no_paq_pzs) es mayor a la sumatoria de las piezas de los componentes (Pzas_Comp), se asigna el valor de Pzas_Comp.
			* Si no_paq_pzs / 2 < 1, se asigna 1 bulto.
			* Si el residuo de no_paq_pzs / 2 es 0, se asigna no_paq_pzs / 2.
			* Si ninguna de las condiciones anteriores se cumple, se calcula ((no_paq_pzs * 1) / 2) + 1.

		🔹 Bulto_Gen (bultos asignados a artículos tipo Genérico/Textil):
			* Si el número de bultos asignados (no_paq_pzs) es mayor a la sumatoria de las piezas de los componentes (Pzas_Comp), se asigna la diferencia no_paq_pzs - Pzas_Comp.
			* Si no_paq_pzs es mayor al conteo de artículos o sumatoria de piezas (PC_Gex), o si no_paq_pzs - Pzas_Comp es mayor a PC_Gex, se asigna el valor de PC_Gex.
			* Si no_paq_pzs / 2 < 1, se asigna 1 bulto.
			* Si el residuo de no_paq_pzs / 2 es 0, se asigna no_paq_pzs / 2.
			* Si ninguna de las condiciones anteriores se cumple, se asigna ((no_paq_pzs - 1) / 2).
	*/
	;WITH OrdBlt AS (
		SELECT 
			t.cod_pto AS Tienda,
			CASE WHEN  c.PC_Gex = 0
				THEN c.Pzas_CMP
			WHEN c.Pzas_CMP = 0 
				THEN 0
			ELSE c.Pzas_CMP				
			END AS Bulto_Com,
			CASE WHEN c.PC_Gex = 0 
					THEN 0
				WHEN c.Pzas_CMP = 0 
					THEN CASE WHEN t.no_paq_pzs > c.PC_Gex
							THEN c.PC_Gex
						ELSE t.no_paq_pzs END
				ELSE 
					CASE WHEN t.no_paq_pzs > c.PC_Gex
						THEN c.PC_Gex
					ELSE t.no_paq_pzs END
			END AS Bulto_Gen,
			t.no_paq_pzs,
			t.rdo_pq_pzs AS Tipo_Ord
		FROM #BultosUsuario t
		JOIN @Conteos c 
			ON t.cod_pto = c.Tienda
	)
	/* 🔹 Insercion de informacion del CTE "OrdBlt" a variable tipo tabla @BultoXTda 🔹 */
	INSERT INTO @BultoXTda (Tienda, Bulto_Com, Bulto_Gen, Bulto_Ttl, Tipo_Ord)
	SELECT 
		Tienda,
		Bulto_Com,
		Bulto_Gen,
		(Bulto_Com + Bulto_Gen) AS Bulto_Ttl,
		Tipo_Ord
	FROM OrdBlt;
	/* 🔹 Se obtiene bandera para clasificar el tipo de OC dependiendo de los articulos que contiene 🔹 */
	INSERT INTO @Tipo (Tipo)
	SELECT DISTINCT
		CAST(CASE WHEN c.enl_art_comp IS NOT NULL 
				THEN 1 
			ELSE 0 
		END AS VARCHAR) AS Tipo
	FROM temp_nueva_pre_recibo_prove_dev a
	LEFT JOIN NuevaTablaComponentes c ON a.enl_art = c.enl_art_comp
	INNER JOIN #BultosUsuario p 
		ON a.cod_pro = p.cod_pro
		AND a.num_ped = p.num_ped
		AND a.cod_pto = p.cod_pto
	WHERE a.cod_pro = @Proveedor 
		AND a.num_ped = @NumPedido;
	/* 🔹 Concatenación de valores para @TipoOC 🔹 */	
	SELECT @TipoOC = COALESCE(@TipoOC + Tipo, Tipo)FROM @Tipo
	/* 🔹 Ejecución del procedimiento almacenado según TipoOC 🔹 */
	IF (@TipoOC = '0')
		EXEC spSIG_PRR_DEV_DIST_SKUyPZAS @BultoXTda, @Proveedor, @NumPedido;
	ELSE IF (@TipoOC = '1')
		EXEC spSIG_PRR_DEV_DIST_CMP @BultoXTda, @Proveedor, @NumPedido;
	ELSE IF (@TipoOC = '01' OR @TipoOC = '10')
		EXEC spSIG_PRR_DEV_DIST_MIXTO @BultoXTda, @Proveedor, @NumPedido;
END;