# PostGIS Geocoder Installation

Based on steps here:

```
CREATE EXTENSION postgis;
CREATE EXTENSION fuzzystrmatch;
CREATE EXTENSION postgis_tiger_geocoder;
--this one is optional if you want to use the rules based standardizer (pagc_normalize_address)
CREATE EXTENSION address_standardizer;

ALTER EXTENSION postgis UPDATE;
ALTER EXTENSION postgis_tiger_geocoder UPDATE;
```

```
SELECT na.address, na.streetname,na.streettypeabbrev, na.zip
	FROM normalize_address('1 Devonshire Place, Boston, MA 02109') AS na;
```

```
INSERT INTO tiger.loader_platform(os, declare_sect, pgbin, wget, unzip_command, psql, path_sep,
		   loader, environ_set_command, county_process_command)
SELECT 'debbie', declare_sect, pgbin, wget, unzip_command, psql, path_sep,
	   loader, environ_set_command, county_process_command
  FROM tiger.loader_platform
  WHERE os = 'sh';
```

```
# OPTIONAL?
UPDATE tiger.loader_lookuptables SET load = true WHERE table_name = 'zcta520';
```

```
psql -U postgresuser -c "SELECT Loader_Generate_Nation_Script('debbie')" -d inventory -tA > /gisdata/nation_script_load.sh
```

```
cd /gisdata
sh nation_script_load.sh
```

```
SELECT count(*) FROM tiger_data.county_all;
```

```
# OPTIONAL
# UPDATE tiger.loader_lookuptables SET load = true WHERE load = false AND lookup_name IN('tract', 'bg', 'tabblock');
```

```
sh ma_load.sh
```

### Testing
See https://postgis.net/docs/Geocode.html for more examples.

```SELECT g.rating, ST_AsText(ST_SnapToGrid(g.geomout,0.00001)) As wktlonlat,
(addy).address As stno, (addy).streetname As street,
(addy).streettypeabbrev As styp, (addy).location As city, (addy).stateabbrev As st,(addy).zip
FROM geocode('424 3rd St, Bedford, MA',1) As g;```

