import os
import hashlib
import random
from IPython.utils.py3compat import encode

c.NotebookApp.ip = '0.0.0.0'
c.NotebookApp.port = int(os.getenv('PORT', 8888))
c.NotebookApp.open_browser = False
c.MultiKernelManager.default_kernel_name = 'python3'

# sets a password if PASSWORD is set in the environment
if 'NOTEBOOK_PASS' in os.environ:
    passphrase = os.environ['NOTEBOOK_PASS']
    salt_len = 12
    h = hashlib.new('sha1')
    salt = ('%0' + str(salt_len) + 'x') % random.getrandbits(4 * salt_len)
    h.update(encode(passphrase, 'utf-8') + encode(salt, 'ascii'))
    c.NotebookApp.token = ':'.join(('sha1', salt, h.hexdigest()))
    del os.environ['NOTEBOOK_PASS']
else:
    c.NotebookApp.token = ''

if 'NOTEBOOK_USER' in os.environ:
    c.NotebookApp.notebook_dir = '/root/' + os.environ['NOTEBOOK_USER']
    del os.environ['NOTEBOOK_USER']
