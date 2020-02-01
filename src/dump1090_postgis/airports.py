import shapely.geometry


class Runway:

    def __init__(self, name: str, lon: float, lat: float, ref_altitude: float, direction: float, bbox: iter,
                 length: float):
        """Construct the runway instance.
        :param name: Name of the runway, e.g. R03
        :type name: string
        :param ref_altitude: Reference altitude of the runway ASL [m]
        :param direction: The direction of the runway, in degrees rel. to north
        """
        self.name = name
        self.ref_point = shapely.geometry.point.Point(lon, lat)
        self.ref_altitude = ref_altitude
        self.direction = direction
        self.boundingbox = shapely.geometry.polygon.Polygon(bbox)
        self.length = length

    def point_in(self, point):
        """Return True if point lies within the runway bounding box, otherwise False.
        :param point: The coordinates to test for
        :type point: shapely.geometry.point.Point
        """
        assert isinstance(point, shapely.geometry.point.Point)
        return self.boundingbox.contains(point)

    def same_heading(self, heading: object, direction_tol: float = 10.0):
        """Return True if heading coincides with the runway direction, otherwise False.

        direction_tol is the maximum permitted difference between the aircraft heading
        and the runway direction to return a positive match.
        :param heading: Aircraft heading
        :type heading: float
        """
        if abs(self.direction - heading) <= direction_tol:
            return True
        else:
            return False


class Airport:

    def __init__(self, name_icao, name_iata, lon, lat, altitude, bbox, runways):
        assert all([isinstance(runway, Runway) for runway in runways])

        self.name_icao = name_icao
        self.name_iata = name_iata
        self.coordinates = shapely.geometry.point.Point(lon, lat)
        self.altitude = altitude
        self.boundingbox = shapely.geometry.polygon.Polygon(bbox)
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


nte_r03 = Runway('R03',
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

nte_r21 = Runway('R21',
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
                      [nte_r03, nte_r21]
                      )
