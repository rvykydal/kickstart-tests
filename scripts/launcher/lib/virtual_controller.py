#!/usr/bin/python3
#
# virtual_controller - the LMC-like library that only does
# what's necessary for running kickstart-based tests in anaconda
#
# Copyright (C) 2011-2015  Red Hat, Inc.
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
#
# Author(s): Brian C. Lane <bcl@redhat.com>
#            Chris Lumens <clumens@redhat.com>
#            Jiri Konecny <jkonecny@redhat.com>
#

import os
import sys
import uuid
import tempfile
import subprocess
import libvirt

from time import sleep

# Use the Lorax treebuilder branch for iso creation
from pylorax.treebuilder import udev_escape
from pylorax.executils import execWithRedirect

from pylorax import setup_logging

from lib.conf.configuration import VirtualConfiguration
from lib.utils import disable_on_dry_run
from lib.utils.iso_dev import IsoDev
from .validator import replace_new_lines
from .shell_launcher import ProcessLauncher
from .test_logging import get_logger
from .log_monitor import LogMonitor


log = get_logger()

__all__ = ["VirtualManager", "InstallError"]


class InstallError(Exception):
    def __str__(self):
        return super().__str__().replace("#012", "\n")


class VirtualInstall(object):
    """
    Run virt-install using an iso and a kickstart
    """
    def __init__(self, test_name, iso, ks_paths, disk_paths, log_check,
                 kernel_args=None, vcpu_count=1, memory=1024, vnc=None,
                 virtio_host="127.0.0.1", virtio_port=6080,
                 nics=None, boot=None):
        """
        Start the installation

        :param iso: Information about the iso to use for the installation
        :type iso: IsoDev
        :param list ks_paths: Paths to kickstart files. All are injected, the
           first one is the one executed.
        :param log_check: Method that returns True if the installation fails
        :type log_check: method
        :param list disk_paths: Paths to pre-existing disk images.
        :param str kernel_args: Extra kernel arguments to pass on the kernel cmdline
        :param int vcpu_count: Number of virtual CPUs to assign to the virt
        :param int memory: Amount of RAM to assign to the virt, in MiB
        :param str vnc: Arguments to pass to virt-install --graphics
        :param str virtio_host: Hostname to connect virtio log to
        :param int virtio_port: Port to connect virtio log to
        :param list nics: virt-install --network parameters
        :param str boot: virt-install --boot option (used eg for ibft)
        """
        super().__init__()

        self._virt_name = "kstest-" + test_name + "_(" + str(uuid.uuid4()) + ")"
        self._iso = iso
        self._ks_paths = ks_paths
        self._disk_paths = disk_paths
        self._kernel_args = kernel_args
        self._vcpu_count = vcpu_count
        self._memory = memory
        self._vnc = vnc
        self._log_check = log_check
        self._virtio_host = virtio_host
        self._virtio_port = virtio_port
        self._nics = nics
        self._boot = boot

    def _prepare_args(self):
        # add --graphics none later
        # add whatever serial cmds are needed later
        args = ["-n", self._virt_name,
                "-r", str(self._memory),
                "--noautoconsole",
                "--vcpus", str(self._vcpu_count),
                "--rng", "/dev/random"]

        # CHECKME This seems to be necessary because of ipxe ibft chain booting,
        # otherwise the vm is created but it does not boot into installation
        if not self._boot:
            args.append("--noreboot")

        args.append("--graphics")
        if self._vnc:
            args.append(self._vnc)
        else:
            args.append("none")

        for ks in self._ks_paths:
            args.append("--initrd-inject")
            args.append(ks)

        for disk in self._disk_paths:
            args.append("--disk")
            args.append("path={0},bus=sata".format(disk))

        for nic in self._nics or []:
            args.append("--network")
            args.append(nic)

        if self._iso.stage2:
            disk_opts = "path={0},device=cdrom,readonly=on,shareable=on".format(self._iso.iso_path)
            args.append("--disk")
            args.append(disk_opts)

        if self._ks_paths:
            extra_args = "ks=file:/{0}".format(os.path.basename(self._ks_paths[0]))
        else:
            extra_args = ""
        if not self._vnc:
            extra_args += " inst.cmdline"
        if self._kernel_args:
            extra_args += " " + self._kernel_args
        if self._iso.stage2:
            extra_args += " stage2=hd:CDLABEL={0}".format(udev_escape(self._iso.label))

        if self._boot:
            # eg booting from ipxe to emulate ibft firmware
            args.append("--boot")
            args.append(self._boot)
        else:
            args.append("--extra-args")
            args.append(extra_args)

            args.append("--location")
            args.append(self._iso.iso_path + ",kernel=isolinux/vmlinuz,initrd=isolinux/initrd.img")

        channel_args = "tcp,host={0}:{1},mode=connect,target_type=virtio" \
                       ",name=org.fedoraproject.anaconda.log.0".format(
                           self._virtio_host, self._virtio_port)
        args.append("--channel")
        args.append(channel_args)
        return args

    def run(self):
        args = self._prepare_args()

        log.info("Running virt-install.")
        log.info("virt-install %s", args)

        self._start_vm(args)

        print()
        if self._log_check():
            log.info("Installation error detected. See logfile.")
        else:
            log.info("Install finished. Or at least virt shut down.")

    @disable_on_dry_run
    def _start_vm(self, args):
        try:
            execWithRedirect("virt-install", args, raise_err=True)
        except subprocess.CalledProcessError as e:
            raise InstallError("Problem starting virtual install: %s" % e)

        conn = libvirt.openReadOnly(None)
        dom = conn.lookupByName(self._virt_name)

        # TODO: If vnc has been passed, we should look up the port and print that
        # for the user at this point
        while dom.isActive() and not self._log_check():
            sys.stdout.write(".")
            sys.stdout.flush()
            sleep(10)

    @disable_on_dry_run
    def destroy(self, pool_name):
        """
        Make sure the virt has been shut down and destroyed

        Could use libvirt for this instead.
        """
        log.info("shutting down %s", self._virt_name)
        launcher = ProcessLauncher(False)
        launcher.run_process(["virsh", "destroy", self._virt_name])
        launcher.run_process(["virsh", "undefine", self._virt_name])
        launcher.run_process(["virsh", "pool-destroy", pool_name])
        launcher.run_process(["virsh", "pool-undefine", pool_name])


