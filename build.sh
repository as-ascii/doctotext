set -e

if [[ "$OSTYPE" == "darwin"* ]]; then
	brew install md5sha1sum automake autogen doxygen
elif [[ "$OSTYPE" == "linux"* ]]; then
	if [[ "$GITHUB_ACTIONS" == "true" ]]; then
		sudo apt-get install -y autopoint
		sudo apt-get install -y doxygen
	fi
else
	echo "Unknown OS type." >&2
	exit 1
fi

git clone https://github.com/microsoft/vcpkg.git
cd vcpkg
git checkout tags/2023.11.20
if [[ "$OSTYPE" == "darwin"* ]]; then
	sed -i -e 's/0.63/1.3.0/' ports/vcpkg-tool-meson/vcpkg.json
	sed -i -e 's/0.63.0/1.3.0/' ports/vcpkg-tool-meson/portfile.cmake
	sed -i -e 's/bb91cea0d66d8d036063dedec1f194d663399cdf/7368795d13081d4928a9ba04d48498ca2442624b/' ports/vcpkg-tool-meson/portfile.cmake
	sed -i -e 's/e5888eb35dd4ab5fc0a16143cfbb5a7849f6d705e211a80baf0a8b753e2cf877a4587860a79cad129ec5f3474c12a73558ffe66439b1633d80b8044eceaff2da/b2dc940a8859d6b0af8cb762c896d3188cadc1e65e3c7d922d6cb9a4ed7a1be88cd4d51a8aa140319a75e467816e714c409cf74c71c830bbc5f96bb81c1845ce/' ports/vcpkg-tool-meson/portfile.cmake
	sed -i -e "s/intl_factory/packages['intl'] = intl_factory/" ports/vcpkg-tool-meson/meson-intl.patch
fi
./bootstrap-vcpkg.sh
cd ..

if [[ "$OSTYPE" == "darwin"* ]]; then
	VCPKG_TRIPLET=x64-osx-dynamic
else
	VCPKG_TRIPLET=x64-linux-dynamic
fi

date > ./ports/docwire/.disable_binary_cache
SOURCE_PATH="$PWD" VCPKG_KEEP_ENV_VARS=SOURCE_PATH ./vcpkg/vcpkg --overlay-ports=./ports install docwire:$VCPKG_TRIPLET

version=`cat ./vcpkg/installed/$VCPKG_TRIPLET/share/docwire/VERSION`
./vcpkg/vcpkg --overlay-ports=./ports export docwire:$VCPKG_TRIPLET --raw --output=docwire-$version --output-dir=.

echo "\$(dirname \"\$0\")/installed/$VCPKG_TRIPLET/tools/docwire.sh \"\$@\"" > docwire-$version/docwire.sh
chmod u+x docwire-$version/docwire.sh

tar -cjvf docwire-$version-$VCPKG_TRIPLET.tar.bz2 docwire-$version
sha1sum docwire-$version-$VCPKG_TRIPLET.tar.bz2 > docwire-$version-$VCPKG_TRIPLET.tar.bz2.sha1
