#!/usr/bin/env bash

# Script to build kernel images that can be used to test the loading of eBPF code.
#
# inspired by:
# https://github.com/cilium/ci-kernels/blob/master/make.sh

set -eu
set -o pipefail

readonly script_dir="$(cd "$(dirname "$0")"; pwd)"
readonly build_dir="${script_dir}/_build"
readonly tmp_virtme="$(mktemp -d --suffix=-virtme)"

# get the script to provide the virtual environment for the kernel
git clone https://git.kernel.org/pub/scm/utils/kernel/virtme/virtme.git "${tmp_virtme}"  || exit 1

mkdir -p "${build_dir}"

readonly kernel_versions=("4.19.114" "5.4.31" "5.10.79" "5.15.133" "6.1.55")
for kernel_version in "${kernel_versions[@]}"; do
	if [[ -f "linux-${kernel_version}.bz" ]]; then
		echo Skipping "${kernel_version}", it already exists
		continue
	fi

	src_dir="${build_dir}/linux-${kernel_version}"
	archive="${build_dir}/linux-${kernel_version}.tar.xz"

	test -e "${archive}" || curl --fail -L https://cdn.kernel.org/pub/linux/kernel/v"${kernel_version%%.*}".x/linux-"${kernel_version}".tar.xz -o "${archive}"
	test -d "${src_dir}" || tar --xz -xf "${archive}" -C "${build_dir}"

	pushd "${src_dir}"
	make KCONFIG_CONFIG=custom.config defconfig
	cat "${script_dir}/config" >> "${src_dir}/custom.config"
	make allnoconfig KCONFIG_ALLCONFIG="custom.config"
	"${tmp_virtme}/virtme-configkernel" --update

	make clean
	make -j"$(nproc)" bzImage

	mv "arch/x86/boot/bzImage" "${script_dir}/linux-${kernel_version}.bz"

	popd
done
