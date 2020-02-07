"""Airport and Runway models."""

import shapely.geometry


class Runway:
    """Runway model defining the geographic location, geometry and orientation.

    Note that this model does NOT represent the physical runway (strip), but the runway referred to during
    landing or takeoff, e.g. 03 or 12L. This means that a physical runway will be described by two Runway instances,
    with a direction difference of 180° between these two.

    This class also provides geometric query functions, to test if a point in space lies with in the runway bounding
    box, or if a flight heading is aligned with the runway or not.
    """

    def __init__(self, name: str, lon: float, lat: float, ref_altitude: float, direction: float, bbox: iter,
                 length: float):
        """Construct the runway instance.

        :param name: Name of the runway, e.g. 03
        :type name: string
        :param ref_altitude: Reference altitude ASL (in meter) of the runway
        :param direction: The direction of the runway, in degrees rel. to north
        :param bbox: Corner coordinates of bounding box of the runway, can be in random order
        :type bbox: List of x-y tuples
        :param length: Length of the runway in meter
        :type length: float
        """

        self.name = name
        self.ref_point = shapely.geometry.point.Point(lon, lat)
        self.ref_altitude = ref_altitude
        self.direction = direction
        self.boundingbox = shapely.geometry.MultiPoint(bbox).bounds
        self.length = length

    def point_in(self, point):
        """Return True if point lies within the runway bounding box, otherwise False.

        :param point: The point geometry to test for
        :type point: shapely.geometry.point.Point
        """
        assert isinstance(point, shapely.geometry.point.Point)
        return self.boundingbox.contains(point)

    def same_heading(self, heading: object, direction_tol: float = 10.0):
        """Return True if heading coincides with the runway direction, otherwise False.

        :param heading: Aircraft heading
        :type heading: float
        :param direction_tol: is the maximum permitted difference between the aircraft heading
        and the runway direction to return a positive match.
        :type direction_tol: float
        """
        if abs(self.direction - heading) <= direction_tol:
            return True
        else:
            return False


class Airport:
    """Airport model, defining its name, location and available runways."""

    def __init__(self, name_icao, name_iata, lon, lat, altitude, bbox, runways):
        assert all([isinstance(runway, Runway) for runway in runways])

        self.name_icao = name_icao
        self.name_iata = name_iata
        self.coordinates = shapely.geometry.point.Point(lon, lat)
        self.altitude = altitude
        self.boundingbox = shapely.geometry.MultiPoint(bbox).bounds
        self.runways = runways

    def get_runway(self, point: shapely.geometry.point.Point, heading: float) -> Runway:
        """Check if touchdown/takeoff point and heading fit any known runway.

        :param point: Coordinates of the point of take off or landing.
        :type point: shapely.geometry.point.Point
        :param heading: Heading of the airplane in the moment of take off or landing (geo-degrees)
        :type heading: float
        :return Runway instance to which the point and direction match, otherwise None
        """

        assert isinstance(point, shapely.geometry.point.Point)

        for runway in self.runways:
            if runway.point_in(point) and runway.same_heading(heading):
                return runway
            else:
                continue

        return None


# Instances of known airports and their runways
_nte_runway_03 = Runway('03',
                        47.144537,
                        -1.617302,
                        27,
                        30,
                        [
                            (47.141703, -1.619792),
                            (47.163170, -1.603446),
                            (47.162999, -1.602936),
                            (47.141525, -1.619280)
                            ],
                        2900)

_nte_runway_21 = Runway('21',
                        47.159876,
                        -1.605619,
                        27,
                        210,
                        [
                            (47.141703, -1.619792),
                            (47.163170, -1.603446),
                            (47.162999, -1.602936),
                            (47.141525, -1.619280)
                            ],
                        2900)

nte_airport = Airport('LFRS', 'NTE', 47.156944, -1.607778, 27,
                      [
                          (47.142339, -1.621437),
                          (47.165234, -1.603608),
                          (47.162784, -1.596542),
                          (47.153871, -1.600891),
                          (47.140760, -1.617134)
                          ],
                      [_nte_runway_03, _nte_runway_21]
                      )
