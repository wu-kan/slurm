# syntax=docker/dockerfile:1.4
FROM wukan0621/sccenv
ARG WUK_WORKSPACE=/workspace
WORKDIR ${WUK_WORKSPACE}
COPY . slurm
RUN <<EOF
. $SCC_SETUP_ENV
echo ${WUK_WORKSPACE}
cd ${WUK_WORKSPACE}/slurm
mkdir -p ${WUK_WORKSPACE}/slurm-modified-spack-mirror/slurm
python3 -m tarfile -c ${WUK_WORKSPACE}/slurm-modified-spack-mirror/slurm/slurm-21-08-8-2.tar.gz .
spack mirror add slurm-modified ${WUK_WORKSPACE}/slurm-modified-spack-mirror
spack uninstall -y slurm@21-08-8-2 | cat
spack install -y --fail-fast --no-checksum slurm@21-08-8-2+mariadb target=$(arch) ^ glib@:2.74.7 && spack gc -y
spack mirror rm slurm-modified
rm -rf ${WUK_WORKSPACE}/slurm-modified-spack-mirror
spack clean -ab
EOF
