import socket
import threading
import unittest
import unittest.mock
import re
from time import sleep

from src.dump1090_postgis.adsb_parser import Dump1090Socket, AdsbMessage


@unittest.skip("Skip for now")
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


class TestServer:
    def __init__(self, host, port):
        self.host = host
        self.port = port

        self.adsb_message_1 = b"MSG,3,1,1,40757F,1,2019/10/20,11:33:40.311,2019/10/20,11:33:40.311,,5000,,,46.65470," \
                              b"-2.77776,,,0,,0,0"

        self.sock = socket.socket()
        self.sock.bind((self.host, self.port))
        self.start_listening()

    def handle_client(self, client):
        # Server will just close the connection after it opens it

        while True:
            print("sending:", self.adsb_message_1)
            self.sock.send(self.adsb_message_1)
            sleep(1)

        client.close()
        return

    def start_listening(self):
        self.sock.listen(5)

        client, addr = self.sock.accept()
        client_handler = threading.Thread(target=self.handle_client, args=(client,))
        client_handler.start()

def run_fake_server(host, port):
    # Run a server to listen for a connection and then close it
    server_sock = socket.socket()
    server_sock.bind((host, port))
    server_sock.listen(0)
    server_sock.accept()
    for _ in range(10):
        print("sending message")
        server_sock.send(b"hello")
    server_sock.close()


class TestDump1090Socket(unittest.TestCase):

    def setUp(self) -> None:
        self.host = socket.gethostname()
        self.port = 7784

        #test_server = TestServer(self.host, self.port)

    def test_connection(self):
        server_thread = threading.Thread(target=run_fake_server, args=(self.host, self.port))
        server_thread.start()
        sleep(3)

        message_source = Dump1090Socket(hostname=self.host, port=self.port)
        print("Client up")
        for msg in AdsbMessage(message_source):
            print(msg)

if __name__ == '__main__':
    unittest.main()
