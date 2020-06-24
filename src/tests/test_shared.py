import unittest

from shapely.geometry import Point

from dump1090_postgis.shared import angle2deg, interpolate_track, angle2geg


class TestFunctions(unittest.TestCase):

    @unittest.skip("")
    def test_angle2compass(self):
        #self.assertEqual(angle2deg(0), 270)
        self.assertEqual(angle2deg(90), 180)

    def test_angle2geg(self):
        self.assertAlmostEqual(angle2geg(0), 270, 3)
        self.assertAlmostEqual(angle2geg(45), 225, 3)
        self.assertAlmostEqual(angle2geg(180), 90, 3)
        self.assertAlmostEqual(angle2geg(-180), 90, 3)
        self.assertAlmostEqual(angle2geg(-89), 359, 3)

    def test_interpolate_track(self):
        self.assertAlmostEqual(interpolate_track([Point(0, 0), Point(-1, 0)]), 270, 3)  # Heading west
        self.assertAlmostEqual(interpolate_track([Point(0, 0), Point(0, 1)]), 0, 3)  # Heading north
        self.assertAlmostEqual(interpolate_track([Point(0, 0), Point(1, -1)]), 135, 3)  # Heading southeast
        self.assertAlmostEqual(interpolate_track([Point(0, 0), Point(-1, 1)]), 315, 3)  # Heading northwest


if __name__ == '__main__':
    unittest.main()
