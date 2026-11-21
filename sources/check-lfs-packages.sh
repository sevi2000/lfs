#!/bin/bash

# ==========================================
# LFS PACKAGE DOWNLOAD VERIFICATION
# ==========================================

set -u

DOWNLOAD_DIR="${1:-$PWD}"

if ! command -v md5sum >/dev/null 2>&1; then
    echo "[ERROR] md5sum is not installed."
    exit 1
fi

if [[ ! -d "$DOWNLOAD_DIR" ]]; then
    echo "[ERROR] Directory does not exist: $DOWNLOAD_DIR"
    exit 1
fi

# Format: filename|expected_md5

PACKAGES=$(cat <<'EOF'
acl-2.4.0.tar.xz|e289f370161698a96f50b2a3fdadf411
attr-2.6.0.tar.gz|910a09c3ae0a211569d180586371cf7e
autoconf-2.73.tar.xz|9cbad9a116ef845bafeed8e7bc771bf4
automake-1.18.1.tar.xz|cea31dbf1120f890cbf2a3032cfb9a68
bash-5.3.tar.gz|977c8c0c5ae6309191e7768e28ebc951
bc-7.0.3.tar.xz|ad4db5a0eb4fdbb3f6813be4b6b3da74
binutils-2.47.tar.xz|d772acfbd55a81644e9fe7b8189cd2a5
bison-3.8.2.tar.xz|c28f119f405a2304ff0a7ccdcc629713
bzip2-1.0.8.tar.gz|67e051268d0c475ea773822f7500d0e5
coreutils-9.11.tar.xz|e52e9857e4aa9ae38ef32f8ed6a27604
dbus-1.16.2.tar.xz|97832e6f0a260936d28536e5349c22e5
dejagnu-1.6.3.tar.gz|68c5208c58236eba447d7d6d1326b821
diffutils-3.12.tar.xz|d1b18b20868fb561f77861cd90b05de4
e2fsprogs-1.47.4.tar.gz|733a93bc688314834ff2d10530ff4dc4
elfutils-0.195.tar.bz2|3e8ef51c43beceddbbb74879549cf72c
expat-2.8.3.tar.xz|1747f5a57b191f0373baeb5adc8078ca
expect5.45.4.tar.gz|00fce8de158422f5ccd2666512329bd2
file-5.48.tar.gz|423686e97f731d8c24e9cd1a22b03dec
findutils-4.11.0.tar.xz|512c6875ed84034dca240c4bc9380b96
flex-2.6.4.tar.gz|2882e3179748cc9f9c23ec593d6adc8d
flit_core-4.0.2.tar.gz|89ebb783230fc8db6c1d2a39644b7085
gawk-5.4.1.tar.xz|d379c2110e7a3e15347dd5559a41ad64
gcc-16.2.0.tar.xz|19b777fb19ea4982731392481306f0d3
gdbm-1.26.tar.gz|aaa600665bc89e2febb3c7bd90679115
gettext-1.0.tar.xz|dc8b2911535929cec1e263706b0a13a1
glibc-2.44.tar.xz|7677da43ef759c68e005f5d4c37986a6
gmp-6.3.0.tar.xz|956dc04e864001a9c22429f761f2c283
gperf-3.3.tar.gz|31753b021ea78a21f154bf9eecb8b079
grep-3.12.tar.xz|5d9301ed9d209c4a88c8d3a6fd08b9ac
groff-1.24.1.tar.gz|d9d996af3d05ebab934380be708ea584
grub-2.14.tar.xz|383f9effad01c235d2535357ff717543
gzip-1.14.tar.xz|4bf5a10f287501ee8e8ebe00ef62b2c2
iana-etc-20260805.tar.gz|f6d2619cfac3a68f91392e28fe4067c3
inetutils-2.8.tar.gz|f0f9ad13045a67da9c882148f9efae6b
iproute2-7.1.0.tar.xz|4f322144fb9a0877c5f9ef71b2f11180
jinja2-3.1.6.tar.gz|66d4c25ff43d1deaf9637ccda523dec8
kbd-2.10.0.tar.xz|77ff950dfa4c34fdf41125547bfa831a
kmod-34.2.tar.xz|36f2cc483745e81ede3406fa55e1065a
less-704.tar.gz|c4c9eea5b1862783b078c67ca67c9185
libcap-2.78.tar.xz|0ff11419aa4813c0a0f84fe67bf3b39e
libffi-3.8.0.tar.gz|96fe46f2a7bb82559b35a268a2c000ba
libpipeline-1.5.8.tar.gz|17ac6969b2015386bcb5d278a08a40b5
libtool-2.6.2.tar.xz|87743862e6cabfb9e76651bc64e31e5c
libxcrypt-4.5.2.tar.xz|25e888919ddcd153a07daa95224fa436
linux-7.1.8.tar.xz|807584f564568b40162e9e4a72bf191f
lz4-1.10.0.tar.gz|dead9f5f1966d9ae56e1e32761e4e675
m4-1.4.21.tar.xz|8051eef7239b2f187791f2ab0034d6b7
make-4.4.1.tar.gz|c8469a3713cbbe04d955d4ae4be23eeb
man-db-2.13.1.tar.xz|b6335533cbeac3b24cd7be31fdee8c83
man-pages-6.18.tar.xz|44915a91e4a28161dc421636a193fb3a
markupsafe-3.0.3.tar.gz|13a73126d25afa72a1ff0daed072f5fe
meson-1.12.0.tar.gz|9f943c267d63016012efcb0f31ecdd7d
mpc-1.4.1.tar.xz|40c5fba305125279ea46041160e81daf
mpdecimal-4.0.1.tar.gz|3d4412579b1edc1047efab151889cca9
mpfr-4.2.2.tar.xz|7c32c39b8b6e3ae85f25156228156061
ncurses-6.6.tar.gz|dd45bf6854430af403452a7a6a40652c
ninja-1.13.2.tar.gz|76c00637fde44909cd7d56f8d73f2042
openssl-4.0.1.tar.gz|07e316afe26b61e72206b81706b497bb
packaging-26.3.tar.gz|c6809ec56986682ceffe573b8778a1ce
patch-2.8.tar.xz|149327a021d41c8f88d034eab41c039f
pcre2-10.47.tar.bz2|aded5840ab5a7d772dd4e16fc294b665
perl-5.44.0.tar.xz|55761cf1543af326492fd194647796d1
pkgconf-3.0.5.tar.xz|18c528161e6b04ae36dc981af8c4d97e
procps-ng-4.0.7.tar.xz|d47bdda51c4bd595a1ab21b8e538bcb3
psmisc-23.7.tar.xz|53eae841735189a896d614cba440eb10
Python-3.14.7.tar.xz|a4c4c2991b4126e227073c2d9445f432
python-3.14.7-docs-html.tar.bz2|bdf55dddc02a76961d61730f06d18849
readline-8.3.tar.gz|25a73bfb2a3ad7146c5e9d4408d9f6cd
sed-4.10.tar.xz|c70dc5372db95c816442ffedf77a0d0f
setuptools-84.0.0.tar.gz|c6919a4b0862ca30604559e163a6cce9
shadow-4.20.2.tar.xz|f52e717bd330818c67bd57c897ec5a8e
sqlite-autoconf-3530400.tar.gz|ee54db5a5b04e77d4883ce0c051a1eba
sqlite-doc-3530400.zip|2cd5b168d0e5c5ae2b99beb3a4269a73
systemd-261.2.tar.gz|e3f04ccc83a28ec5e80c5432bb8329f5
systemd-man-pages-261.2.tar.xz|4c5533c1a2d0921dd4c5b5e6b8902570
tar-1.35.tar.xz|a2d8042658cfd8ea939e6d911eaf4152
tcl8.6.18-src.tar.gz|acfe0c9f7d0c626ecf026e834a888da6
tcl8.6.18-html.tar.gz|54d1ff0f5eee4e81e5cdaa4baa343397
texinfo-7.3.tar.xz|915a09fcdfc2bf0f5ecf9e556d5698ff
tzdata2026c.tar.gz|bff7174205cefab793e3b24271ef2f45
util-linux-2.42.2.tar.xz|1d70131b70abda3dec3b37e282a20c96
vim-9.2.1025.tar.gz|060c9c0d7e2bdb5e5d80daad596cae02
wheel-0.48.0.tar.gz|f668e4885de814378b332eceea04a8a0
xz-5.8.3.tar.xz|a02753f34e5546d20213b87f876a0933
zlib-1.3.2.tar.gz|a1e6c958597af3c67d162995a342138a
zstd-1.5.7.tar.gz|780fc1896922b1bc52a4e90980cdda48
EOF
)

