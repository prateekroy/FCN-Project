#!/bin/bash

SCALARIS_VERSION="0.9.0+git"
date=`date +"%Y%m%d.%H%M"`
name="scalaris" # folder base name (without version)
pkg_name="scalaris-bindings" # package name
url="https://github.com/scalaris-team/scalaris.git"
deletefolder=0 # set to 1 to delete the folder the repository is checked out to

#####
if [[ "$SCALARIS_VERSION" == *git* ]]; then
  MODE="snapshot"
else
  MODE="tag"
fi

if [ "$MODE" = "snapshot" ] ; then
  folder="${name}"
  if [ ! -d "${folder}" ]; then
    echo "checkout ${url} -> ${folder} ..."
    git clone --branch master --single-branch --depth=1 "${url}" "${folder}"
    result=$?
  else
    echo "update ${url} -> ${folder} ..."
    cd "${folder}"
    git pull
    result=$?
    cd - >/dev/null
  fi

  if [ ${result} -eq 0 ]; then
    echo -n "get git revision ..."
    revision=`cd "${folder}" && git log --pretty=format:'%h' -n 1`
    result=$?
    echo " ${revision}"
    pkg_version="${SCALARIS_VERSION}${date}.${revision}"
  fi
else
  pkg_version="${SCALARIS_VERSION}"
  folder="${name}-${pkg_version}"
  tarfile="${folder}.tar.gz"
  echo "downloading archive ${url%.git}/archive/${SCALARIS_VERSION}.tar.gz ..."
  wget "${url%.git}/archive/${SCALARIS_VERSION}.tar.gz" -O "${tarfile}" && \
  tar -xzf "${tarfile}"
  result=$?
  if [ ! -d "${folder}" ]; then
    echo "wrong archive contents, expecting folder ${folder}"
    exit 1
  fi
fi

if ! diff -q checkout.sh "${folder}/contrib/packages/bindings/checkout.sh" > /dev/null ; then
  echo "checkout-script changed - re-run ./checkout.sh"
  cp "${folder}/contrib/packages/bindings/checkout.sh" ./
  exit 1
fi

if [ "$MODE" = "snapshot" ] ; then
  if [ ${result} -eq 0 ]; then
    tarfile="${name}-${pkg_version}.tar.gz"
    newfoldername="${name}-${pkg_version}"
    echo "making ${tarfile} ..."
    mv "${folder}" "${newfoldername}" && tar -czf "${tarfile}" "${newfoldername}" --exclude-vcs && mv "${newfoldername}" "${folder}"
    result=$?
  fi
fi

if [ ${result} -eq 0 ]; then
  echo "extracting .spec file ..."
  sourcefolder="${folder}/contrib/packages/bindings"
  sed -e "s/%define pkg_version .*/%define pkg_version ${pkg_version}/g" \
      < "${sourcefolder}/${pkg_name}.spec"           > "./${pkg_name}.spec" && \
  cp  "${sourcefolder}/${pkg_name}.changes"            "./${pkg_name}.changes"
  result=$?
fi

if [ ${result} -eq 0 ]; then
  echo "extracting Debian package files ..."
  sourcefolder="${folder}/contrib/packages/bindings"
  sed -e "s/Version: .*-.*/Version: ${pkg_version}-1/g" \
      -e "s/scalaris.*\\.orig\\.tar\\.gz/${pkg_name}-${pkg_version}\\.orig\\.tar\\.gz/g" \
      -e "s/scalaris.*\\.diff\\.tar\\.gz/${pkg_name}-${pkg_version}\\.diff\\.tar\\.gz/g" \
      < "${sourcefolder}/${pkg_name}.dsc"             > "./${pkg_name}.dsc" && \
  ( ( test "$MODE" != "snapshot" && \
      sed -e "0,/(.*-.*)/s//(${pkg_version}-1)/" \
      < "${sourcefolder}/debian.changelog"            > ./debian.changelog ) || \
    sed -e "0,/(.*-.*)/s//(${pkg_version}-1)/" \
        -e "0,/ -- Nico Kruber <kruber@zib.de>  .*/s// -- Nico Kruber <kruber@zib.de>  `LANG=C date -R`/" \
      < "${sourcefolder}/debian.changelog"            > ./debian.changelog ) && \
  cp  "${sourcefolder}/debian.compat"                   ./debian.compat && \
  cp  "${sourcefolder}/debian.control"                  ./debian.control && \
  cp  "${sourcefolder}/debian.rules"                    ./debian.rules && \
  cp  "${sourcefolder}/debian.source.lintian-overrides" ./debian.source.lintian-overrides && \
  cp  "${folder}/LICENSE"                               ./debian.copyright
  result=$?
fi

if [ ${result} -eq 0 ]; then
  echo "extracting ArchLinux package files ..."
  sourcefolder="${folder}/contrib/packages/bindings"
  tarmd5sum=`md5sum "${tarfile}" | cut -d' ' -f 1` && \
  sed -e "s/pkgver=.*/pkgver=${pkg_version}/g" \
      -e "s/md5sums=('.*')/md5sums=('${tarmd5sum}')/g" \
      < "${sourcefolder}/PKGBUILD"                   > ./PKGBUILD
  result=$?
fi

if [ ${result} -eq 0 -a ${deletefolder} -eq 1 ]; then
  echo "removing ${folder} ..."
  rm -rf "${folder}"
fi
