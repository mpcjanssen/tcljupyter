from ipykernel.kernelbase import Kernel
from io import BytesIO
import urllib, base64
import tkinter



def bgerror(*args):
    print(args)


class TclJupyter(Kernel):
    implementation = 'Tcl (python)'
    implementation_version = '1.0'
    language = 'tcl'  # will be used for
                         # syntax highlighting
    language_version = '8.6.19'
    language_info = {'name': 'tcl',
            'mimetype': 'txt/x-tcl',
            'extension': '.tcl'}
    banner = "Tcl"
    def __init__(self, **kwargs):
        Kernel.__init__(self, **kwargs)
        self.tcl = tkinter.Tcl()
        self.tcl.createcommand("writechan", self.writechan)
        self.tcl.createcommand("bgerror", self.bgerror)


        self.tcl.eval("chan push stdout {writechan stdout}")
        self.tcl.eval("chan push stderr {writechan stderr}")
        self.tcl.eval("interp create child")
        self.tcl.eval   
        self.execution_count = 0

    def bgerror(self,msg):
        self.writechan("stderr","write",msg)

    def writechan(self, name, cmd, *args):
        print(args)
        if cmd == "initialize":
            return ["initialize", "finalize", "write"]
        elif cmd == "write":
            stream_content = {'name': name, 'text': args[1]}
            self.send_response(self.iopub_socket, 'stream', stream_content)
            
        return("")

    def do_execute(self, code, silent,
            store_history=True,
            user_expressions=None,
            allow_stdin=False):
        try:
            result = self.tcl.call("child", "eval", code)
            if not silent:
                stream_content = {'name': 'stdout', 'text': result}
        except tkinter.TclError as err:
                errorInfo = self.tcl.getvar("::errorInfo").splitlines()
                stream_content = {'name': 'stderr', 'text': "\n".join(errorInfo[0:-2])}

        self.send_response(self.iopub_socket, 'stream', stream_content)
        return {'status': 'ok', 'execution_count': self.execution_count,
                         'payload': [], 'user_expressions': {}}

