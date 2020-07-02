import unittest

from unittest.mock import Mock
from shapely.geometry import Point

from dump1090_postgis.shared import angle2compass, interpolate_track


class TestFunctions(unittest.TestCase):

    def test_angle2compass(self):
        self.assertAlmostEqual(angle2compass(0), 90, 3)
        self.assertAlmostEqual(angle2compass(45), 45, 3)
        self.assertAlmostEqual(angle2compass(180), 270, 3)
        self.assertAlmostEqual(angle2compass(-180), 270, 3)
        self.assertAlmostEqual(angle2compass(91), 359, 3)

    def test_interpolate_track(self):
        self.assertAlmostEqual(interpolate_track([Mock(point=Point(0, 0)), Mock(point=Point(-1, 0))]), 270, 3)  # Heading west
        self.assertAlmostEqual(interpolate_track([Mock(point=Point(0, 0)), Mock(point=Point(0, 1))]), 0, 3)  # Heading north
        self.assertAlmostEqual(interpolate_track([Mock(point=Point(0, 0)), Mock(point=Point(-1, -1))]), 225, 3)  # Heading southwest


if __name__ == '__main__':
    unittest.main()
