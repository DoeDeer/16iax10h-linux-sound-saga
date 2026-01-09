#!/usr/bin/env bash
set -euo pipefail

### --------- helpers ---------
err() {
    echo "ERROR: $*" >&2
    exit 1
}

info() {
    echo "==> $*"
}

### --------- docker check ---------
if ! command -v docker >/dev/null 2>&1; then
    err "Docker is not installed or not in PATH"
fi

if ! docker info >/dev/null 2>&1; then
    err "Docker is installed but not usable (is the daemon running?)"
fi

info "Docker is available"

### --------- secure boot prompt ---------
SIGN_KERNEL="no"
CERT_DIR=""

read -rp "Do you want to sign the kernel for Secure Boot? [y/N]: " answer
case "${answer,,}" in
    y|yes)
        SIGN_KERNEL="yes"
        read -rp "Enter absolute path to directory containing Secure Boot certs/keys: " CERT_DIR
        [[ -d "$CERT_DIR" ]] || err "Certificate directory does not exist"
        ;;
esac

### --------- output path ---------
read -rp "Enter output directory for built RPMs: " OUTPUT_DIR
OUTPUT_DIR="$(realpath -m "$OUTPUT_DIR")"
mkdir -p "$OUTPUT_DIR"

info "Output directory: $OUTPUT_DIR"

### --------- dockerfile ---------
TMPDIR="$(mktemp -d)"
cleanup() { rm -rf "$TMPDIR"; }
trap cleanup EXIT

cp ./fix/firmware/aw88399_acf.bin "$TMPDIR/aw88399_acf.bin"
cat > "$TMPDIR/Dockerfile" <<'EOF'
FROM fedora:43

RUN dnf -y install \
        fedpkg qt3-devel libXi-devel gcc-c++ ccache && \
    dnf clean all && \
    fedpkg clone -a kernel && \
    dnf builddep -y kernel/kernel.spec && \
    rm -r kernel

COPY ./aw88399_acf.bin /lib/firmware/aw88399_acf.bin

ARG UNAME=builder
ARG UID=1000
ARG GID=1000
RUN groupadd -g $GID -o $UNAME && \
    useradd -m -u $UID -g $GID -o $UNAME && \
    echo "$UNAME ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers && \
    usermod -aG pesign $UNAME

USER $UNAME
WORKDIR /home/$UNAME
EOF

info "Building Docker image"
docker build -t fbuild:latest "$TMPDIR"

### --------- run build ---------
cat > "$TMPDIR/entrypoint.sh" <<'EOF'
#!/usr/bin/env bash

set -euo pipefail

info() { echo "==> $*"; }

info "Cloning Fedora kernel dist-git"
fedpkg clone -a kernel
cd kernel

info "Checking out f43 branch"
git switch f43

info "Installing build dependencies"
sudo dnf -y builddep kernel.spec

if [[ -d /certs ]]; then
    info "Secure Boot enabled – configuring signing"
    echo "$(whoami)" | sudo tee -a /etc/pesign/users
    sudo /usr/libexec/pesign/pesign-authorize
    certutil -A -i /certs/cert.der -n "Sound fix certificate" -d /etc/pki/pesign/ -t "Pu,Pu,Pu"
    pk12util -i /certs/key.p12 -d /etc/pki/pesign -w /certs/pass.txt
    sed -i '/here before the %%install macro is pre-built./a\\n%define pe_signing_cert Sound fix certificate' kernel.spec
fi

info "Copy the sound fix to build folder and configure specs file"
cp /inputs/sound_fix.patch .
sed -i 's/# define buildid .local/%define buildid .sound_fix/' kernel.spec
echo "CONFIG_SND_HDA_SCODEC_AW88399=m
CONFIG_SND_HDA_SCODEC_AW88399_I2C=m
CONFIG_SND_SOC_AW88399=m
CONFIG_SND_SOC_SOF_INTEL_TOPLEVEL=y
CONFIG_SND_SOC_SOF_INTEL_COMMON=m
CONFIG_SND_SOC_SOF_INTEL_MTL=m
CONFIG_SND_SOC_SOF_INTEL_LNL=m" >> kernel-local
sed -i '/Patch999999/i\Patch2: sound_fix.patch' kernel.spec
sed -i '/ApplyOptionalPatch linux-kernel-test.patch/i\ApplyOptionalPatch sound_fix.patch' kernel.spec

info "Building kernel RPMs (this will take a long time)"
fedpkg local --with baseonly --without debuginfo --without perf --without selftests --without efiuki
info "Copying RPMs to output directory"
find . -type f -name "*.rpm" -exec cp -v {} /output \;

info "Build completed"
EOF

DOCKER_RUN_ARGS=(
    --rm
    -v "$OUTPUT_DIR:/output"
    -v "./fix/patches/16iax10h-audio-linux-6.18.patch:/inputs/sound_fix.patch"
    -v "$TMPDIR/entrypoint.sh:/inputs/entrypoint.sh"
)

if [[ "$SIGN_KERNEL" == "yes" ]]; then
    DOCKER_RUN_ARGS+=("-v" "$CERT_DIR:/certs:ro")
fi

info "Starting kernel build container"

docker run "${DOCKER_RUN_ARGS[@]}" fbuild:latest bash /inputs/entrypoint.sh

echo
info "Kernel build finished successfully"
info "RPMs are available in: $OUTPUT_DIR"
