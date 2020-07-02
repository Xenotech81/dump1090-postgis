import numpy as np
from shapely.geometry import LineString, Point


def feet2m(ft):
    """Transforms from feet (ADSb altitude unit) to meter."""
    return 0.3048 * ft


def winddir2angle(deg):
    """Transforms a wind direction in degrees [0...360] to the mathematical angle in a x-y plane."""
    angle = 270.0 - deg
    if angle < 0.0:
        return angle + 360
    else:
        return angle


def angle2winddir(deg):
    """Transforms mathematical angle to wind direction in degrees [0...360].

    ATTENTION: Wind direction and compass direction are in opposite directions!
    """
    angle = 270.0 - deg
    if angle > 360:
        return angle - 360
    else:
        return angle


def angle2compass(deg):
    """Transform mathematical angle to compass direction."""
    return (450 - deg) % 360


def interpolate_track(positions: iter):
    """Compute flight heading from a list of two aircraft positions.

    Positions is a list of 2 or more Points, sorted in ascending order
    (chronologically along the flight path).

    NOTE: For now no track is interpolated, just a local heading from the first two points in the list of points.

    :param positions: List of Position instances to interpolate the track from
    :type positions: list of shapely.geometry.Point
    """
    points = np.array(LineString([p.point for p in positions]))
    rad = np.arctan2(np.diff(points[..., 1]), np.diff(points[..., 0]))
    deg = np.rad2deg(rad)[0]

    return angle2compass(deg)
