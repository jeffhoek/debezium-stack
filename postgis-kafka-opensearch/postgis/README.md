# PostGIS Geocoder Installation

Based on section [2.4.1. Tiger Geocoder Enabling your PostGIS database: Using Extension](https://postgis.net/docs/postgis_installation.html#install_tiger_geocoder_extension):

Launch psql:
```
docker compose exec -it postgres psql -U postgresuser inventory
```

Install the extension:
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

Create loader_platform entry:
```
INSERT INTO tiger.loader_platform(os, declare_sect, pgbin, wget, unzip_command, psql, path_sep,
		   loader, environ_set_command, county_process_command)
SELECT 'debbie', declare_sect, pgbin, wget, unzip_command, psql, path_sep,
	   loader, environ_set_command, county_process_command
  FROM tiger.loader_platform
  WHERE os = 'sh';
```

Update declare_sect tiger.loader_platform where os='debbie'
```
TBD (use PGAdmin and loader_datatable.txt)
```

Zip code-5 digit tabulation area (optional)
```
UPDATE tiger.loader_lookuptables SET load = true WHERE table_name = 'zcta520';
```

Generate national load script:
```
psql -U postgresuser -c "SELECT Loader_Generate_Nation_Script('debbie')" -d inventory -tA > /gisdata/nation_script_load.sh
```

Run the script:
```
cd /gisdata
sh nation_script_load.sh
```

Check counts:
```
SELECT count(*) FROM tiger_data.county_all;
```

for population statistics (optional)
```
UPDATE tiger.loader_lookuptables SET load = true WHERE load = false AND lookup_name IN('tract', 'bg', 'tabblock');
```

Generate script for loading MS:
```
psql -U postgresuser -c "SELECT Loader_Generate_Script(ARRAY['MA'], 'debbie')" -d inventory -tA > /gisdata/ma_load.sh
```

Run the script:
```
sh ma_load.sh
```

Check disk space:
```
du -sh postgis/gisdata && du -sh pgdata
919M	postgis/gisdata
2.1G	pgdata
```


### Testing
See https://postgis.net/docs/Geocode.html for more examples.

```SELECT g.rating, ST_AsText(ST_SnapToGrid(g.geomout,0.00001)) As wktlonlat,
(addy).address As stno, (addy).streetname As street,
(addy).streettypeabbrev As styp, (addy).location As city, (addy).stateabbrev As st,(addy).zip
FROM geocode('424 3rd St, Bedford, MA',1) As g;```

