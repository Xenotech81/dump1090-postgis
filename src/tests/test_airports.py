import unittest

from shapely.geometry import Point

from dump1090_postgis.airports import _nte_runway_03, _nte_runway_21


class TestRunway(unittest.TestCase):
    def test_point_in(self):
        point = Point((-1.61046, 47.15356, 100.0))
        self.assertEqual(_nte_runway_03.point_in(point), True)
        self.assertEqual(_nte_runway_21.point_in(point), True)


if __name__ == '__main__':
    unittest.main()
