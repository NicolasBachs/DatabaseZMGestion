DROP PROCEDURE IF EXISTS `zsp_producto_crear`;

DELIMITER $$
CREATE PROCEDURE `zsp_producto_crear`(pIn JSON)
SALIR:BEGIN
    /*
        Procedimiento que permite crear un producto. Controla que no exista uno con el mismo nombre y que pertenezca a la misma catgoria y grupo de productos, que la longitud de tela necesaria
        sea mayor o igual que cero, que existan la categoeria, el grupo y el tipo de producto, y que el precio sea mayor que cero.
        Devuelve el producto con su precio en 'respuesta' o el error en 'error'.
    */

    -- Control de permisos
    DECLARE pUsuariosEjecuta JSON;
    DECLARE pIdUsuarioEjecuta smallint;
    DECLARE pToken varchar(256);
    DECLARE pMensaje text;

    -- Producto a crear
    DECLARE pProductos JSON;
    DECLARE pIdProducto int;
    DECLARE pIdCategoriaProducto tinyint;
    DECLARE pIdGrupoProducto tinyint;
    DECLARE pIdTipoProducto char(1);
    DECLARE pProducto varchar(80);
    DECLARE pLongitudTela decimal(10,2);
    DECLARE pObservaciones varchar(255);

    -- Precio del producto
    DECLARE pPrecios JSON;
    DECLARE pPrecio decimal(10,2);

    -- Para la respuesta
    DECLARE pRespuesta JSON;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        SHOW ERRORS;
        SELECT f_generarRespuesta("ERROR_TRANSACCION", NULL) pOut;
        ROLLBACK;
	END;

    SET pUsuariosEjecuta = pIn ->> "$.UsuariosEjecuta";
    SET pToken = pUsuariosEjecuta ->> "$.Token";

    CALL zsp_usuario_tiene_permiso(pToken, 'zsp_producto_crear', pIdUsuarioEjecuta, pMensaje);
    IF pMensaje != 'OK' THEN
        SELECT f_generarRespuesta(pMensaje, NULL) pOut;
        LEAVE SALIR;
    END IF;

    -- Extraigo atributos del Producto
    SET pProductos = pIn ->> "$.Productos";
    SET pProducto = pProductos ->> "$.Producto";
    SET pIdCategoriaProducto = pProductos ->> "$.IdCategoriaProducto";
    SET pIdGrupoProducto = pProductos ->> "$.IdGrupoProducto";
    SET pIdTipoProducto = pProductos ->> "$.IdTipoProducto";
    SET pLongitudTela = pProductos ->> "$.LongitudTela";
    SET pObservaciones = pProductos ->> "$.Observaciones";

    -- Extraigo atributos de Precio
    SET pPrecios = pIn ->> "$.Precios";
    SET pPrecio = pPrecios ->> "$.Precio";

    IF pProducto IS NULL OR pProducto = '' THEN 
        SELECT f_generarRespuesta("ERROR_INGRESAR_PRODUCTO", NULL) pOut;
        LEAVE SALIR;
    END IF;

    IF pIdCategoriaProducto IS NULL OR NOT EXISTS (SELECT IdCategoriaProducto FROM CategoriasProducto WHERE IdCategoriaProducto = pIdCategoriaProducto) THEN
        SELECT f_generarRespuesta("ERROR_NOEXISTE_CATEGORIAPRODUCTO", NULL) pOut;
        LEAVE SALIR;
    END IF;

    IF (pIdGrupoProducto IS NULL OR NOT EXISTS (SELECT IdGrupoProducto FROM GruposProducto WHERE IdGrupoProducto = pIdGrupoProducto AND Estado = 'A')) THEN
        SELECT f_generarRespuesta("ERROR_NOEXISTE_GRUPOPRODUCTO", NULL) pOut;
        LEAVE SALIR;
    END IF;

    IF EXISTS (SELECT IdProducto FROM Productos WHERE Producto = pProducto AND IdCategoriaProducto = pIdCategoriaProducto AND IdGrupoProducto = pIdGrupoProducto) THEN
        SELECT f_generarRespuesta("ERROR_EXISTE_PRODUCTO", NULL) pOut;
        LEAVE SALIR;
    END IF;

    IF pLongitudTela < 0 THEN
        SELECT f_generarRespuesta("ERROR_INVALIDA_LONGITUDTELA", NULL) pOut;
        LEAVE SALIR;
    END IF;

    IF NOT EXISTS (SELECT IdTipoProducto FROM TiposProducto WHERE IdTipoProducto = pIdTipoProducto) THEN
        SELECT f_generarRespuesta("ERROR_INVALIDO_TIPOPRODUCTO", NULL) pOut;
        LEAVE SALIR;
    END IF;

    IF pPrecio IS NULL THEN
        SELECT f_generarRespuesta("ERROR_INGRESAR_PRECIO", NULL) pOut;
        LEAVE SALIR;
    END IF;

    IF pPrecio < 0.00 THEN
        SELECT f_generarRespuesta("ERROR_INVALIDO_PRECIO", NULL) pOut;
        LEAVE SALIR;
    END IF;

    START TRANSACTION;
    
    INSERT INTO Productos (IdProducto, IdCategoriaProducto, IdGrupoProducto, IdTipoProducto, Producto, LongitudTela, FechaAlta, FechaBaja, Observaciones, Estado) VALUES (0, pIdCategoriaProducto, pIdGrupoProducto, pIdTipoProducto, pProducto, pLongitudTela, NOW(), NULL, NULLIF(pObservaciones, ''), 'A');
    SET pIdProducto = (SELECT IdProducto FROM Productos WHERE Producto = pProducto AND IdCategoriaProducto = pIdCategoriaProducto AND IdGrupoProducto = pIdGrupoProducto);
    INSERT INTO Precios (IdPrecio, Precio, Tipo, IdReferencia, FechaAlta) VALUES(0, pPrecio, 'P', pIdProducto, NOW());

    SET pRespuesta = (
			SELECT CAST(
                JSON_OBJECT(
                    "Productos",  JSON_OBJECT(
                        'IdProducto', p.IdProducto,
                        'IdCategoriaProducto', p.IdCategoriaProducto,
                        'IdGrupoProducto', p.IdGrupoProducto,
                        'IdTipoProducto', p.IdTipoProducto,
                        'Producto', p.Producto,
                        'LongitudTela', p.LongitudTela,
                        'FechaAlta', p.FechaAlta,
                        'FechaBaja', p.FechaBaja,
                        'Observaciones', p.Observaciones,
                        'Estado', p.Estado
                        ),
                    "Precios", JSON_OBJECT(
                        'IdPrecio', ps.IdPrecio,
                        'Precio', ps.Precio,
                        'FechaAlta', ps.FechaAlta
                    ) 
                )
             AS JSON)
			FROM	Productos p
            INNER JOIN Precios ps ON (ps.Tipo = 'P' AND p.IdProducto = ps.IdReferencia)
			WHERE	p.IdProducto = pIdProducto
        );
	
		SELECT f_generarRespuesta(NULL, pRespuesta) AS pOut;

    COMMIT;
END $$
DELIMITER ;
