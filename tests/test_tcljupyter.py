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
        {'code': 'expr {6 * 7}', 'result': '42'}
    ]

    # Tests on is_complete_* interactions between frontend and kernel
    complete_code_samples = ['expr {1}', 'puts "hello, world"', 'proc foo {x} {\n  expr {x * 2} \n}', 'set x \\\\']
    incomplete_code_samples = ['expr {1', 'puts "hello, world', 'proc foo {x} {\n  expr {x * 2}', 'expr \\', 'puts "hello, \\']
    
    # Samples of code which should generate a rich display output, and
    # the expected MIME type
    # code_display_data = [
    #    {'code': 'show_image()', 'mime': 'image/png'}
    #]

    # Adapted from https://github.com/IRkernel/IRkernel/blob/master/tests/testthat/test_ir.py#L34
    def _execute_code(self, code, tests=True, silent=False, store_history=True):
        self.flush_channels()
        
        reply, output_msgs = self.execute_helper(code, silent=silent, store_history=store_history)
        
        self.assertEqual(reply['content']['status'], 'ok', '{0}: {0}'.format(reply['content'].get('ename'), reply['content'].get('evalue')))
        if tests:
            self.assertGreaterEqual(len(output_msgs), 1)
            # tcljupyter sends both display_datas /and/ execute_results
            self.assertIn(output_msgs[0]['msg_type'], ('display_data', 'execute_result'))
        return reply, output_msgs

    def test_should_increment_exec_count(self):
        """properly increments execution history"""
        code = 'set x 1'
        reply, output_msgs = self._execute_code(code)
        reply2, output_msgs2 = self._execute_code(code)
        
        execution_count_1 = reply['content']['execution_count']
        execution_count_2 = reply2['content']['execution_count']
        self.assertEqual(execution_count_1 + 1, execution_count_2)

if __name__ == '__main__':
    unittest.main()
