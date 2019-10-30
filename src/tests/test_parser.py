import unittest
from ..dump1090-postgis.parser import AdsbMessage

class TestParser(unittest.TestCase):
    def test_message_normalization(self):
        self.assertEqual(True, False)

    unittest.skip("Not finished yet")
    def test_dummy():
        REGEXP_MSG = r'^MSG,' \
                     r'(?P<transmission_type>\d),' \
                     r'(?P<dummy_type>\d)'
        __re_msg = re.compile(REGEXP_MSG)
        grps = __re_msg.search('MSG,3,7').groupdict()


if __name__ == '__main__':
    unittest.main()
