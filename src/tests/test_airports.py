import unittest

from shapely.geometry import Point

from dump1090_postgis.airports import _nte_runway_03, _nte_runway_21, nte_airport


class TestRunway(unittest.TestCase):

    def setUp(self):
        self.point_on_runway = Point((-1.61046, 47.15356, 100.0))

    def test_point_in(self):
        self.assertEqual(_nte_runway_03.point_in(self.point_on_runway), True)
        self.assertEqual(_nte_runway_21.point_in(self.point_on_runway), True)

    def test_same_heading_exact(self):
        self.assertEqual(_nte_runway_03.same_heading(30), True)
        self.assertEqual(_nte_runway_21.same_heading(210), True)

    def test_same_heading_approx(self):
        self.assertEqual(_nte_runway_03.same_heading(50, direction_tol=20), True)
        self.assertEqual(_nte_runway_21.same_heading(230, direction_tol=20), True)
        self.assertEqual(_nte_runway_03.same_heading(10, direction_tol=20), True)
        self.assertEqual(_nte_runway_21.same_heading(190, direction_tol=20), True)

    def test_same_heading_false(self):
        self.assertEqual(_nte_runway_03.same_heading(51, direction_tol=20), False)
        self.assertEqual(_nte_runway_21.same_heading(231, direction_tol=20), False)
        self.assertEqual(_nte_runway_03.same_heading(9, direction_tol=20), False)
        self.assertEqual(_nte_runway_21.same_heading(189, direction_tol=20), False)

    def test_same_heading_inverse(self):
        self.assertEqual(_nte_runway_03.same_heading(210), False)
        self.assertEqual(_nte_runway_21.same_heading(30), False)


class TestAirport(unittest.TestCase):

    def setUp(self):
        self.point_on_runway = Point((-1.61046, 47.15356, 100.0))
        self.point_on_airport = Point((-1.61046, 47.154, 100.0))
        self.point_outside_airport = Point((-1.8, 48., 100.0))

    def test_get_runway_exact(self):
        """Testing the exact match between aircraft heading and runway direction."""
        self.assertTrue(nte_airport.get_runway(self.point_on_runway, 30) is _nte_runway_03), "Must return runway 03 for heading 30"
        self.assertTrue(nte_airport.get_runway(self.point_on_runway, 210) is _nte_runway_21), "Must return runway 21 for heading 210"

    def test_get_runway_approx(self):
        """Testing the heading match acceptance limits."""
        self.assertTrue(nte_airport.get_runway(self.point_on_runway, 50) is _nte_runway_03), "Must return runway 03 for heading 50"
        self.assertTrue(nte_airport.get_runway(self.point_on_runway, 230) is _nte_runway_21), "Must return runway 21 for heading 230"
        self.assertTrue(nte_airport.get_runway(self.point_on_runway, 10) is _nte_runway_03), "Must return runway 03 for heading 10"
        self.assertTrue(nte_airport.get_runway(self.point_on_runway, 190) is _nte_runway_21), "Must return runway 21 for heading 190"

    def test_get_runway_inverse(self):
        """If aircraft heading does not match any runway direction."""
        self.assertTrue(nte_airport.get_runway(self.point_on_runway, 51) is None), "Must return None for heading 51"
        self.assertTrue(nte_airport.get_runway(self.point_on_runway, 231) is None), "Must return None for heading 231"
        self.assertTrue(nte_airport.get_runway(self.point_on_runway, 9) is None), "Must return None for heading 51"
        self.assertTrue(nte_airport.get_runway(self.point_on_runway, 189) is None), "Must return None for heading 231"

    def test_off_runway_landing_heading_match(self):
        """If GPS position is besides the runway, but the heading still fits the runway."""
        self.assertTrue(nte_airport.get_runway(self.point_on_airport, 30) is _nte_runway_03), "Must return runway 03 for heading 30"
        self.assertTrue(nte_airport.get_runway(self.point_on_airport, 210) is _nte_runway_21), "Must return runway 21 for heading 210"

    def test_off_runway_landing_heading_off(self):
        """If GPS position is besides the runway, and the heading does not fit any runways."""
        self.assertTrue(nte_airport.get_runway(self.point_on_airport, 180) is None), "Must return None for " \
                                                                                              "heading 180"
        self.assertTrue(nte_airport.get_runway(self.point_on_airport, 330) is None), "Must return None for " \
                                                                                               "heading 330"

    def test_off_airport_landing(self):
        """For landings outside the known airport."""
        self.assertTrue(nte_airport.get_runway(self.point_outside_airport, 30) is None)
        self.assertTrue(nte_airport.get_runway(self.point_outside_airport, 210) is None)


if __name__ == '__main__':
    unittest.main()
