from tcljupyter import TclJupyter
from ipykernel.kernelapp import IPKernelApp
IPKernelApp.launch_instance(
        kernel_class=TclJupyter)
