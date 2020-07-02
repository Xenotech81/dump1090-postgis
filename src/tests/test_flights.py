import unittest
from unittest.mock import patch, Mock, MagicMock
import sqlalchemy.orm

from dump1090_postgis.airports import Airport, _nte_runway_21
from tests import msg3_valid
from tests.test_adsb_parser import AdsbMessageStub
from tests.test_models import position_config_0

@unittest.skip("")
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


class TestLandingAndTakeoffManager(unittest.TestCase):

    def setUp(self) -> None:
        with patch('os.environ', return_value="ENV_VAR"):
            from dump1090_postgis.models import Flight, Position
            from dump1090_postgis.flights import LandingAndTakeoffManager
            from dump1090_postgis.models import Landings, Takeoffs

        self.Landings = Landings
        self.Takeoffs = Takeoffs

        self.flight_mock = Mock(spec=Flight, hexident='hex1')

        self.position_mock = Mock(spec=Position)
        self.position_mock.configure_mock(**position_config_0)

        self.session_mock = Mock()
        self.session_mock.add = Mock()
        self.session_mock.commit = Mock()

        self.airport_mock = Mock(spec=Airport)
        self.airport_mock.get_runway.return_value = _nte_runway_21

        LandingAndTakeoffManager._airports = [self.airport_mock]
        self.lt_manager = LandingAndTakeoffManager(self.session_mock)

    def test_callback(self):
        self.lt_manager._callback(self.position_mock, self.flight_mock, self.Landings)
        self.assertTrue(self.lt_manager._LandingAndTakeoffManager__session.add.called)
        self.assertTrue(self.lt_manager._LandingAndTakeoffManager__session.commit.called)


if __name__ == '__main__':
    unittest.main()
