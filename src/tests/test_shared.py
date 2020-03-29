import unittest

from unittest.mock import Mock
from shapely.geometry import Point

from dump1090_postgis.shared import interpolate_track, angle2deg


class TestFunctions(unittest.TestCase):

    def test_angle2deg(self):
        self.assertAlmostEqual(angle2deg(0), 270, 3)
        self.assertAlmostEqual(angle2deg(45), 225, 3)
        self.assertAlmostEqual(angle2deg(180), 90, 3)
        self.assertAlmostEqual(angle2deg(-180), 90, 3)
        self.assertAlmostEqual(angle2deg(-89), 359, 3)

    def test_interpolate_track(self):
        # East wind
        self.assertAlmostEqual(interpolate_track([Mock(point=Point(0, 0)), Mock(point=Point(-1, 0))]), 90, 3)
        # South wind
        self.assertAlmostEqual(interpolate_track([Mock(point=Point(0, 0)), Mock(point=Point(0, 1))]), 180, 3)
        # Northest wind
        self.assertAlmostEqual(interpolate_track([Mock(point=Point(0, 0)), Mock(point=Point(-1, -1))]), 45, 3)
        self.assertAlmostEqual(interpolate_track([Mock(point=Point(1, 1)), Mock(point=Point(-1, -1))]), 45, 3)
        # Northest wind
        self.assertAlmostEqual(interpolate_track([Mock(point=Point(0, 0)), Mock(point=Point(1, 1))]), 225, 3)
        self.assertAlmostEqual(interpolate_track([Mock(point=Point(-1, -1)), Mock(point=Point(0, 0))]), 225, 3)


if __name__ == '__main__':
    unittest.main()
