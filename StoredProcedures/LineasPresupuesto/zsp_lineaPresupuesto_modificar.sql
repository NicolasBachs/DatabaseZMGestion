DROP PROCEDURE IF EXISTS `zsp_lineaPresupuesto_modificar`;

DELIMITER $$
CREATE PROCEDURE `zsp_lineaPresupuesto_modificar`(pIn JSON)
SALIR:BEGIN
    /*
        Procedimiento que permite modificar una linea de presupuesto. 
        Controla que la linea de presupuesto este en estado 'Pendiente', que exista el cliente para el cual se le esta creando, la ubicación donde se esta realizando y el usuario que lo está creando.
        Devuelve el presupuesto en 'respuesta' o el error en 'error'.
    */

    -- Control de permisos
    DECLARE pUsuariosEjecuta JSON;
    DECLARE pIdUsuarioEjecuta smallint;
    DECLARE pToken varchar(256);
    DECLARE pMensaje text;

    -- Linea de presupuesto a crear
    DECLARE pLineasProducto JSON;
    DECLARE pIdLineaProducto bigint;
    DECLARE pIdPresupuesto int;
    DECLARE pIdProductoFinal int;
    DECLARE pPrecioUnitario decimal(10,2);
    DECLARE pCantidad tinyint;

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

    CALL zsp_usuario_tiene_permiso(pToken, 'zsp_lineaPresupuesto_crear', pIdUsuarioEjecuta, pMensaje);
    IF pMensaje != 'OK' THEN
        SELECT f_generarRespuesta(pMensaje, NULL) pOut;
        LEAVE SALIR;
    END IF;

    -- Extraigo atributos de la linea de presupuesto
    SET pLineasProducto = pIn ->> "$.LineasProducto";
    SET pIdPresupuesto = pLineasProducto ->> "$.IdReferencia";
    SET pIdLineaProducto = pLineasProducto ->> "$.IdLineaProducto";
    SET pIdProductoFinal = pLineasProducto ->> "$.IdProductoFinal";
    SET pPrecioUnitario = pLineasProducto ->> "$.PrecioUnitario";
    SET pCantidad = pLineasProducto ->> "$.Cantidad";

    IF pIdLineaProducto IS NULL OR NOT EXISTS (SELECT IdLineaProducto FROM LineasProducto WHERE IdLineaProducto = pIdLineaProducto) THEN
        SELECT f_generarRespuesta("ERROR_NOEXISTE_LINEAPRESUPUESTO", NULL) pOut;
        LEAVE SALIR;
    END IF;

    IF pIdProductoFinal IS NULL OR NOT EXISTS (SELECT IdProductoFinal FROM ProductosFinales WHERE IdProductoFinal = pIdProductoFinal) THEN
        SELECT f_generarRespuesta("ERROR_NOEXISTE_PRODUCTOFINAL", NULL) pOut;
        LEAVE SALIR;
    END IF;

    IF EXISTS (SELECT IdProductoFinal FROM LineasProducto WHERE IdReferencia = pIdPresupuesto AND Tipo = 'P' AND IdProductoFinal = pIdProductoFinal AND IdLineaProducto <> pIdLineaProducto) THEN
        SELECT f_generarRespuesta("ERROR_PRESUPUESTO_EXISTE_PRODUCTOFINAL", NULL) pOut;
        LEAVE SALIR;
    END IF;


    IF pCantidad <= 0  OR pCantidad IS NULL THEN
        SELECT f_generarRespuesta("ERROR_CANTIDAD_INVALIDA", NULL) pOut;
        LEAVE SALIR;
    END IF;

    IF pPrecioUnitario <= 0.00 OR pPrecioUnitario IS NULL THEN
        SELECT f_generarRespuesta("ERROR_INVALIDO_PRECIO", NULL) pOut;
        LEAVE SALIR;
    END IF;

    CALL zsp_usuario_tiene_permiso(pToken, 'modificar_precio_presupuesto', pIdUsuarioEjecuta, pMensaje);
    IF pMensaje != 'OK' THEN
        SELECT f_calcularPrecioProductoFinal(pIdProductoFinal) INTO pPrecioUnitario;
    END IF;

    START TRANSACTION;

    UPDATE LineasProducto
    SET IdProductoFinal = pIdLineaProducto,
        PrecioUnitario = pPrecioUnitario,
        Cantidad = pCantidad
    WHERE IdLineaProducto = pIdLineaProducto;

    SET pRespuesta = (
			SELECT CAST(
                JSON_OBJECT(
                    "LineasProducto",  JSON_OBJECT(
                        'IdLineaProducto', lp.IdLineaProducto,
                        'IdLineaProductoPadre', lp.IdLineaProductoPadre,
                        'IdProductoFinal', lp.IdProductoFinal,
                        'IdUbicacion', lp.IdUbicacion,
                        'IdReferencia', lp.IdReferencia,
                        'Tipo', lp.Tipo,
                        'PrecioUnitario', lp.PrecioUnitario,
                        'Cantidad', lp.Cantidad,
                        'FechaAlta', lp.FechaAlta,
                        'FechaCancelacion', lp.FechaCancelacion,
                        'Estado', lp.Estado
                    ) 
                )
             AS JSON)
			FROM	LineasProducto lp
			WHERE	lp.IdLineaProducto = pIdLineaProducto
        );
		SELECT f_generarRespuesta(NULL, pRespuesta) AS pOut;

    COMMIT;
END $$
DELIMITER ;