class VirtualManager(object):

    def __init__(self, virtual_configuration: VirtualConfiguration):
        super().__init__()
        self._conf = virtual_configuration

    def _start_virt_install(self, install_log):
        """
        Use virt-install to install to a disk image

        :param str install_log: The path to write the log from virt-install

        This uses virt-install with a boot.iso and a kickstart to create a disk
        image.
        """
        iso_dev = IsoDev(self._conf.iso_path)

        log_monitor = LogMonitor(install_log, timeout=self._conf.timeout)

        kernel_args = ""
        if self._conf.kernel_args:
            kernel_args += self._conf.kernel_args
        if self._conf.proxy:
            kernel_args += " proxy=" + self._conf.proxy

        iso_dev.mount()

        try:
            log.info("Starting virtual machine")
            virt = VirtualInstall(self._conf.test_name,
                                  iso_dev, self._conf.ks_paths,
                                  disk_paths=self._conf.disk_paths,
                                  kernel_args=kernel_args,
                                  vcpu_count=self._conf.vcpu_count,
                                  memory=self._conf.ram,
                                  vnc=self._conf.vnc,
                                  log_check=log_monitor.log_check,
                                  virtio_host=log_monitor.host,
                                  virtio_port=log_monitor.port,
                                  nics=self._conf.networks,
                                  boot=self._conf.boot_image)

            virt.run()
            virt.destroy(os.path.basename(self._conf.temp_dir))
            log_monitor.shutdown()
        except InstallError as e:
            log.error("VirtualInstall failed: %s", e)
            raise
        finally:
            log.info("unmounting the iso")
            iso_dev.unmount()

        if log_monitor.log_check():
            if not log_monitor.error_line and self._conf.timeout:
                msg = "Test timed out"
            else:
                msg = "Test failed on line: %s" % log_monitor.error_line
            raise InstallError(msg)

    def _prepare_and_run(self):
        """
        Install to a disk image

        Use virt-install or anaconda to install to a disk image.
        """
        try:
            install_log = os.path.abspath(os.path.dirname(self._conf.log_path))+"/virt-install.log"
            log.info("install_log = %s", install_log)

            self._start_virt_install(install_log)
        except InstallError as e:
            log.error("Install failed: %s", e)

            if not self._conf.keep_image:
                log.info("Removing bad disk image")

                for image in self._conf.disk_paths:
                    if os.path.exists(image):
                        os.unlink(image)

            raise

        log.info("Disk Image install successful")

    def run(self):
        setup_logging(self._conf.log_path, log)

        log.debug(self._conf)

        # Check for invalid combinations of options, print all the errors and exit.
        errors = self._check_setup()
        if errors:
            list(log.error(e) for e in errors)
            return False

        tempfile.tempdir = self._conf.temp_dir

        # Make the image.
        try:
            self._prepare_and_run()
        except InstallError as e:
            log.error("ERROR: Image creation failed: %s", e)
            raise e

        self._create_human_log()
        self._report_result()

        return True

    def _report_result(self):
        msg = "SUMMARY\n"
        msg += "-------\n"
        msg += "Logs are in {}\n".format(os.path.abspath(os.path.dirname(self._conf.log_path)))
        msg += "Disk image(s) at {}\n".format(",".join(self._conf.disk_paths))
        msg += "Results are in {}\n".format(self._conf.temp_dir)

        log.info(msg)

    def _create_human_log(self):
        output_log = os.path.join(self._conf.temp_dir, "virt-install-human.log")
        if not os.path.exists(self._conf.install_logpath):
            log.debug("Can't create virt-install-human.log")
            return

        with open(self._conf.install_logpath, 'rt') as in_file:
            with open(output_log, 'wt') as out_file:
                for line in in_file:
                    line = replace_new_lines(line)
                    out_file.write(line)

    @disable_on_dry_run(returns=[])
    def _check_setup(self):
        errors = []

        if self._conf.ks_paths and not os.path.exists(self._conf.ks_paths[0]):
            errors.append("kickstart file (%s) is missing." % self._conf.ks_paths[0])

        if self._conf.iso_path and not os.path.exists(self._conf.iso_path):
            errors.append("The iso %s is missing." % self._conf.iso_path)

        if not self._conf.iso_path:
            errors.append("virt install needs an install iso.")

        if not os.path.exists("/usr/bin/virt-install"):
            errors.append("virt-install needs to be installed.")

        if os.getuid() != 0:
            errors.append("You need to run this as root")

        return errors
