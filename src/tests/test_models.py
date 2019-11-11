import datetime
import unittest.mock

from src.dump1090_postgis.models import Flight

class TestFlightModel(unittest.TestCase):

    def setUp(self):
        self.flight = Flight('DUMMY1')
        self.flight.last_seen = datetime.datetime.fromtimestamp(0)

    #@unittest.mock.patch("src.dump1090_postgis.models.datetime.datetime")
    def test_age(self):
        #datetime_mock.utcnow.return_value = datetime.datetime.fromtimestamp(1)
        print(self.flight.age)
        #print(datetime_mock.utcnow)
        print(self.flight.age<datetime.timedelta(seconds=1))
        self.assertEqual(self.flight.age, datetime.datetime.utcnow()-self.flight.last_seen)


if __name__ == '__main__':
    unittest.main()
