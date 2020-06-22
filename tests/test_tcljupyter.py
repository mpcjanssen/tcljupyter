import unittest
import jupyter_kernel_test as jkt

class TclJupyterTests(jkt.KernelTests):
    # Required --------------------------------------

    # The name identifying an installed kernel to run the tests against
    kernel_name = "tcljupyter"

    # language_info.name in a kernel_info_reply should match this
    language_name = "tcl"

    # Optional --------------------------------------

    # Code in the kernel's language to write "hello, world" to stdout
    code_hello_world = 'puts "hello, world"'

    # Pager: code that should display something (anything) in the pager
    # code_page_something = "help(something)"

    # Samples of code which generate a result value (ie, some text
    # displayed as Out[n])
    code_execute_result = [
        {'code': 'expr {6 * 7}', 'result': '42'},
        {'code': 'expr {6 * 7};', 'result': '42'}
    ]

    # Samples of code which should generate a rich display output, and
    # the expected MIME type
    # code_display_data = [
    #    {'code': 'show_image()', 'mime': 'image/png'}
    #]

if __name__ == '__main__':
    unittest.main()
