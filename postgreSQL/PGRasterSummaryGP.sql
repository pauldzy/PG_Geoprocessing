CREATE OR REPLACE FUNCTION dz.PGRasterSummaryGP(
    IN  pGeometry              geometry
   ,OUT pReturnCode            NUMERIC
   ,OUT pStatusMessage         VARCHAR
   ,OUT pPopulation            INTEGER
)
AS
$BODY$ 
DECLARE
   sdo_geog       geography;
   sdo_geom       geometry;
   curs_results   REFCURSOR;
   rec_result     RECORD;
   rast_clip      raster;
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
   -- Open cursor of results
   --------------------------------------------------------------------------
   OPEN curs_results FOR
   SELECT
    a.rid 
   ,a.rast
   ,ST_Within(a.shape::geometry,sdo_geom) AS boo_within
   ,a.total_population
   FROM
   dz.pop2012_rdt a
   WHERE
   ST_Intersects(a.shape,sdo_geog);

   --------------------------------------------------------------------------
   -- Step 30
   -- Step through cursor
   --------------------------------------------------------------------------
   pPopulation := 0;
   
   LOOP 
      FETCH curs_results INTO rec_result; 
      EXIT WHEN NOT FOUND;

      IF rec_result.boo_within
      THEN
         pPopulation := pPopulation + rec_result.total_population;

      ELSE
         rast_clip := ST_Clip(
             rec_result.rast
            ,sdo_geom
            ,false
         );

         r := ST_SummaryStats(rast_clip,true);

         IF r.sum IS NOT NULL AND r.sum > 0
         THEN
            pPopulation := pPopulation + r.sum;

         END IF;
         
      END IF;
      
   END LOOP; 
   
   CLOSE curs_results;
     
   --------------------------------------------------------------------------
   -- Step 70
   -- Exit
   --------------------------------------------------------------------------
   RETURN;
   
END;
$BODY$
LANGUAGE plpgsql;

ALTER FUNCTION dz.PGRasterSummaryGP(
    geometry
) OWNER TO dz;

GRANT EXECUTE ON FUNCTION dz.PGRasterSummaryGP(
    geometry
) TO PUBLIC;
