#!/bin/bash

RENDER_ACCOUNT=$(whoami)
INSTALL_DIRECTORY=$(pwd)

MISCELLANEOUS_DEP="libboost-all-dev git-core tar unzip wget bzip2 build-essential autoconf libtool libxml2-dev libgeos-dev libgeos++-dev libpq-dev libbz2-dev libproj-dev munin-node munin libprotobuf-c0-dev protobuf-c-compiler libfreetype6-dev libpng12-dev libtiff5-dev libicu-dev libgdal-dev libcairo-dev libcairomm-1.0-dev apache2 apache2-dev libagg-dev liblua5.2-dev ttf-unifont lua5.1 liblua5.1-dev libgeotiff-epsg"
POSTGRES_DEP="postgresql postgresql-contrib postgis postgresql-9.5-postgis-2.2"
OSM_DEP="make cmake g++ libboost-dev libboost-system-dev libboost-filesystem-dev libexpat1-dev zlib1g-dev libbz2-dev libpq-dev libgeos-dev libgeos++-dev libproj-dev lua5.2 liblua5.2-dev"
MAPNIK_DEP="autoconf apache2-dev libtool libxml2-dev libbz2-dev libgeos-dev libgeos++-dev libproj-dev gdal-bin libgdal1-dev libmapnik-dev mapnik-utils python-mapnik"
FONTS_DEP="fonts-noto-cjk fonts-noto-hinted fonts-noto-unhinted ttf-unifont"

echo "INSTALLING DEPENDENCIES"
echo "=================================="
sudo apt -q install -y $MISCELLANEOS_DEP

echo "INSTALLING POSTGRES"
echo "=================================="
sudo apt -q install -y $POSTGRES_DEP

echo "SETTING UP USER / DATABASE"
echo "=================================="
sudo su - postgres -c "createuser $RENDER_ACCOUNT"
sudo su - postgres -c "createdb -E UTF8 -O $RENDER_ACCOUNT gis"
sudo su - postgres -c "psql gis -c 'CREATE EXTENSION postgis;'"
sudo su - postgres -c "psql gis -c 'CREATE EXTENSION hstore;'"
sudo su - postgres -c "psql gis -c \"ALTER TABLE spatial_ref_sys OWNER TO $RENDER_ACCOUNT;\""

echo "INSTALLING osm2pgsql"
echo "=================================="
if [ ! -d "src" ]; then
	mkdir "./src"
fi

cd "./src"

if [ ! -d "osm2pgsql" ]; then
	git clone git://github.com/openstreetmap/osm2pgsql.git
fi

cd "./osm2pgsql"
sudo apt -q install -y $OSM_DEP

mkdir build
cd build
cmake ..
make && sudo make install

echo "INSTALLING mapnik / mod_tile"
echo "=================================="
sudo apt install -y $MAPNIK_DEP
cd "$INSTALL_DIRECTORY/src"
if [ ! -d "mod_tile" ]; then
	git clone -b switch2osm git://github.com/SomeoneElseOSM/mod_tile.git
fi
cd mod_tile
./autogen.sh
./configure
make
sudo make install
sudo make install-mod_tile
sudo ldconfig

echo "INSTALLING carto"
echo "=================================="
cd $INSTALL_DIRECTORY

if [ ! -d "$INSTALL_DIRECTORY/src/openstreetmap-carto" ]; then
	git clone git://github.com/gravitystorm/openstreetmap-carto.git
fi

cd "$INSTALL_DIRECTORY/src/openstreetmap-carto"
if [ -f "mapnik.xml" ]; then
	echo "FILE mapnik.xml NOT FOUND !"
	echo "EXIT"
	return 1
	# sudo apt -q install -y npm nodejs-legacy
	# sudo npm install -g carto
	# carto project.mml > mapnik.xml
fi
	


cd $INSTALL_DIRECTORY
if [ ! -f "algeria-latest.osm" ]; then
	echo "CAN'T FIND .osm FILE !"
	echo "EXIT"
	return 1
fi

echo "STORING OSM TO DATABASE"
echo "=================================="
osm2pgsql -d gis --create --slim  -G --hstore --tag-transform-script "$INSTALL_DIRECTORY/src/openstreetmap-carto/openstreetmap-carto.lua" -C 2500 --number-processes 1 -S "$INSTALL_DIRECTORY/src/openstreetmap-carto/openstreetmap-carto.style" "$INSTALL_DIRECTORY/algeria-latest.osm"

if [ ! -d "$INSTALL_DIRECTORY/src/openstreetmap-carto/data" ]; then
	cd $INSTALL_DIRECTORY
	./src/openstreetmap-carto/scripts/get-shapefiles.py
fi


echo "INSTALLING FONTS"
echo "=================================="
sudo apt -qq install -y $FONTS_DEP



echo "EDITING /usr/local/etc/renderd.conf"
echo "=================================="
sudo sed -i "s/XML=.*/XML=$(echo $INSTALL_DIRECTORY | sed 's=/=\\/=g')\/src\/openstreetmap-carto\/mapnik.xml/g" /usr/local/etc/renderd.conf

echo "CONFIGURING apache SERVER"
echo "=================================="
sudo mkdir /var/lib/mod_tile
sudo chown "$RENDER_ACCOUNT" /var/lib/mod_tile
sudo mkdir /var/run/renderd
sudo chown "$RENDER_ACCOUNT" /var/run/renderd

sudo sh -c 'echo "LoadModule tile_module /usr/lib/apache2/modules/mod_tile.so" > /etc/apache2/conf-available/mod_tile.conf'

sudo a2enconf mod_tile

sudo awk -i inplace '1;/ServerAdmin webmaster@localhost/{
	print "";
	print "# Next lines are added by me ########################";
	print "LoadTileConfigFile /usr/local/etc/renderd.conf";
	print "ModTileRenderdSocketName /var/run/renderd/renderd.sock";
	print "# Timeout before giving up for a tile to be rendered";
	print "ModTileRequestTimeout 0";
	print "# Timeout before giving up for a tile to be rendered that is otherwise missing";
	print "ModTileMissingRequestTimeout 30";
	print "";
}' /etc/apache2/sites-available/000-default.conf

sudo service nginx stop
sudo service apache2 restart
sudo service apache2 reload

echo "=================================="
echo "DONE !"
echo "=================================="