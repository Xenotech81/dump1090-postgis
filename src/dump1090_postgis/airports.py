"""Airport and Runway models."""
import logging

import shapely.geometry

log = logging.getLogger(__name__)


class Runway:
    """Runway model defining the geographic location, geometry and orientation.

    Note that this model does NOT represent the physical runway (strip), but the runway referred to during
    landing or takeoff, e.g. 03 or 12L. This means that a physical runway will be described by two Runway instances,
    with a direction difference of 180° between these two.

    This class also provides geometric query functions, to test if a point in space lies within the runway bounding
    box, or if a flight heading is aligned with the runway or not.
    """

    def __init__(self, name: str, lon: float, lat: float, ref_altitude: float, direction: float, bbox: iter,
                 length: float):
        """Construct the runway instance.

        :param name: Name of the runway, e.g. 03
        :type name: string
        :param ref_altitude: Reference altitude ASL (in meter) of the runway
        :param direction: The direction of the runway, in degrees rel. to north
        :param bbox: Corner coordinates of bounding box of the runway, counterclockwise order
        :type bbox: List of x-y tuples
        :param length: Length of the runway in meter
        :type length: float
        """

        self.name = name
        self.ref_point = shapely.geometry.point.Point(lon, lat)
        self.ref_altitude = ref_altitude
        self.direction = direction
        self.boundingbox = shapely.geometry.Polygon(bbox)
        self.length = length

    def point_in(self, point):
        """Return True if point lies within the runway bounding box, otherwise False.

        :param point: The point geometry to test for
        :type point: shapely.geometry.point.Point
        """
        assert isinstance(point, shapely.geometry.point.Point)
        log.debug("Testing point_in for runway {}: {} ".format(self.name, self.boundingbox.contains(point)))

        return self.boundingbox.contains(point)

    def same_heading(self, heading: float, direction_tol: float = 20.0):
        """Return True if heading coincides (within bounds) with the runway direction, otherwise False.

        :param heading: Aircraft heading
        :type heading: float
        :param direction_tol: The maximum permitted difference between the aircraft heading
        and the runway direction to return a positive.
        :type direction_tol: float
        """

        log.debug("Testing aircraft heading {:.1f} relative to runway direction {}".format(heading, self.direction))
        if abs(self.direction - heading) <= direction_tol:
            log.debug("Aircraft heading and runway direction coincide")
            return True
        else:
            log.debug("Aircraft heading and runway direction do not coincide")
            return False


class Airport:
    """Airport model, defining its name, location and available runways."""

    def __init__(self, name_icao, name_iata, lon, lat, altitude, bbox, runways):
        assert all([isinstance(runway, Runway) for runway in runways])

        self.name_icao = name_icao
        self.name_iata = name_iata
        self.coordinates = shapely.geometry.point.Point(lon, lat)
        self.altitude = altitude
        self.boundingbox = shapely.geometry.Polygon(bbox)
        self.runways = runways

    def get_runway(self, point: shapely.geometry.point.Point, heading: float) -> Runway:
        """Check if touchdown/takeoff point and heading fit any known runway.

        :param point: Coordinates of the point of take off or landing.
        :type point: shapely.geometry.point.Point
        :param heading: Heading of the airplane in the moment of take off or landing (relative north)
        :type heading: float
        :return Runway instance to which the point and direction match, otherwise None
        """

        assert isinstance(point, shapely.geometry.point.Point)

        for runway in self.runways:
            log.debug("Testing for runway '{}'".format(runway.name))
            if runway.point_in(point) and runway.same_heading(heading):
                log.debug("Runway match!")
                return runway
            else:
                continue

        return None


# Instances of known airports and their runways
_nte_runway_03 = Runway('03',
                        -1.617302,
                        47.144537,
                        27,
                        30,
                        [
                            (-1.619792, 47.141703),
                            (-1.603446, 47.163170),
                            (-1.602936, 47.162999),
                            (-1.619280, 47.141525)
                            ],
                        2900)

_nte_runway_21 = Runway('21',
                        -1.605619,
                        47.159876,
                        27,
                        210,
                        [
                            (-1.619792, 47.141703),
                            (-1.603446, 47.163170),
                            (-1.602936, 47.162999),
                            (-1.619280, 47.141525)
                            ],
                        2900)

nte_airport = Airport('LFRS', 'NTE', 47.156944, -1.607778, 27,
                      [
                          (-1.621437, 47.142339),
                          (-1.603608, 47.165234),
                          (-1.596542, 47.162784),
                          (-1.600891, 47.153871),
                          (-1.617134, 47.140760)
                          ],
                      [_nte_runway_03, _nte_runway_21]
                      )
