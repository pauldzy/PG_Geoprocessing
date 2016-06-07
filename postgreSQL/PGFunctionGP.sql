CREATE OR REPLACE FUNCTION dz.PGFunctionGP(
    IN  pGeometry            geometry
   ,OUT pReturnCode          NUMERIC
   ,OUT pStatusMessage       VARCHAR
   ,OUT pOutput              VARCHAR
)
AS
$BODY$ 
DECLARE
   
   sdo_geog       geography;
   sdo_geom       geometry;
   str_vector     VARCHAR;
   str_raster     VARCHAR;
   r              RECORD;
   
BEGIN
   
   --------------------------------------------------------------------------
   -- Step 10
   -- Check over incoming parameters
   --------------------------------------------------------------------------
   pReturnCode := 0;
   
   IF pGeometry IS NULL
   THEN
      pReturnCode    := -1;
      pStatusMessage := 'Input geometry is NULL, no results possible.';
      RETURN;
      
   END IF;
   
   IF ST_GeometryType(pGeometry) NOT IN ('ST_Polygon','ST_MultiPolygon')
   THEN
      pReturnCode    := -2;
      pStatusMessage := 'input geometry must be polygon';
      RETURN;
      
   END IF;

   IF ST_SRID(pGeometry) = 4326
   THEN
      sdo_geom := pGeometry;
      sdo_geog := pGeometry::geography;
      
   ELSE
      sdo_geom := ST_Transform(pGeometry,4326);
      sdo_geog := sdo_geom::geography;
   
   END IF;
   
   --------------------------------------------------------------------------
   -- Step 20
   -- Process the vector intersection
   --------------------------------------------------------------------------
   r := dz.PGVectorIntersectGP(
      sdo_geom
   );
   
   pReturnCode    := r.pReturnCode;
   pStatusMessage := r.pStatusMessage;
   str_vector     := r.pOutput;
   
   IF pReturnCode <> 0
   THEN
      RETURN;
   
   END IF;
   
   --------------------------------------------------------------------------
   -- Step 30
   -- Process the raster summary
   --------------------------------------------------------------------------
   r := dz.PGRasterSummaryGP(
      sdo_geom
   );
   
   pReturnCode    := r.pReturnCode;
   pStatusMessage := r.pStatusMessage;
   str_raster     := r.pOutput;
   
   IF pReturnCode <> 0
   THEN
      RETURN;
   
   END IF;
   
   --------------------------------------------------------------------------
   -- Step 40
   -- Combine the output
   --------------------------------------------------------------------------
   pOutput := '{';
   
   pOutput := pOutput || '"vectorIntersection":' || str_vector;
   
   pOutput := pOutput || ',"rasterSummary":' || str_raster;
   
   pOutput := pOutput || '}';
   
   --------------------------------------------------------------------------
   -- Step 50
   -- Exit
   --------------------------------------------------------------------------
   RETURN;
   
END;
$BODY$
LANGUAGE plpgsql;

ALTER FUNCTION dz.PGFunctionGP(
    geometry
) OWNER TO dz;

GRANT EXECUTE ON FUNCTION dz.PGFunctionGP(
    geometry
) TO PUBLIC;
