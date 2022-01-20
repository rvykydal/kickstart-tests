# Copyright (C) 2022  Red Hat, Inc.
#
# This copyrighted material is made available to anyone wishing to use,
# modify, copy, or redistribute it subject to the terms and conditions of
# the GNU General Public License v.2, or (at your option) any later version.
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY expressed or implied, including the implied warranties of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General
# Public License for more details.  You should have received a copy of the
# GNU General Public License along with this program; if not, write to the
# Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA
# 02110-1301, USA.  Any Red Hat trademarks that are incorporated in the
# source code or documentation are not subject to the GNU General Public
# License and may only be used or replicated with the express permission of
# Red Hat, Inc.
#
# mlewando@redhat.com

TESTTYPE="ui oscap anaconda disable"

. ${KSTESTDIR}/functions.sh

kernel_args() {
    local tmp_dir="${1}"

    # Provide an installation source.
    local repo_url="${KSTEST_URL}"

    local httpd_url="$(cat ${tmp_dir}/httpd_url)"

#    echo "${DEFAULT_BOOTOPTS} inst.graphical inst.updates=${httpd_url} inst.repo=${repo_url}"
    echo "${DEFAULT_BOOTOPTS} inst.graphical inst.updates=${httpd_url}"
}

prepare_updates() {
    local tmp_dir="${1}"
    local updates_dir="${tmp_dir}/updates"
    local updates_img="${tmp_dir}/updates.img"

    # Create an updates image with anabot.
    (
      cd "${tmp_dir}"
      mkdir -p etc/anaconda/conf.d
      echo "[Anaconda]" > etc/anaconda/conf.d/05_osef.conf
      echo "addons_enabled = False" >> etc/anaconda/conf.d/05_osef.conf
      tar cvzf updates.img etc
    )

    # Apply the anabot updates image.
    apply_updates_image "file://${updates_img}" "${updates_dir}"

    # Create a new updates image.
    create_updates_image "${updates_dir}" "${updates_img}"

    # Provide the image. The function prints the URL.
    upload_updates_image "${tmp_dir}" "${updates_img}"
}

inject_ks_to_initrd() {
    echo "false"
}

validate() {
    local tmp_dir="${1}"

    # Copy logs.
    copy_interesting_files_from_system "${tmp_dir}"

    check_result_file "${tmp_dir}"

}

cleanup() {
    local tmp_dir="${1}"
    stop_httpd "${tmp_dir}"
}
