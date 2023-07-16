set -e
brew update

brew install md5sha1sum automake autogen doxygen

git clone https://github.com/microsoft/vcpkg.git
cd vcpkg
git checkout tags/2023.01.09
./bootstrap-vcpkg.sh
cd ..

VCPKG_TRIPLET=x64-osx

./vcpkg/vcpkg install libiconv:$VCPKG_TRIPLET
./vcpkg/vcpkg install zlib:$VCPKG_TRIPLET
./vcpkg/vcpkg install freetype:$VCPKG_TRIPLET
./vcpkg/vcpkg install libxml2:$VCPKG_TRIPLET
./vcpkg/vcpkg install leptonica:$VCPKG_TRIPLET
./vcpkg/vcpkg install tesseract:$VCPKG_TRIPLET
./vcpkg/vcpkg install boost-filesystem:$VCPKG_TRIPLET
./vcpkg/vcpkg install boost-system:$VCPKG_TRIPLET
./vcpkg/vcpkg install boost-signals2:$VCPKG_TRIPLET
./vcpkg/vcpkg install boost-config:$VCPKG_TRIPLET
./vcpkg/vcpkg install boost-dll:$VCPKG_TRIPLET
./vcpkg/vcpkg install boost-assert:$VCPKG_TRIPLET
./vcpkg/vcpkg install boost-smart-ptr:$VCPKG_TRIPLET

mkdir -p custom-triplets
cp ./vcpkg/triplets/community/$VCPKG_TRIPLET-dynamic.cmake custom-triplets/$VCPKG_TRIPLET.cmake
./vcpkg/vcpkg install podofo:$VCPKG_TRIPLET --overlay-triplets=custom-triplets

vcpkg_prefix="$PWD/vcpkg/installed/$VCPKG_TRIPLET"

deps_prefix="$PWD/deps"
mkdir -p $deps_prefix

wget -nc https://sourceforge.net/projects/htmlcxx/files/v0.87/htmlcxx-0.87.tar.gz
echo "ac7b56357d6867f649e0f1f699d9a4f0f03a6e80  htmlcxx-0.87.tar.gz" | shasum -c
tar -xzvf htmlcxx-0.87.tar.gz
cd htmlcxx-0.87
./configure CXXFLAGS=-std=c++17 LDFLAGS="-L$vcpkg_prefix/lib" LIBS="-liconv" CPPFLAGS="-I$vcpkg_prefix/include" --prefix="$deps_prefix"
sed -i.bak -e "s/\(allow_undefined=\)yes/\1no/" libtool
sed -i -r -e 's/css\/libcss_parser_pp.la \\//' Makefile
sed -i -r -e 's/css\/libcss_parser.la//' Makefile
sed -i '' -r -e 's/-DDEFAULT_CSS=\"\\\"\$\{datarootdir\}\/htmlcxx\/css\/default.css\\\"\"//' Makefile
sed -i -r -e 's/css\/libcss_parser_pp.la//' Makefile
sed -i -r -e 's/css//' Makefile
sed -i -e 's/throw (Exception)//' html/CharsetConverter.h
sed -i -e 's/throw (Exception)//' html/CharsetConverter.cc
echo 'int main() {}' > htmlcxx.cc
make -j4
make install-strip
cd ..
rm -rf htmlcxx-0.87

wget -nc http://silvercoders.com/download/3rdparty/libcharsetdetect-master.tar.bz2
echo "6f9adaf7b6130bee6cfac179e3406cdb933bc83f  libcharsetdetect-master.tar.bz2" | shasum -c
tar -xjvf libcharsetdetect-master.tar.bz2
cd libcharsetdetect-master
cmake -DCMAKE_CXX_STANDARD=17 -DBUILD_SHARED_LIBS=TRUE -DCMAKE_INSTALL_PREFIX:PATH="$deps_prefix" .
cmake --build . --config Release --target install
cd ..
rm -rf libcharsetdetect-master
rm libcharsetdetect-master.tar.bz2


