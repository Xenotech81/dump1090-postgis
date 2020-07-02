import unittest
import datetime
from unittest.mock import patch, Mock
import shapely.geometry

position_config_0 = {
    "id": 1000,
    "flight_id": 1,
    "time": datetime.datetime.fromtimestamp(0),
    "coordinates": shapely.geometry.point.Point((0, 0)),
    "point": shapely.geometry.point.Point((0, 0)),
    "verticalrate": 0.0,
    "track": None,
    "onground": False
    }

position_config_1 = {
    "id": 2000,
    "flight_id": 1,
    "time": datetime.datetime.fromtimestamp(1),
    "coordinates": shapely.geometry.point.Point((1, 1)),
    "point": shapely.geometry.point.Point((1, 1)),
    "verticalrate": 0.0,
    "track": None,
    "onground": True
    }


class TestFlightModel(unittest.TestCase):

    def setUp(self):
        with patch('os.environ'):
            from src.dump1090_postgis.models import Flight, Position

        self.Flight = Flight
        self.Position = Position

        self.position_0 = Mock(autospec=Position)
        self.position_0.configure_mock(**position_config_0)

        self.position_1 = Mock(autospec=Position)
        self.position_1.configure_mock(**position_config_1)

        self.flight = self.Flight('DUMMY1')
        self.flight.last_seen = datetime.datetime.fromtimestamp(0)

    # @unittest.mock.patch("src.dump1090_postgis.models.datetime.datetime")
    @unittest.skip("")
    def test_age(self):
        # datetime_mock.utcnow.return_value = datetime.datetime.fromtimestamp(1)
        print(self.flight.age)
        # print(datetime_mock.utcnow)
        print(self.flight.age < datetime.timedelta(seconds=1))
        self.assertEqual(self.flight.age, datetime.datetime.utcnow() - self.flight.last_seen)

    def test_identify_onground_change_landed(self):
        position_airborne = self.position_0
        position_airborne.onground = False
        position_onground = self.position_1
        position_onground.onground = True

        self.Flight.positions = [position_airborne]
        self.Flight._broadcast_landing = Mock()
        self.Flight._broadcast_takeoff = Mock()

        flight = self.Flight("Landing")
        flight.identify_onground_change(position_onground)

        self.assertTrue(flight._broadcast_landing.called_once()), "The landing event must be broadcast to subscribers"
        self.assertEqual(flight.landed, self.position_1.time), "Timestamp of latest position must be the landing time"

    def test_identify_onground_change_takeoff(self):
        position_onground = self.position_0
        position_onground.onground = True
        position_airborne = self.position_1
        position_airborne.onground = False

        self.Flight.positions = [position_onground]
        self.Flight._broadcast_landing = Mock()
        self.Flight._broadcast_takeoff = Mock()

        flight = self.Flight("Takeoff")
        flight.identify_onground_change(position_airborne)

        self.assertTrue(flight._broadcast_takeoff().called_once()), "The takeoff event must be broadcast to subscribers"
        self.assertEqual(flight.takeoff, self.position_1.time), "Timestamp of latest position must be the takeoff time"

    def test_identify_onground_change_enroute(self):
        position_airborne_1 = self.position_0
        position_airborne_1.onground = False
        position_airborne_2 = self.position_1
        position_airborne_2.onground = False

        self.Flight.positions = [position_airborne_1]
        self.Flight._broadcast_landing = Mock()
        self.Flight._broadcast_takeoff = Mock()

        flight = self.Flight("enroute")
        flight.identify_onground_change(position_airborne_2)

        self.assertFalse(flight._broadcast_takeoff.called), "No broadcast"
        self.assertFalse(flight._broadcast_landing.called), "No broadcast"
        self.assertEqual(flight.takeoff, None)
        self.assertEqual(flight.landed, None)

    def test_identify_onground_change_taxi(self):
        position_taxi_1 = self.position_0
        position_taxi_1.onground = True
        position_taxi_2 = self.position_1
        position_taxi_2.onground = True

        self.Flight.positions = [position_taxi_1]
        self.Flight._broadcast_landing = Mock()
        self.Flight._broadcast_takeoff = Mock()

        flight = self.Flight("taxi")

        self.assertFalse(flight._broadcast_takeoff.called), "No broadcast"
        self.assertFalse(flight._broadcast_landing.called), "No broadcast"
        self.assertEqual(flight.takeoff, None)
        self.assertEqual(flight.landed, None)

    def test_identify_onground_change_first_position(self):
        position_0 = self.position_0
        position_0.onground = True

        self.Flight.positions = []  # There are no previous positions...
        flight = self.Flight("FirstPosition")

        with patch('dump1090_postgis.models.logging.warning') as warning:
            flight.identify_onground_change(position_0)
            self.assertTrue(warning.called_once())


if __name__ == '__main__':
    unittest.main()