TOTAL=0
OK=0
MISSING=0
BAD=0

echo ""
echo "=========================================="
echo "       LFS PACKAGE VERIFICATION"
echo "=========================================="
echo "Directory: $DOWNLOAD_DIR"
echo ""

while IFS='|' read -r FILE EXPECTED; do

    [[ -z "$FILE" ]] && continue

    ((TOTAL+=1))

    PATH_FILE="$DOWNLOAD_DIR/$FILE"

    if [[ ! -f "$PATH_FILE" ]]; then
        echo "[MISSING] $FILE"
        ((MISSING+=1))
        continue
    fi

    ACTUAL=$(md5sum "$PATH_FILE" | awk '{print $1}')

    if [[ "$ACTUAL" == "$EXPECTED" ]]; then
        echo "[OK]      $FILE"
        ((OK+=1))
    else
        echo "[BAD MD5] $FILE"
        echo "          Expected: $EXPECTED"
        echo "          Actual:   $ACTUAL"
        ((BAD+=1))
    fi

done <<< "$PACKAGES"

echo ""
echo "=========================================="
echo "             FINAL SUMMARY"
echo "=========================================="
echo "Total packages : $TOTAL"
echo "Valid packages : $OK"
echo "Missing        : $MISSING"
echo "Bad checksums  : $BAD"
echo "=========================================="

if (( MISSING == 0 && BAD == 0 )); then
    echo "[SUCCESS] ALL PACKAGES VERIFIED!"
    exit 0
else
    echo "[FAILED] SOME PACKAGES ARE MISSING OR INVALID."
    exit 1
fi
