CREATE TYPE dz.gadm_level2 AS (
    county_district    VARCHAR
   ,admin_type         VARCHAR
);

CREATE TYPE dz.gadm_level1 AS (
    state_province     VARCHAR
   ,admin_type         VARCHAR
   ,counties_districts dz.gadm_level2[]
);

CREATE TYPE dz.gadm_level0 AS (
    country            VARCHAR
   ,states_provinces   dz.gadm_level1[]
);
