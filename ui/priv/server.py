from octoprint.plugin import plugin_manager
from octoprint.plugins.virtual_printer import VirtualPrinterPlugin
from octoprint.plugins.virtual_printer.virtual import VirtualPrinter, VirtualEEPROM
from threading import Thread

import os
import psutil
import signal
import struct
import sys

# Monkey patch VirtualEEPROM so it doesn't write a file
VirtualEEPROM._initialise_eeprom = lambda _self: VirtualEEPROM.get_default_settings()

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

def start_printer_read_thread():
    def read_forever():
        """Reads messages from the virtual printer. b'wait' messages are discarded"""
        stream = os.fdopen(4, 'wb')

        while True:
            line = printer.readline()

            if line != b'wait':
                header = struct.pack('!I', len(line))
                
                try:
                    stream.write(header)
                    stream.write(line)
                    stream.flush()
                except:
                    pass
    
    read_thread = Thread(target=read_forever)
    read_thread.start()

    return read_thread


def start_printer_write_thread():
    stream = os.fdopen(3, 'rb')

    def recv():
        """Read an Erlang term from an input stream."""
        header = stream.read(4)
        if len(header) != 4:
            return None  # EOF
    
        (length,) = struct.unpack('!I', header)
        payload = stream.read(length)
        if len(payload) != length:
            return None

        return payload

    def write_forever():
        command = recv()
        while command:
            printer.write(command)
            message = recv()

    write_thread = Thread(target=write_forever)
    write_thread.start()

    return write_thread

def wait_until_parent_exits():
    # Our parent is whatever Elixir process that spawned us
    parent = os.getppid()

    while psutil.pid_exists(parent):
        pass
    
    # sys.exit doesn't seem to work properly, so we go for the kill
    os.kill(os.getpid(), signal.SIGKILL)


if __name__ == '__main__':
    start_printer_read_thread()
    start_printer_write_thread()
    wait_until_parent_exits()