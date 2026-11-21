cd sources
tar xvf binutils-2.47.tar.xz
cd binutils-2.47/
mkdir -v build
cd build
../configure --prefix=$LFS/tools \
             --with-sysroot=$LFS \
             --target=$LFS_TGT   \
             --disable-nls       \
             --enable-gprofng=no \
             --disable-werror    \
             --enable-new-dtags  \
             --enable-default-hash-style=gnu && make && make install;
make
make install
cd ../..
rm -Rf binutils-2.47/