git clone https://github.com/docwire/wv2.git
cd wv2
mkdir build
cd build
cmake -DCMAKE_CXX_STANDARD=17 -DCMAKE_BUILD_TYPE=Debug -DCMAKE_INSTALL_PREFIX:PATH="$deps_prefix" ..
make install
cd ..
wget http://silvercoders.com/download/3rdparty/wv2-0.2.3_patched_4-private_headers.tar.bz2
echo "6bb3959d975e483128623ee3bff3fba343f096c7  wv2-0.2.3_patched_4-private_headers.tar.bz2" | shasum -c
tar -xjvf wv2-0.2.3_patched_4-private_headers.tar.bz2
mv wv2-0.2.3_patched_4-private_headers/*.h $deps_prefix/include/wv2/
cd ..

wget -nc http://www.codesink.org/download/mimetic-0.9.7.tar.gz
echo "568557bbf040be2b17595431c9b0992c32fae6ed  mimetic-0.9.7.tar.gz" | shasum -c
tar -zxvf mimetic-0.9.7.tar.gz
wget -nc http://silvercoders.com/download/3rdparty/mimetic-0.9.7-patches.tar.gz
echo "7e203fb2b2d404ae356674e7dfc293e78fe3362b  mimetic-0.9.7-patches.tar.gz" | shasum -c
tar -xvzf mimetic-0.9.7-patches.tar.gz
cd mimetic-0.9.7
patch -p1 -i ../mimetic-0.9.7-patches/register_keyword.patch
patch -p1 -i ../mimetic-0.9.7-patches/ContTokenizer.patch
patch -p1 -i ../mimetic-0.9.7-patches/macro_string.patch
patch -p1 -i ../mimetic-0.9.7-patches/mimetic_pointer_comparison.patch
./configure CXXFLAGS=-std=c++17 --prefix="$deps_prefix"
make -j4
make install-strip
cd ..

git clone https://github.com/libyal/libbfio.git
cd libbfio
git checkout 3bb082c
./synclibs.sh
autoreconf -i
./configure --prefix="$deps_prefix"
make -j4
make install
cd ..

git clone https://github.com/libyal/libpff.git
cd libpff
git checkout 99a86ef
./synclibs.sh
touch ../../config.rpath
autoreconf -i
./configure --prefix="$deps_prefix"
make -j4
make install
cd ..

wget http://www.winimage.com/zLibDll/unzip101e.zip && \
unzip -d unzip101e unzip101e.zip && \
cd unzip101e && \
printf 'cmake_minimum_required(VERSION 3.7)\n' >> CMakeLists.txt
printf 'project(Unzip)\n' >> CMakeLists.txt
printf 'set(UNZIP_SRC ioapi.c unzip.c)\n' >> CMakeLists.txt
printf 'add_library(unzip STATIC ${UNZIP_SRC})\n' >> CMakeLists.txt
printf 'install(FILES unzip.h ioapi.h DESTINATION include)\n' >> CMakeLists.txt
printf 'install(TARGETS unzip DESTINATION lib)\n' >> CMakeLists.txt
printf 'target_compile_options(unzip PRIVATE -fPIC)\n' >> CMakeLists.txt
cmake -DCMAKE_CXX_STANDARD=17 -DCMAKE_INSTALL_PREFIX:PATH="$deps_prefix" -DCMAKE_CXX_FLAGS="-I$vcpkg_prefix/include" .
cmake --build .
cmake --install .
cd ..

wget http://silvercoders.com/download/3rdparty/cmapresources_korean1-2.tar.z
echo "e4e36995cff0331d8bd5ad00c1c1453c24ab4c07  cmapresources_korean1-2.tar.z" | sha1sum -c -
tar -xvf cmapresources_korean1-2.tar.z
mv ak12 $deps_prefix/share/

wget http://silvercoders.com/download/3rdparty/cmapresources_japan1-6.tar.z
echo "9467d7ed73c16856d2a49b5897fc5ea477f3a111  cmapresources_japan1-6.tar.z" | sha1sum -c -
tar -xvf cmapresources_japan1-6.tar.z
mv aj16 $deps_prefix/share/

wget http://silvercoders.com/download/3rdparty/cmapresources_gb1-5.tar.z
echo "56e6cbd9e053185f9e00118e54fd5159ca118b39  cmapresources_gb1-5.tar.z" | sha1sum -c -
tar -xvf cmapresources_gb1-5.tar.z
mv ag15 $deps_prefix/share/

wget http://silvercoders.com/download/3rdparty/cmapresources_cns1-6.tar.z
echo "80c92cc904c9189cb9611741b913ffd22bcd4036  cmapresources_cns1-6.tar.z" | sha1sum -c -
tar -xvf cmapresources_cns1-6.tar.z
mv ac16 $deps_prefix/share/

wget http://silvercoders.com/download/3rdparty/mappingresources4pdf_2unicode_20091116.tar.Z
echo "aaf44cb1e5dd2043c932e641b0e41432aee2ca0d  mappingresources4pdf_2unicode_20091116.tar.Z" | sha1sum -c -
tar -xvf mappingresources4pdf_2unicode_20091116.tar.Z
mv ToUnicode $deps_prefix/share/

mkdir -p build
cd build
cmake -DCMAKE_CXX_STANDARD=17 -DCMAKE_TOOLCHAIN_FILE=$PWD/../vcpkg/scripts/buildsystems/vcpkg.cmake \
	-DCMAKE_PREFIX_PATH="$deps_prefix" \
	..
cmake --build .
cmake --build . --target doxygen install
cd ..

cd build
mkdir -p tessdata
cd tessdata
wget -nc https://github.com/tesseract-ocr/tessdata_fast/raw/4.1.0/eng.traineddata
wget -nc https://github.com/tesseract-ocr/tessdata_fast/raw/4.1.0/osd.traineddata
wget -nc https://github.com/tesseract-ocr/tessdata_fast/raw/4.1.0/pol.traineddata
cd ..
cp $deps_prefix/lib/libwv2.4.dylib .
cp $vcpkg_prefix/lib/libpodofo.0.9.8.dylib .
cp $deps_prefix/lib/libhtmlcxx.3.dylib .
cp $deps_prefix/lib/libcharsetdetect.dylib .
cp $deps_prefix/lib/libmimetic.0.dylib .
cp $deps_prefix/lib/libbfio.1.dylib .
cp $deps_prefix/lib/libpff.1.dylib .
mkdir -p resources
cd resources
cp $deps_prefix/share/ac16/CMap/* .
cp $deps_prefix/share/ag15/CMap/* .
cp $deps_prefix/share/aj16/CMap/* .
cp $deps_prefix/share/ak12/CMap/* .
cp $deps_prefix/share/ToUnicode/* .
cd ..
cd ..

cd build/tests
DYLD_FALLBACK_LIBRARY_PATH=.. ctest -j4 -V
cd ../..

build_type=$1
if [ "$build_type" = "--release" ]; then
	rm -rf build/CMakeFiles build/src build/tests/ build/examples/CMakeFiles build/doc/CMakeFiles
	rm build/Makefile build/CMakeCache.txt build/cmake_install.cmake build/install_manifest.txt build/examples/cmake_install.cmake build/examples/Makefile build/doc/Makefile build/doc/cmake_install.cmake build/doc/Doxyfile.doxygen
fi

cd build/
for i in *.dylib*; do
    [ -f "$i" ] || break
    sha1sum $i >> SHA1checksums.sha1
done
cd ..

version=`cat build/VERSION`

tar -cjvf doctotext-$version-osx.tar.bz2 build
sha1sum doctotext-$version-osx.tar.bz2 > doctotext-$version-osx.tar.bz2.sha1
