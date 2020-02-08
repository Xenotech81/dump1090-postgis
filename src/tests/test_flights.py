import unittest
from unittest.mock import patch, Mock
import sqlalchemy.orm

from tests import msg3_valid
from tests.test_adsb_parser import AdsbMessageStub


class TestCurrentFlights(unittest.TestCase):

    def setUp(self) -> None:
        with patch('os.environ', return_value="ENV_VAR"):
            from src.dump1090_postgis.flights import CurrentFlights
            from src.dump1090_postgis.adsb_parser import AdsbMessageFilter
            from dump1090_postgis.models import Flight

        self.Flight = Flight

        session_mock = Mock(spec=sqlalchemy.orm.session.Session)
        adsb_filter_mock = Mock(spec=AdsbMessageFilter)
        self.current_flights = CurrentFlights(session_mock, adsb_filter=adsb_filter_mock)

    def test_set_item(self):
        flight_1 = Mock(spec=self.Flight, hexident='hex1')
        self.current_flights['hex1'] = flight_1

        self.assertDictEqual(self.current_flights._flights, {'hex1': flight_1})
        self.assertRaises(AssertionError, self.current_flights.__setitem__, 'hex1', "WrongType")

    def test_get_item(self):
        flight_1 = Mock(spec=self.Flight, hexident='hex1')
        self.current_flights['hex1'] = flight_1

        self.assertEqual(self.current_flights['hex1'], flight_1)
        self.assertEqual(self.current_flights['NotInDict'], None)

    def test_iter(self):
        flight_1 = Mock(spec=self.Flight, hexident='hex1')
        flight_2 = Mock(spec=self.Flight, hexident='hex2')
        self.current_flights['hex1'] = flight_1
        self.current_flights['hex2'] = flight_2

        for flight, flight_truth in zip(self.current_flights, [flight_1, flight_2]):
            self.assertEqual(flight, flight_truth)

    def test_update_msg3(self):
        """A valid MSG=3 type message must create a new Flight instance."""
        self.current_flights.prune = Mock()
        altitude_mock = Mock()
        altitude_mock.return_value = True
        self.current_flights._adsb_filter.altitude = altitude_mock

        for msg in AdsbMessageStub([msg3_valid]):
            self.current_flights.update(msg)
            self.assertTrue(msg.hexident in self.current_flights._flights.keys())
            self.assertTrue(self.current_flights.prune.called_once())


if __name__ == '__main__':
    unittest.main()
