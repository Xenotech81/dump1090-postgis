import numpy as np
from shapely.geometry import LineString, Point


def feet2m(ft):
    """Transforms from feet (ADSb altitude unit) to meter."""
    return 0.3048 * ft


def deg2angle(deg):
    """Transforms a wind direction in degrees [0...360] to the mathematical angle in a x-y plane."""
    angle = 270.0 - deg
    if angle < 0.0:
        return angle + 360
    else:
        return angle


def angle2deg(deg):
    """Transforms mathematical angle in a x-y plane to wind direction in degrees [0...360]."""
    angle = 270.0 - deg
    if angle > 360:
        return angle - 360
    else:
        return angle


def interpolate_track(positions: iter):
    """Compute flight heading from a list of points by least squares polynomial fit.

    :param positions: List of Position instances to interpolate the track from
    :type positions: list of shapely.geometry.Point
    """
    points = np.array(LineString([p.point for p in positions]))
    rad = np.arctan2(np.diff(points[..., 1]), np.diff(points[..., 0]))
    angle = np.rad2deg(rad)[0]

    return angle2deg(angle)
