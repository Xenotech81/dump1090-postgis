from dateutil.parser.isoparser import isoparser

_date_time_parser = isoparser(sep=',')

msg3_valid = {
    'transmission_type': 3,
    'hexident': 'hex_msg3_valid',
    'gen_date_time': _date_time_parser.isoparse('2019/10/20,11:33:40.311'.replace('/', '-')),
    'log_date_time': _date_time_parser.isoparse('2019/10/20,11:33:40.311'.replace('/', '-')),
    'callsign': None,
    'altitude': 3000,
    'speed': 300,
    'track': 0,
    'latitude': 46.65470,
    'longitude': -2.77776,
    'onground': False
    }
