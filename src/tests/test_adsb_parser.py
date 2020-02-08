import unittest


class AdsbMessageStub:

    def __init__(self, messages):
        """

        :param messages: List of messages to yield. Mssages are dicts
        :type messages:
        """
        self.__messages = messages

    def __update_attributes(self, attributes: dict):
        """
        Creates or updates the attributes of this instance.
        :param attributes: Dictionary of attribute names and values
        """
        for attr, value in attributes.items():
            setattr(self, attr, value)

    def __iter__(self):
        """
        Yields an instance of itself with dynamically created or updated instance attributes.
        :param msg: ADSb message string
        :return: Instance of itself updated with ADSb message values
        """
        for msg in self.__messages:
            print("AdsbMessageStub yielding:", msg)
            self.__update_attributes(msg)
            yield self


class MyTestCase(unittest.TestCase):
    def test_something(self):
        self.assertEqual(True, False)


if __name__ == '__main__':
    unittest.main()
