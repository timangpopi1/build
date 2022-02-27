#!/usr/bin/env bash

export PATH=/usr/bin/core_perl:$PATH

DIR="$(pwd ...)"

branch="release/12.x"

git clone -b "$branch" https://github.com/llvm/llvm-project --depth=1

JobsTotal="$(($(nproc)*4))"
./build-llvm.py \
    --clang-vendor "Android" \
    --defines "LLVM_PARALLEL_COMPILE_JOBS=$JobsTotal LLVM_PARALLEL_LINK_JOBS=$JobsTotal CMAKE_C_FLAGS=-O3 CMAKE_CXX_FLAGS=-O3" \
    --projects "clang;lld;polly;compiler-rt" \
    --incremental \
    --no-update \
    --no-ccache \
    --targets "ARM;AArch64" \
    --lto thin \
    --branch "$branch"

./build-binutils.py --targets arm aarch64

# Remove unused products
rm -fr install/include
rm -f install/lib/*.a install/lib/*.la

# Strip remaining products
for f in $(find install -type f -exec file {} \; | grep 'not stripped' | awk '{print $1}'); do
	strip -s "${f: : -1}"
done

# Set executable rpaths so setting LD_LIBRARY_PATH isn't necessary
for bin in $(find install -mindepth 2 -maxdepth 3 -type f -exec file {} \; | grep 'ELF .* interpreter' | awk '{print $1}'); do
	# Remove last character from file output (':')
	bin="${bin: : -1}"

	echo "$bin"
	patchelf --set-rpath "$DIR/install/lib" "$bin"
done

rel_time="$(date +'%H%M')" # HoursMinute
rel_date="$(date '+%Y%m%d')" # ISO 8601 format
clang_version="$(install/bin/clang --version | head -n1 | cut -d' ' -f4)"
files="clang-$clang_version-$rel_date-$rel_time.tar.gz"
tar -czvf "$files" install/*
rclone copy "$files" fadlyas07:drive -P
