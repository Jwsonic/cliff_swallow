from erlport.erlterms import Atom
from erlport.erlang import cast, call

from octoprint.plugin import plugin_manager
from octoprint.plugins.virtual_printer import VirtualPrinterPlugin
from octoprint.plugins.virtual_printer.virtual import VirtualPrinter, VirtualEEPROM
from threading import Thread

import asyncio
import os
import psutil
import signal
import struct
import sys

# Monkey patch VirtualEEPROM so it doesn't write a file
VirtualEEPROM._initialise_eeprom = lambda _self: VirtualEEPROM.get_default_settings(
)

# Initialize the global plugin registry so the VirtualPrinterPlugin doesn't explode
plugin_manager(True)


class DictSettings(object):
    '''
    The VirtualPrinter plugin expects a Settings object which does a lot of file I/O.
    DictSettings implements the methods VirtualPrinter expects, but backend by a dict.
    '''

    def __init__(self, settings):
        self._settings = settings

    def _get(self, path):
        if not isinstance(path, list):
            return None

        current = self._settings

        for key in path:
            if key not in current:
                return None

            current = current.get(key, {})

        return current

    def get_int(self, path):
        return self._get(path)

    def get_float(self, path):
        return self._get(path)

    def get_boolean(self, path):
        return self._get(path)

    def get(self, path, **kwargs):
        return self._get(path)

    def global_get_basefolder(self, _):
        return '.'


settings = DictSettings(VirtualPrinterPlugin().get_settings_defaults())
printer = VirtualPrinter(settings, '.')

VIRTUAL_PRINTER = Atom(b'virtual_printer')
OK = Atom(b'ok')


def start(pid):
    def read_forever():
        while True:
            line = printer.readline()

            if line and line != b'wait':
                cast(pid, (VIRTUAL_PRINTER, bytes(line)))

    def wait_until_parent_exits():
        # Our parent is whatever Elixir process that spawned us
        parent = os.getppid()

        while parent != 1 and psutil.pid_exists(parent):
            pass

        # sys.exit doesn't seem to work properly, so we go for the kill
        os.kill(os.getpid(), signal.SIGKILL)

    read_thread = Thread(target=read_forever)
    read_thread.start()

    wait_thread = Thread(target=wait_until_parent_exits)
    wait_thread.start()

    return OK


def write(command):
    printer.write(command)
