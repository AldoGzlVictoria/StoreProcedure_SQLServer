  
CREATE PROCEDURE [dbo].[spSIG_TablaDinamica]
AS  
BEGIN
  SET NOCOUNT ON
  
  /*
  &&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&
  Creacion de tabla dinamica #DinamicTable:
	El procedimiento para realizar la creación de este tipo de tablas es la siguiente:
		1.- Debemos tener en cuenta que la creacion va de acuerdo a un archivo con N cantidad de campos separados por | (pipes)
		2.- Una vez que identificamos el archivo realizamos un Bulk de todo el contenido de este con su respectivo Try-Catch.
		3.- En el siguiente paso crearemos una varibale del tipo VARCHAR con la longitud maxima permitida por SQL Server, donde
			almacenaremos unicamente el registro de los encabezados.
		4.- Una vez guardados los encabezados realizaremos una conversión de XML donde la subconsulta convierte la cadena @LIST en un formato XML. 
			La función REPLACE reemplaza cada | en la cadena con </i><i>, y luego se envuelve la cadena resultante con <v><i> al inicio y </i></v> al final. 
			Esto crea un XML estructurado.
		5.- La cláusula CROSS APPLY se utiliza para aplicar la función nodes al XML generado. Esta función devuelve un conjunto de nodos XML que coinciden con la ruta //v/i.
		6.- Ahora construimos la lista de columnas la siguiente subconsulta selecciona los valores de la columna head de la tabla temporal #tableHeader, 
			eliminando los espacios en blanco al inicio y al final con LTRIM y RTRIM, y los envuelve con QUOTENAME para manejarlos como nombres de columnas. 
			Los valores se concatenan con comas , y se convierten a formato XML.
			6.1.- La función STUFF elimina el primer carácter (que es una coma extra) de la cadena resultante, dejando una lista de nombres de columnas separados por comas.
		7.- Construimos la consulta SELECT dinámica que selecciona las columnas especificadas en @COLUMNS y las inserta en una nueva tabla "Test_Table".
		8.- La subconsulta selecciona la columna head de #tableHeader y la renombra como headT. 
			Luego, se aplica la operación PIVOT para transformar los valores únicos de headT en columnas, utilizando MAX(headT) como función de agregación.
		9.- Finalmente, se ejecuta la consulta dinámica utilizando sp_executesql.
		
	Los siguientes archivos los puedes utilizar para realizar tus pruebas.	
		* //Ruta del Archivo Prueba/File_20Col.txt
		* //Ruta del Archivo Prueba/File_30Col.txt
		* //Ruta del Archivo Prueba/File_Col.txt
  &&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&
  */

  CREATE TABLE #DinamicTable(
	headers [VARCHAR] (MAX)
  )
  /*
	&&&&&&&&&&&&&&&&&&&&&&&&&&&&&
	Bulk de carga de encabezados:
	&&&&&&&&&&&&&&&&&&&&&&&&&&&&&
  */
  BEGIN TRY
    BULK INSERT #DinamicTable FROM '//Ruta del Archivo Prueba/File_20Col.txt'
  END TRY
  BEGIN CATCH
      SELECT ERROR_NUMBER(), ERROR_MESSAGE();
  END CATCH
  /*
	&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&
	Split por | para crear registro de cada campo:
	&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&
  */
  DECLARE @LIST VARCHAR(MAX) = (SELECT headers FROM #DinamicTable WHERE headers LIKE '1|X_cod_emp|F_int_art           |G_ean_art|H_ean_rel|I_enl_art|%');
	SELECT
		x.f.value( '.', 'varchar(50)' ) AS [head] INTO #tableHeader
	FROM ( 
		SELECT CAST ( '<v><i>' + REPLACE ( @LIST, '|', '</i><i>' ) + '</i></v>' AS XML ) AS x 
	) AS D
	CROSS APPLY x.nodes( '//v/i' ) x( f );
  /*
	&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&
	Transponer los registros a columnas a nuevas tablas para crear tablas dinamicas:
	&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&
  */
  DECLARE @COLUMNS AS NVARCHAR(MAX)
		 ,@Query AS NVARCHAR(MAX)

  SELECT @COLUMNS = STUFF((SELECT ',' + QUOTENAME(LTRIM(RTRIM(head))) FROM #tableHeader FOR XML PATH (''), TYPE).value('.','VARCHAR(MAX)'),1,1,'')
  SET @Query = N'SELECT ' + @COLUMNS + N' INTO Test_Table FROM (SELECT head As headT FROM #tableHeader) P PIVOT (MAX(headT) FOR headT IN (' + @COLUMNS + N')) AS PIVOT_TABLE'
  EXEC sp_executesql @Query
  
  SELECT 
	* 
   FROM Test_Table;
  
  DROP TABLE #DinamicTable;
  DROP TABLE #tableHeader;
  
  IF OBJECT_ID(N'dbo.Test_Table', N'U') IS NOT NULL  
	BEGIN
	   DROP TABLE [dbo].[Test_Table];  
	END
  
	RETURN
END