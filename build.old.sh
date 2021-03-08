#/bin/bash

set -e

function build_slice {
	[[ "${cached}" == "true" ]] && return 0

    local sdk="$1"
    local arch="$2"
    local triple="$3"

    export CC="xcrun -sdk ${sdk} clang -arch ${arch}"
    export CXX="xcrun -sdk ${sdk} clang++ -arch ${arch}"
    export CFLAGS="${ADDITIONAL_CFLAGS}"

    local arch_dir="${PWD}/staging/${sdk}/archs/${arch}"
    local prefix_dir="${arch_dir}/prefix"
    mkdir -p "${prefix_dir}"

    export PKG_CONFIG_PATH="${prefix_dir}/lib/pkgconfig"
    export openssl_LIBS="-L${PWD}/OpenSSL/${sdk}/lib -lssl -lcrypto"
    export openssl_CFLAGS="-I${PWD}/OpenSSL/${sdk}/include"

    cd libplist
    ./autogen.sh --host="${triple}" --prefix="${prefix_dir}" --without-cython
    make clean all install bin_PROGRAMS=""
    install_name_tool -id '@rpath/plist.framework/plist' "${prefix_dir}/lib/libplist-2.0.dylib"

    cd ../libusbmuxd
    ./autogen.sh --host="${triple}" --prefix="${prefix_dir}"
    make clean all install bin_PROGRAMS=""
    install_name_tool -id '@rpath/usbmuxd.framework/usbmuxd' "${prefix_dir}/lib/libusbmuxd-2.0.dylib"

    cd ../libimobiledevice
    ./autogen.sh --host="${triple}" --prefix="${prefix_dir}" --without-cython # --enable-debug
    make clean all install bin_PROGRAMS=""
    install_name_tool -id '@rpath/libimobiledevice.framework/libimobiledevice' "${prefix_dir}/lib/libimobiledevice-1.0.dylib"

    cd ..
}

function build_framework {
    local sdk="$1"
    local is_hierarchical="$2"
    local lib_name="$3"
    local module_name="$4"

    local sdk_dir="${PWD}/staging/${sdk}"
    local fwk_dir="${sdk_dir}/${module_name}.framework"
    local archs=("${sdk_dir}/archs"/*)

    mkdir "${fwk_dir}"
    cp -a "${archs[0]}/prefix/include/${module_name}" "${fwk_dir}/Headers"

    mkdir "${fwk_dir}/Modules"
    cat > "${fwk_dir}/Modules/module.modulemap" << ENDMOD
framework module ${module_name} {
    umbrella "."
}
ENDMOD

    cat > "${fwk_dir}/Info.plist" << ENDPLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>CFBundleDevelopmentRegion</key>
	<string>English</string>
	<key>CFBundleExecutable</key>
	<string>${module_name}</string>
	<key>CFBundleIdentifier</key>
	<string>com.kabiroberai.${module_name}</string>
	<key>CFBundleInfoDictionaryVersion</key>
	<string>6.0</string>
	<key>CFBundlePackageType</key>
	<string>FMWK</string>
	<key>CFBundleShortVersionString</key>
	<string>1.0</string>
	<key>CFBundleSignature</key>
	<string>????</string>
	<key>CFBundleVersion</key>
	<string>1</string>
</dict>
</plist>
ENDPLIST

    if [[ "$(ls -1q "${sdk_dir}" | wc -l)" -gt 1 ]]; then
        # More than 1 arch for sdk. Use lipo.
        lipo -create "${sdk_dir}/archs/"*"/prefix/lib/${lib_name}" -output "${fwk_dir}/${module_name}"
    else
        # Only one arch. Use slice directly.
        cp -L "${sdk_dir}/archs/"*"/prefix/lib/${lib_name}" "${fwk_dir}/${module_name}"
    fi

    if [[ "${is_hierarchical}" == "true" ]]; then
    	mkdir -p "${fwk_dir}/Versions/A"
    	ln -s A "${fwk_dir}/Versions/Current"
    	for file in Headers Info.plist Modules "${module_name}"; do
    		mv "${fwk_dir}/${file}" "${fwk_dir}/Versions/A/"
    		ln -s "Versions/Current/${file}" "${fwk_dir}/${file}"
    	done
    fi
}

function build_frameworks {
    local sdkdir="staging/$1"
    local archs=("${sdkdir}/archs"/*)

    build_framework "$1" "$2" libplist-2.0.dylib plist
    mkdir "${sdkdir}/plist.framework/Headers-old"
    mv "${sdkdir}/plist.framework/Headers/"* "${sdkdir}/plist.framework/Headers-old/"
    cp "${sdkdir}/plist.framework/Headers-old/plist.h" "${sdkdir}/plist.framework/Headers/"
    rm -r "${sdkdir}/plist.framework/Headers-old"

    if [[ ! -r "${archs[0]}/prefix/include/usbmuxd/usbmuxd.h" ]]; then
        mkdir -p "${archs[0]}/prefix/include/usbmuxd"
        mv "${archs[0]}/prefix/include/usbmuxd"{.h,}
    fi
    build_framework "$1" "$2" libusbmuxd-2.0.dylib usbmuxd

    build_framework "$1" "$2" libimobiledevice-1.0.dylib libimobiledevice
    # cp "${archs[0]}/prefix/include/usbmuxd"{,-proto}".h" "${sdkdir}/libimobiledevice.framework/Headers/"
}

function build_xcframework {
    local fwk="$1"
    local sdks=(staging/*)

    local args=()
    for sdk in "${sdks[@]}"; do
        args+=("-framework" "${sdk}/${fwk}.framework")
    done

    xcodebuild -create-xcframework "${args[@]}" -output "output/${fwk}.xcframework"
}

[[ "$1" == "cached" ]] && cached=true

rm -rf output
mkdir output

if [[ "${cached}" == "true" ]]; then
	rm -rf staging/*/{plist,libimobiledevice,usbmuxd}.framework
else
	rm -rf staging
	mkdir staging
fi

ADDITIONAL_CFLAGS="-miphoneos-version-min=8.0"
build_slice iphoneos arm64 aarch64-apple-darwin
build_frameworks iphoneos

ADDITIONAL_CFLAGS="-mios-simulator-version-min=8.0"
build_slice iphonesimulator x86_64 x86_64-apple-darwin_sim
build_slice iphonesimulator arm64 aarch64-apple-darwin_sim
build_frameworks iphonesimulator

ADDITIONAL_CFLAGS="-mmacosx-version-min=10.11"
build_slice macosx arm64 aarch64-apple-darwin
build_slice macosx x86_64 x86_64-apple-darwin
build_frameworks macosx true

echo "Building xcframeworks..."

build_xcframework plist
build_xcframework usbmuxd
build_xcframework libimobiledevice

echo "Done!"
