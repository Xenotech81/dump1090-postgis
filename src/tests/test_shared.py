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
        self.assertAlmostEqual(interpolate_track([Point(0, 0), Point(-1, 0)]), 90, 3)  # East wind
        self.assertAlmostEqual(interpolate_track([Point(0, 0), Point(0, 1)]), 180, 3)  # South wind
        self.assertAlmostEqual(interpolate_track([Point(0, 0), Point(-1, -1)]), 45, 3)  # Northest wind

if __name__ == '__main__':
    unittest.main()
