import unittest
import re
from src.dump1090_postgis.adsb_parser import Dump1090Socket


unittest.skip("Skip for now")
class TestParser(unittest.TestCase):

    def test_message_normalization(self):
        self.assertEqual(True, False)
        unittest.skip("Not finished yet")

    def test_dummy(self):
        REGEXP_MSG = r'^MSG,' \
                     r'(?P<transmission_type>\d),' \
                     r'(?P<dummy_type>\d)'
        __re_msg = re.compile(REGEXP_MSG)
        grps = __re_msg.search('MSG,3,7').groupdict()


class TestDump1090Socket(unittest.TestCase):

    def setUp(self) -> None:
        self.HOST = 'dummy'
        self.PORT = '1234'

        self.dump1090_socket = Dump1090Socket(hostname=self.HOST, port=self.PORT)


if __name__ == '__main__':
    unittest.main()
