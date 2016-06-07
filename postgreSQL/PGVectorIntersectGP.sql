CREATE OR REPLACE FUNCTION dz.PGVectorIntersectGP(
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
   curs_results   REFCURSOR;
   rec_result     RECORD;
   str_name_0     VARCHAR := NULL;
   int_index_0    INTEGER := 0;
   str_name_1     VARCHAR := NULL;
   int_index_1    INTEGER := 0;
   str_name_2     VARCHAR := NULL;
   int_index_2    INTEGER := 0;
   ary_tree       dz.gadm_level0[];
   rec_level0     dz.gadm_level0;
   rec_level1     dz.gadm_level1;
   rec_level2     dz.gadm_level2;
   dumrec_level0  dz.gadm_level0;
   dumrec_level1  dz.gadm_level1;
   dumrec_level2  dz.gadm_level2;
   dumary_level0  dz.gadm_level0[];
   dumary_level1  dz.gadm_level1[];
   dumary_level2  dz.gadm_level2[];
   
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
    a.name_0
   ,a.name_1
   ,a.name_2
   ,a.engtype_1
   ,a.engtype_2 
   FROM
   dz.vector_layer a
   WHERE
   ST_Intersects(a.shape,sdo_geog)
   ORDER BY
    a.name_0
   ,a.name_1
   ,a.name_2;

   --------------------------------------------------------------------------
   -- Step 30
   -- Step through cursor
   --------------------------------------------------------------------------
   LOOP 
      FETCH curs_results INTO rec_result; 
      EXIT WHEN NOT FOUND;

      IF str_name_0 IS NULL 
      OR str_name_0 != rec_result.name_0
      THEN
         --raise notice '|%| |%| |%|',int_index_0,str_name_0,rec_result.name_0;
         int_index_0 := int_index_0 + 1; 
         int_index_1 := 0;
         int_index_2 := 0;
         
         rec_level0.country := rec_result.name_0;
         rec_level0.states_provinces := dumary_level1;
         
         ary_tree := array_append(
             ary_tree
            ,rec_level0
         );
         
         str_name_0 := rec_result.name_0;
        
      END IF;
         
      IF  rec_result.name_1 IS NOT NULL AND rec_result.name_1 != '' 
      AND (str_name_1 IS NULL OR str_name_1 != rec_result.name_1)
      THEN
      
         int_index_1 := int_index_1 + 1;
         int_index_2 := 0;
         
         rec_level1.state_province := rec_result.name_1;
         rec_level1.admin_type := rec_result.engtype_1;
         rec_level1.counties_districts := dumary_level2;
         
         dumrec_level0 := ary_tree[int_index_0];
         
         dumrec_level0.states_provinces := array_append(
             ary_tree[int_index_0].states_provinces
            ,rec_level1
         );
         
         ary_tree[int_index_0] := dumrec_level0;
         
         str_name_1 := rec_result.name_1;
         
      END IF;
         
      IF rec_result.name_2 IS NOT NULL AND rec_result.name_2 != ''
      AND (str_name_2 IS NULL OR str_name_2 != rec_result.name_2)
      THEN
      
         int_index_2 :=  int_index_2 + 1;
         
         rec_level2.county_district := rec_result.name_2;
         rec_level2.admin_type := rec_result.engtype_2;

         dumrec_level0 := ary_tree[int_index_0];
         
         dumrec_level1 := ary_tree[int_index_0].states_provinces[int_index_1];
         
         dumrec_level1.counties_districts := array_append(
             ary_tree[int_index_0].states_provinces[int_index_1].counties_districts
            ,rec_level2
         );

         dumrec_level0.states_provinces[int_index_1] := dumrec_level1; 
         ary_tree[int_index_0] := dumrec_level0;
         
         str_name_2 := rec_result.name_2;
         
      END IF;
      
   END LOOP; 
   
   CLOSE curs_results;
   
   --------------------------------------------------------------------------
   -- Step 40
   -- Convert into JSON for output
   --------------------------------------------------------------------------
   pOutput := '[';

   FOR i IN 1 .. array_length(ary_tree,1)
   LOOP
      raise notice '%',ary_tree[i].country;

      pOutput := pOutput || '{"country":"' || ary_tree[i].country || '"';

      IF array_length(ary_tree[i].states_provinces,1) > 0
      THEN
         pOutput := pOutput || ',"states_provinces":[';

      END IF;
      
      FOR j IN 1 .. array_length(ary_tree[i].states_provinces,1)
      LOOP
         raise notice '   %',ary_tree[i].states_provinces[j].state_province;

         pOutput := pOutput || '{"state_province":"' || ary_tree[i].states_provinces[j].state_province || '"';
         pOutput := pOutput || ',"type":"' || ary_tree[i].states_provinces[j].admin_type || '"';

         IF array_length(ary_tree[i].states_provinces[j].counties_districts,1) > 0
         THEN
            pOutput := pOutput || ',"counties_districts":[';

         END IF;

         FOR k IN 1 .. array_length(ary_tree[i].states_provinces[j].counties_districts,1)
         LOOP
            raise notice '      %',ary_tree[i].states_provinces[j].counties_districts[k].county_district;

            pOutput := pOutput || '{"county_district":"' || ary_tree[i].states_provinces[j].counties_districts[k].county_district || '"';
            pOutput := pOutput || ',"type":"' || ary_tree[i].states_provinces[j].counties_districts[k].admin_type || '"}';

            IF k < array_length(ary_tree[i].states_provinces[j].counties_districts,1)
            THEN
               pOutput := pOutput || ',';
               
            END IF;
            
         END LOOP;

         IF array_length(ary_tree[i].states_provinces[j].counties_districts,1) > 0
         THEN
            pOutput := pOutput || ']';
            
         END IF;

         pOutput := pOutput || '}';

         IF j < array_length(ary_tree[i].states_provinces,1)
         THEN
            pOutput := pOutput || ',';
            
         END IF;

      END LOOP;

      IF array_length(ary_tree[i].states_provinces,1) > 0
      THEN
         pOutput := pOutput || ']';

      END IF;

      pOutput := pOutput || '}';

      IF i < array_length(ary_tree,1)
      THEN
         pOutput := pOutput || ',';
         
      END IF;
      
   END LOOP;

   pOutput := pOutput || ']';
     
   --------------------------------------------------------------------------
   -- Step 50
   -- Exit
   --------------------------------------------------------------------------
   RETURN;
   
END;
$BODY$
LANGUAGE plpgsql;

ALTER FUNCTION dz.PGVectorIntersectGP(
   geometry
) OWNER TO dz;

GRANT EXECUTE ON FUNCTION dz.PGVectorIntersectGP(
    geometry
) TO PUBLIC;
